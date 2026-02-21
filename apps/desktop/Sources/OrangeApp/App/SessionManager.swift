import Foundation

@MainActor
final class SessionManager {
    private let sttService: SpeechToTextService
    private let contextProvider: ContextProvider
    private let plannerClient: PlannerClient
    private let executionEngine: ExecutionEngine
    private let safetyPolicy: SafetyPolicy

    private(set) var pendingPlan: ActionPlan?

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
    }

    func stopRecordingAndPlan(state: AppState) async {
        state.state = .transcribing
        state.statusText = "Transcribing..."

        let eventStreamTask = Task {
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
        defer { eventStreamTask.cancel() }

        do {
            let transcriptResult = try await sttService.stop()
            state.transcript = transcriptResult.fullText
            state.partialTranscript = transcriptResult.fullText

            state.state = .planning
            state.statusText = "Planning..."

            let context = await contextProvider.capture()
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
            state.actionPlan = plan

            var prompts = safetyPolicy.evaluate(actions: plan.actions)
            if plan.requiresConfirmation || plan.riskLevel == "high" || plan.riskLevel == "medium" {
                prompts.append(
                    SafetyPrompt(
                        title: "Confirm Planned Actions",
                        message: "Planner marked this command as \(plan.riskLevel) risk."
                    )
                )
            }
            if prompts.isEmpty {
                await executePlan(plan, state: state)
            } else {
                pendingPlan = plan
                state.safetyPrompts = prompts
                state.state = .confirming
                state.statusText = "Confirmation required"
            }
        } catch {
            state.state = .failed
            state.statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func confirmAndExecute(state: AppState) async {
        guard let plan = pendingPlan else { return }
        pendingPlan = nil
        state.safetyPrompts = []
        await executePlan(plan, state: state)
    }

    func cancel(state: AppState) {
        pendingPlan = nil
        state.state = .canceled
        state.statusText = "Canceled"
    }

    private func executePlan(_ plan: ActionPlan, state: AppState) async {
        state.state = .executing
        state.statusText = "Executing..."
        let beforeContext = await contextProvider.capture()

        let result = await executionEngine.execute(plan: plan)
        state.executionResult = result
        state.state = .verifying
        state.statusText = "Verifying..."

        let afterContext = await contextProvider.capture()
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
        } else if let verifyReason = verifyResult?.reason, verifyResult?.status == "failure" {
            state.state = .failed
            state.statusText = "Verification failed: \(verifyReason)"
        } else {
            state.state = .failed
            state.statusText = "Execution failed"
        }
    }

    private func contextDigest(from context: ScreenContext) -> String {
        let appName = context.app.name ?? "Unknown"
        let window = context.app.windowTitle ?? "Unknown"
        let url = context.app.url ?? "n/a"
        let ax = (context.axTreeSummary ?? "").prefix(1200)
        return "app=\(appName), window=\(window), url=\(url), ax=\(ax)"
    }
}
