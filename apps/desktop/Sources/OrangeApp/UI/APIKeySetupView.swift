import SwiftUI

struct APIKeySetupView: View {
    let existingKeyPresent: Bool
    let onValidate: (String) async -> ProviderValidateResponse
    let onSave: (String) -> Void

    @State private var apiKey: String = ""
    @State private var validationMessage: String = ""
    @State private var validationIsValid = false
    @State private var isValidating = false

    private var normalizedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedKey.isEmpty && normalizedKey.hasPrefix("sk-ant-")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Orange accent line
            Capsule()
                .fill(Color.orange)
                .frame(width: 32, height: 3)

            Text("ORANGE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
                .tracking(3)

            Text("Anthropic API Key")
                .font(.title2.weight(.semibold))

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                Text("Your key stays in macOS Keychain. Never sent to Orange servers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SecureField("sk-ant-...", text: $apiKey)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

            HStack(spacing: 10) {
                Button {
                    Task { await validate() }
                } label: {
                    HStack(spacing: 4) {
                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isValidating ? "Validating..." : "Validate Key")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .disabled(isValidating || normalizedKey.isEmpty)
                .opacity(isValidating || normalizedKey.isEmpty ? 0.5 : 1)

                Button {
                    onSave(normalizedKey)
                    if !validationIsValid {
                        validationMessage = "Saved without validation. Orange will verify connectivity in the background."
                    }
                } label: {
                    Text(existingKeyPresent ? "Update Key" : "Save Key")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.orange))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(!canSave ? 0.5 : 1)

                Spacer()
            }

            if !validationMessage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: validationIsValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 11))
                    Text(validationMessage)
                        .font(.caption)
                }
                .foregroundStyle(validationIsValid ? .green : .orange)
            }
        }
        .padding(24)
        .frame(width: 520)
        .preferredColorScheme(.dark)
    }

    private func validate() async {
        isValidating = true
        validationIsValid = false
        let result = await onValidate(normalizedKey)
        validationIsValid = result.valid
        if result.valid {
            validationMessage = result.accountHint ?? "Key validated successfully."
        } else {
            validationMessage = result.reason ?? "Key validation failed."
        }
        isValidating = false
    }
}
