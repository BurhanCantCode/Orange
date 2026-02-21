import Foundation

protocol ExecutionEngine {
    func execute(plan: ActionPlan) async -> ExecutionResult
}

final class ActionExecutor: ExecutionEngine {
    func execute(plan: ActionPlan) async -> ExecutionResult {
        var completed: [String] = []
        for action in plan.actions {
            do {
                try await Task.sleep(nanoseconds: UInt64(action.timeoutMs) * 1_000_000)
                completed.append(action.id)
                Logger.info("Executed action \(action.id): \(action.kind.rawValue)")
            } catch {
                return ExecutionResult(
                    status: .failure,
                    completedActions: completed,
                    failedActionId: action.id,
                    reason: error.localizedDescription,
                    recoverySuggestion: "Retry command"
                )
            }
        }

        return ExecutionResult(
            status: .success,
            completedActions: completed,
            failedActionId: nil,
            reason: nil,
            recoverySuggestion: nil
        )
    }
}
