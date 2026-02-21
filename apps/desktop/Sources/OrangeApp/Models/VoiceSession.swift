import Foundation

enum SessionState: String {
    case idle
    case listening
    case transcribing
    case planning
    case confirming
    case executing
    case verifying
    case done
    case failed
    case canceled
}

struct VoiceSession {
    let id: String
    var transcript: String
    var state: SessionState
    var createdAt: Date
}
