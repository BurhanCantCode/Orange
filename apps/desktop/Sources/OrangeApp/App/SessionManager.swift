import Foundation

@MainActor
final class SessionManager {
    private let sttService: SpeechToTextService
    private let contextProvider: ContextProvider
    private let plannerClient: PlannerClient
    private let executionEngine: ExecutionEngine
    private let safetyPolicy: SafetyPolicy

    private(set) var pendingPlan: ActionPlan?
    private var eventStreamTask: Task<Void, Never>?
    private var executionTask: Task<ExecutionResult, Never>?
    private var canceled = false
    private var sessionApprovals = Set<SafetyCategory>()
    private let timestampFormatter = ISO8601DateFormatter()

    init(
        sttService: SpeechToTextService,
        contextProvider: ContextProvider,
        plannerClient: PlannerClient,
        executionEngine: ExecutionEngine,
        safetyPolicy: SafetyPolicy
    ) {
        self.sttService = sttService
        self.contextProvider = contextProvider
        self.plannerClient = plannerClient
        self.executionEngine = executionEngine
        self.safetyPolicy = safetyPolicy
    }

    func beginRecording(state: AppState) {
        cleanupActiveWork(state: state, resetStatus: false)
        canceled = false
        sessionApprovals = []
        state.sessionId = UUID().uuidString
        sttService.setPartialHandler { partial in
            Task { @MainActor in
                state.partialTranscript = partial
            }
        }
        state.state = .listening
        state.statusText = "Listening..."
        state.partialTranscript = ""
        state.transcript = ""
        state.plannerEvents = []
        sttService.start()
        submitTelemetry(
            state: state,
            stage: "listening",
            status: "started"
        )
    }

    func stopRecordingAndPlan(state: AppState) async {
        guard !canceled else { return }
        state.state = .transcribing
        state.statusText = "Transcribing..."
        submitTelemetry(
            state: state,
            stage: "transcribing",
            status: "started"
        )

        eventStreamTask?.cancel()
        eventStreamTask = Task {
            do {
                for try await event in plannerClient.streamEvents(sessionId: state.sessionId) {
                    await MainActor.run {
                        state.plannerEvents.append(event)
                        state.statusText = event.message
                    }
                }
            } catch {
                await MainActor.run {
                    if state.state == .planning {
                        state.statusText = "Planning..."
                    }
                }
            }
        }
        defer {
            eventStreamTask?.cancel()
            eventStreamTask = nil
        }

        do {
            let transcriptResult = try await sttService.stop()
            guard !canceled else { return }
            state.transcript = transcriptResult.fullText
            state.partialTranscript = transcriptResult.fullText

            state.state = .planning
            state.statusText = "Planning..."
            submitTelemetry(
                state: state,
                stage: "planning",
                status: "started"
            )

            let context = await contextProvider.capture()
            guard !canceled else { return }
            let request = PlanRequest(
                schemaVersion: 1,
                sessionId: state.sessionId,
                transcript: transcriptResult.fullText,
                screenshotBase64: context.screenshotBase64,
                axTreeSummary: context.axTreeSummary,
                app: context.app,
                preferences: PlannerPreferences(preferredModel: nil, locale: nil, lowLatency: true)
            )

            let plan = try await plannerClient.plan(request: request)
            guard !canceled else { return }
            state.actionPlan = plan

            var prompts = safetyPolicy
                .evaluate(actions: plan.actions)
                .filter { shouldPrompt($0) }

            if plan.requiresConfirmation || plan.riskLevel == "high" || plan.riskLevel == "medium" {
                prompts.append(
                    SafetyPrompt(
                        category: .send,
                        approvalMode: .alwaysAsk,
                        title: "Confirm Planned Actions",
                        message: "Planner marked this command as \(plan.riskLevel) risk."
                    )
                )
            }
            if prompts.isEmpty {
                submitTelemetry(
                    state: state,
                    stage: "planning",
                    status: "completed"
                )
                await executePlan(plan, state: state)
            } else {
                pendingPlan = plan
                state.safetyPrompts = prompts
                state.state = .confirming
                state.statusText = "Confirmation required"
                submitTelemetry(
                    state: state,
                    stage: "confirming",
                    status: "required"
                )
            }
        } catch is CancellationError {
            state.state = .canceled
            state.statusText = "Canceled"
            submitTelemetry(
                state: state,
                stage: "session",
                status: "canceled"
            )
        } catch {
            if canceled {
                state.state = .canceled
                state.statusText = "Canceled"
                return
            }
            if let plannerError = error as? PlannerServiceError,
               let code = plannerError.code,
               code == "missing_api_key" || code == "invalid_api_key" || code == "invalid_api_key_format"
            {
                state.onboardingGate = .needsAPIKey
                state.sidecarHealthy = false
                state.state = .failed
                state.statusText = "Anthropic API key required. Open API Key Setup."
                submitTelemetry(
                    state: state,
                    stage: "planning",
                    status: "failed",
                    errorCode: code
                )
                return
            }
            state.state = .failed
            state.statusText = "Failed: \(error.localizedDescription)"
            submitTelemetry(
                state: state,
                stage: "planning",
                status: "failed",
                errorCode: "planning_error"
            )
        }
    }

