import SwiftUI

struct APIKeySetupView: View {
    let existingKeyPresent: Bool
    let onValidate: (String) async -> ProviderValidateResponse
    let onSave: (String) -> Void

    @State private var apiKey: String = ""
    @State private var validationMessage: String = ""
    @State private var validationIsValid = false
    @State private var isValidating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Anthropic API Key")
                .font(.title2.weight(.semibold))
            Text("Orange uses your own Anthropic key for planning and verification. Your key stays in macOS Keychain.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SecureField("sk-ant-...", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Button(isValidating ? "Validating..." : "Validate Key") {
                    Task { await validate() }
                }
                .disabled(isValidating || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(existingKeyPresent ? "Update Key" : "Save Key") {
                    onSave(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .disabled(!validationIsValid)

                Spacer()
            }

            if !validationMessage.isEmpty {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(validationIsValid ? .green : .orange)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func validate() async {
        isValidating = true
        validationIsValid = false
        let result = await onValidate(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        validationIsValid = result.valid
        if result.valid {
            validationMessage = result.accountHint ?? "Key validated successfully."
        } else {
            validationMessage = result.reason ?? "Key validation failed."
        }
        isValidating = false
    }
}
