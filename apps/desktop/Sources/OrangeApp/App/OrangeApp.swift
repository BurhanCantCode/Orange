import SwiftUI

@main
struct OrangeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var appState = AppState()
    @State private var showOnboarding = false
    @State private var showAPIKeySetup = false
    @State private var showDiagnostics = false
    @State private var permissionStatus = PermissionsManager.Status(
        accessibility: false,
        microphone: false,
        screenRecording: false
    )

    private let sessionManager: SessionManager
    private let sidecarManager = PythonSidecarManager()
    private let hotkeyManager = HotkeyManager()
    private let permissionsManager = PermissionsManager()
    private let credentialManager = CredentialManager()
    private let plannerClient: HTTPPlannerClient

    init() {
        let stt = AppleSpeechRecognizer()
        let context = LocalContextProvider()
        let planner = HTTPPlannerClient()
        let executor = ActionExecutor()
        let safety = DefaultSafetyPolicy()

        self.plannerClient = planner
        self.sessionManager = SessionManager(
            sttService: stt,
            contextProvider: context,
            plannerClient: planner,
            executionEngine: executor,
            safetyPolicy: safety
        )
    }

    var body: some Scene {
        WindowGroup("Orange") {
            Color.clear
                .frame(width: 1, height: 1)
                .onAppear {
                    refreshPermissionStatus()
                    sidecarManager.startIfNeeded(apiKey: credentialManager.loadAnthropicAPIKey())
                    refreshOnboardingGate()
                    Task { await refreshProviderHealth() }

                    OverlayWindow.shared.attach(rootView: overlayContent())
                    OverlayWindow.shared.show()

                    hotkeyManager.register(
                        onPress: { handleStart() },
                        onRelease: { handleStop() }
                    )
                }
                .onDisappear {
                    OverlayWindow.shared.hide()
                    sidecarManager.stop()
                }
                .onChange(of: appState.onboardingGate) { _, newValue in
                    if newValue == .needsAPIKey {
                        showAPIKeySetup = true
                    }
                }
                .sheet(isPresented: $showAPIKeySetup) {
                    APIKeySetupView(
                        existingKeyPresent: credentialManager.hasAnthropicAPIKey(),
                        onValidate: { key in
                            await validateAPIKey(key)
                        },
                        onSave: { key in
                            saveAPIKey(key)
                        }
                    )
                    .interactiveDismissDisabled(appState.onboardingGate == .needsAPIKey)
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(
                        status: permissionStatus,
                        onRequestAccessibility: {
                            _ = permissionsManager.promptAccessibilityPermission()
                            permissionsManager.openSettingsAccessibility()
                        },
                        onRequestMicrophone: {
                            Task {
                                _ = await permissionsManager.requestMicrophonePermission()
                                permissionsManager.openSettingsMicrophone()
                                await MainActor.run {
                                    refreshPermissionStatus()
                                    refreshOnboardingGate()
                                }
                            }
                        },
                        onRequestScreenRecording: {
                            _ = permissionsManager.requestScreenRecordingPermission()
                            permissionsManager.openSettingsScreenRecording()
                        },
                        onRefresh: {
                            refreshPermissionStatus()
                            refreshOnboardingGate()
                        }
                    )
                    .interactiveDismissDisabled(appState.onboardingGate == .needsPermissions)
                }
                .alert("Diagnostics", isPresented: $showDiagnostics) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(appState.diagnosticsText)
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("Orange") {
                Button("API Key Setup") {
                    showAPIKeySetup = true
                }

                Button("Reset API Key") {
                    resetAPIKey()
                }

                Button("Diagnostics") {
                    Task {
                        await loadDiagnostics()
                        showDiagnostics = true
                    }
                }

                Divider()

                Button("Permissions Setup") {
                    refreshPermissionStatus()
                    refreshOnboardingGate()
                    showOnboarding = true
                }
            }
        }
    }

    private func handleStart() {
        refreshOnboardingGate()
        guard appState.onboardingGate == .ready else {
            switch appState.onboardingGate {
            case .needsAPIKey:
                appState.statusText = "Enter Anthropic API key"
                showAPIKeySetup = true
            case .needsPermissions:
                appState.statusText = "Grant required permissions"
                showOnboarding = true
            case .ready:
                break
            }
            return
        }

        if !appState.sidecarHealthy {
            Task {
                await refreshProviderHealth()
            }
            appState.statusText = "Starting sidecar..."
            return
        }

        sessionManager.beginRecording(state: appState)
    }

    private func handleStop() {
        guard appState.state == .listening else { return }
        guard appState.isReadyForCommands else {
            appState.statusText = "Setup incomplete"
            return
        }
        Task {
            await sessionManager.stopRecordingAndPlan(state: appState)
        }
    }

    private func refreshPermissionStatus() {
        permissionStatus = permissionsManager.currentStatus()
    }

    private func refreshOnboardingGate() {
        if !credentialManager.hasAnthropicAPIKey() {
            appState.onboardingGate = .needsAPIKey
            showAPIKeySetup = true
            showOnboarding = false
            return
        }

        if !permissionStatus.allGranted {
            appState.onboardingGate = .needsPermissions
            showOnboarding = true
            showAPIKeySetup = false
            return
        }

        appState.onboardingGate = .ready
        showAPIKeySetup = false
        showOnboarding = false
    }

    private func validateAPIKey(_ key: String) async -> ProviderValidateResponse {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ProviderValidateResponse(
                provider: "anthropic",
                valid: false,
                reason: "API key is empty.",
                accountHint: nil
            )
        }

        do {
            return try await plannerClient.validateProvider(
                request: ProviderValidateRequest(
                    provider: "anthropic",
                    apiKey: trimmed
                )
            )
        } catch {
            return ProviderValidateResponse(
                provider: "anthropic",
                valid: false,
                reason: error.localizedDescription,
                accountHint: nil
            )
        }
    }

    private func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard credentialManager.saveAnthropicAPIKey(trimmed) else {
            appState.statusText = "Failed to save API key"
            return
        }

        sidecarManager.restart(apiKey: trimmed)
        appState.statusText = "API key saved"

        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            await refreshProviderHealth()
            refreshPermissionStatus()
            refreshOnboardingGate()
        }
    }

    private func resetAPIKey() {
        credentialManager.resetAnthropicAPIKey()
        sidecarManager.restart(apiKey: nil)
        appState.sidecarHealthy = false
        appState.statusText = "API key removed"
        refreshOnboardingGate()
    }

    private func refreshProviderHealth() async {
        do {
            let status = try await plannerClient.providerStatus()
            await MainActor.run {
                appState.sidecarHealthy = status.health
            }
        } catch {
            await MainActor.run {
                appState.sidecarHealthy = false
            }
        }
    }

    private func loadDiagnostics() async {
        let permission = permissionsManager.currentStatus()
        let providerLine: String
        do {
            let providerStatus = try await plannerClient.providerStatus()
            providerLine = "Provider: \(providerStatus.provider), keyConfigured=\(providerStatus.keyConfigured), health=\(providerStatus.health), models=\(providerStatus.modelSimple)/\(providerStatus.modelComplex)"
        } catch {
            providerLine = "Provider: unavailable (\(error.localizedDescription))"
        }

        appState.diagnosticsText = [
            providerLine,
            "Gate: \(appState.onboardingGate.rawValue)",
            "Permissions: accessibility=\(permission.accessibility), mic=\(permission.microphone), screen=\(permission.screenRecording)",
            "Sidecar healthy: \(appState.sidecarHealthy)"
        ].joined(separator: "\n")
    }

    @ViewBuilder
    private func overlayContent() -> some View {
        OverlayView(
            appState: appState,
            onStart: {
                handleStart()
            },
            onStop: {
                handleStop()
            },
            onConfirm: {
                Task { await sessionManager.confirmAndExecute(state: appState) }
            },
            onCancel: {
                sessionManager.cancel(state: appState)
            }
        )
    }
}