    func confirmAndExecute(state: AppState) async {
        guard let plan = pendingPlan else { return }
        recordSafetyDecisions(state: state, decision: "approved")
        for prompt in state.safetyPrompts where prompt.approvalMode == .perSession {
            sessionApprovals.insert(prompt.category)
        }
        pendingPlan = nil
        state.safetyPrompts = []
        submitTelemetry(
            state: state,
            stage: "confirming",
            status: "approved"
        )
        await executePlan(plan, state: state)
    }

    func cancel(state: AppState) {
        if !state.safetyPrompts.isEmpty {
            recordSafetyDecisions(state: state, decision: "denied")
        }
        cleanupActiveWork(state: state, resetStatus: true)
        submitTelemetry(
            state: state,
            stage: "session",
            status: "canceled"
        )
    }

    private func executePlan(_ plan: ActionPlan, state: AppState) async {
        guard !canceled else { return }
        state.state = .executing
        state.statusText = "Executing..."
        submitTelemetry(
            state: state,
            stage: "executing",
            status: "started"
        )
        let beforeContext = await contextProvider.capture()
        guard !canceled else { return }

        executionTask?.cancel()
        executionTask = Task { [executionEngine] in
            await executionEngine.execute(plan: plan)
        }
        let result = await (executionTask?.value ?? ExecutionResult(
            status: .failure,
            completedActions: [],
            failedActionId: nil,
            reason: "Execution task cancelled",
            recoverySuggestion: "Retry",
            actionResults: []
        ))
        executionTask = nil
        guard !canceled else { return }

        state.executionResult = result

        let actionKindsById = Dictionary(uniqueKeysWithValues: plan.actions.map { ($0.id, $0.kind.rawValue) })
        for actionResult in result.actionResults {
            submitTelemetry(
                state: state,
                stage: "executing",
                actionKind: actionKindsById[actionResult.id],
                status: actionResult.status.rawValue,
                latencyMs: actionResult.latencyMs,
                errorCode: actionResult.errorCode
            )
        }

        state.state = .verifying
        state.statusText = "Verifying..."
        submitTelemetry(
            state: state,
            stage: "verifying",
            status: "started"
        )

        let afterContext = await contextProvider.capture()
        guard !canceled else { return }
        let verifyResult = try? await plannerClient.verify(
            sessionId: state.sessionId,
            plan: plan,
            executionStatus: result.status,
            reason: result.reason,
            beforeContext: contextDigest(from: beforeContext),
            afterContext: contextDigest(from: afterContext)
        )

        if result.status == .success, verifyResult?.status != "failure" {
            state.state = .done
            state.statusText = "Done"
            submitTelemetry(
                state: state,
                stage: "session",
                app: beforeContext.app.name,
                status: "success"
            )
        } else if let verifyReason = verifyResult?.reason, verifyResult?.status == "failure" {
            state.state = .failed
            state.statusText = "Verification failed: \(verifyReason)"
            submitTelemetry(
                state: state,
                stage: "verifying",
                app: beforeContext.app.name,
                status: "failure",
                errorCode: "verification_failed"
            )
        } else {
            state.state = .failed
            state.statusText = "Execution failed"
            submitTelemetry(
                state: state,
                stage: "executing",
                app: beforeContext.app.name,
                status: "failure",
                errorCode: "execution_failed"
            )
        }
    }

    private func contextDigest(from context: ScreenContext) -> String {
        let appName = context.app.name ?? "Unknown"
        let window = context.app.windowTitle ?? "Unknown"
        let url = context.app.url ?? "n/a"
        let ax = (context.axTreeSummary ?? "").prefix(1200)
        return "app=\(appName), window=\(window), url=\(url), ax=\(ax)"
    }

    private func shouldPrompt(_ prompt: SafetyPrompt) -> Bool {
        switch prompt.approvalMode {
        case .oneTime, .alwaysAsk:
            return true
        case .perSession:
            return !sessionApprovals.contains(prompt.category)
        }
    }

    private func cleanupActiveWork(state: AppState, resetStatus: Bool) {
        canceled = true
        sttService.cancel()
        eventStreamTask?.cancel()
        eventStreamTask = nil
        executionTask?.cancel()
        executionTask = nil
        pendingPlan = nil
        state.safetyPrompts = []
        state.actionPlan = nil
        if resetStatus {
            state.state = .canceled
            state.statusText = "Canceled"
        }
    }

    private func submitTelemetry(
        state: AppState,
        stage: String,
        app: String? = nil,
        actionKind: String? = nil,
        status: String,
        latencyMs: Int? = nil,
        errorCode: String? = nil
    ) {
        let event = SessionTelemetryEvent(
            sessionId: state.sessionId,
            timestamp: timestampFormatter.string(from: Date()),
            stage: stage,
            app: app,
            actionKind: actionKind,
            status: status,
            latencyMs: latencyMs,
            errorCode: errorCode
        )
        Task {
            await plannerClient.telemetry(event: event)
        }
    }

    private func recordSafetyDecisions(state: AppState, decision: String) {
        let timestamp = timestampFormatter.string(from: Date())
        for prompt in state.safetyPrompts {
            state.safetyAuditTrail.append(
                SafetyDecisionRecord(
                    id: UUID().uuidString,
                    sessionId: state.sessionId,
                    category: prompt.category.rawValue,
                    decision: decision,
                    timestamp: timestamp,
                    approvalMode: prompt.approvalMode.rawValue
                )
            )
        }
    }
}
