import Foundation

struct TranscriptResult {
    let fullText: String
    let partials: [String]
}

protocol SpeechToTextService {
    func start()
    func stop() async throws -> TranscriptResult
}

final class AppleSpeechRecognizer: SpeechToTextService {
    private var startedAt: Date?

    func start() {
        startedAt = Date()
        Logger.info("STT started")
    }

    func stop() async throws -> TranscriptResult {
        let elapsed = Date().timeIntervalSince(startedAt ?? Date())
        Logger.info("STT stopped after \(elapsed)s")

        // Scaffold behavior: return placeholder text for now.
        return TranscriptResult(
            fullText: "open Safari and go to orange.ai",
            partials: ["open Safari", "and go to orange.ai"]
        )
    }
}

final class WhisperAPIClient {
    func transcribe(audioData: Data) async throws -> String {
        _ = audioData
        return ""
    }
}
