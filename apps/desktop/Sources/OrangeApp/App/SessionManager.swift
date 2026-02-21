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
        state.state = .listening
        state.statusText = "Listening..."
        sttService.start()
    }

    func stopRecordingAndPlan(state: AppState) async {
        state.state = .transcribing
        state.statusText = "Transcribing..."

        do {
            let transcriptResult = try await sttService.stop()
            state.transcript = transcriptResult.fullText

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

            let prompts = safetyPolicy.evaluate(actions: plan.actions)
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

        let result = await executionEngine.execute(plan: plan)
        state.executionResult = result

        if result.status == .success {
            state.state = .done
            state.statusText = "Done"
        } else {
            state.state = .failed
            state.statusText = "Execution failed"
        }
    }
}
