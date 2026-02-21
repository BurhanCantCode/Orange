import XCTest
@testable import OrangeApp

final class OrangeAppTests: XCTestCase {
    func testSafetyPolicyFlagsDestructiveAction() {
        let action = AgentAction(
            id: "a1",
            kind: .runAppleScript,
            target: nil,
            text: nil,
            keyCombo: nil,
            appBundleId: nil,
            timeoutMs: 1000,
            destructive: true,
            expectedOutcome: nil
        )

        let prompts = DefaultSafetyPolicy().evaluate(actions: [action])
        XCTAssertFalse(prompts.isEmpty)
    }
}
