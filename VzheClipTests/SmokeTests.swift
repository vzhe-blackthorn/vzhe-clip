import XCTest
@testable import VzheClip

@MainActor
final class SmokeTests: XCTestCase {
    func testAppKnowsItIsRunningUnderTests() {
        XCTAssertTrue(AppDelegate.isRunningTests)
    }
}
