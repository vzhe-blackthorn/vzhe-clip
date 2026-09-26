import XCTest
@testable import VzheClip

@MainActor
final class ClipCardViewTests: XCTestCase {
    func testPreviewTrimsAndLimitsLength() {
        XCTAssertEqual(ClipCardView.preview(of: "\n  hello \n"), "hello")
        XCTAssertEqual(ClipCardView.preview(of: String(repeating: "x", count: 1000)).count, 300)
    }

    func testRelativeTimeIsShortAndNonEmpty() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let text = ClipCardView.relativeTime(now.addingTimeInterval(-120), now: now)
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("2"), text)
    }
}
