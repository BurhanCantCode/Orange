import Foundation

final class PythonSidecarManager {
    private var process: Process?

    func startIfNeeded() {
        if process?.isRunning == true { return }

        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let agentDirectory = repoRoot.appendingPathComponent("agent")
        guard FileManager.default.fileExists(atPath: agentDirectory.path) else {
            Logger.error("agent directory not found at \(agentDirectory.path)")
            return
        }

        let p = Process()
        p.currentDirectoryURL = agentDirectory
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["python3", "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "7789"]

        let output = Pipe()
        p.standardOutput = output
        p.standardError = output

        do {
            try p.run()
            process = p
            Logger.info("Sidecar started")
        } catch {
            Logger.error("Failed to start sidecar: \(error.localizedDescription)")
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        Logger.info("Sidecar stopped")
    }

    deinit {
        stop()
    }
}
