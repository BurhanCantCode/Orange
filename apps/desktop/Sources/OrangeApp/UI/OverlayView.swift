import SwiftUI

struct OverlayView: View {
    @ObservedObject var appState: AppState
    let onStart: () -> Void
    let onStop: () -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(colorForState(appState.state))
                    .frame(width: 14, height: 14)
                Text(appState.statusText)
                    .font(.headline)
                Spacer()
                Text(appState.state.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !appState.transcript.isEmpty {
                Text("Heard: \(appState.transcript)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if !appState.partialTranscript.isEmpty {
                Text("Listening: \(appState.partialTranscript)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let plan = appState.actionPlan {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.summary ?? "Action Plan")
                        .font(.subheadline.weight(.semibold))
                    ForEach(plan.actions.prefix(4), id: \.id) { action in
                        Text("• \(action.kind.rawValue) \(action.target ?? action.text ?? action.keyCombo ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !appState.safetyPrompts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(appState.safetyPrompts) { prompt in
                        Text("\(prompt.title): \(prompt.message)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            if !appState.plannerEvents.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Timeline")
                        .font(.caption.weight(.semibold))
                    ForEach(appState.plannerEvents.suffix(3)) { event in
                        Text("• \(event.message)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 8) {
                Button("Start") { onStart() }
                Button("Stop") { onStop() }
                if appState.state == .confirming {
                    Button("Confirm") { onConfirm() }
                    Button("Cancel") { onCancel() }
                }
            }
        }
        .padding(16)
        .frame(width: 480)
    }

    private func colorForState(_ state: SessionState) -> Color {
        switch state {
        case .listening: return .red
        case .planning, .transcribing, .executing, .verifying: return .orange
        case .done: return .green
        case .failed, .canceled: return .gray
        default: return .blue
        }
    }
}
