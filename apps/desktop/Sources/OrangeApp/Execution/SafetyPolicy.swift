import Foundation

struct SafetyPrompt: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

protocol SafetyPolicy {
    func evaluate(actions: [AgentAction]) -> [SafetyPrompt]
}

struct DefaultSafetyPolicy: SafetyPolicy {
    func evaluate(actions: [AgentAction]) -> [SafetyPrompt] {
        var prompts: [SafetyPrompt] = []

        if actions.contains(where: { $0.destructive }) {
            prompts.append(
                SafetyPrompt(
                    title: "Confirm High-Risk Action",
                    message: "This command contains destructive or send behavior."
                )
            )
        }

        if actions.contains(where: { $0.kind == .runAppleScript }) {
            prompts.append(
                SafetyPrompt(
                    title: "Confirm Script Execution",
                    message: "AppleScript execution requires explicit approval."
                )
            )
        }

        return prompts
    }
}
