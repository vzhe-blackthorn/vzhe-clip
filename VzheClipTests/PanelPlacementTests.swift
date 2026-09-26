import XCTest
@testable import VzheClip

@MainActor
final class PanelPlacementTests: XCTestCase {
    private let size = CGSize(width: 360, height: 520)
    private let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

    func testOpensBelowRightOfCursor() {
        let origin = PanelPlacement.origin(cursor: CGPoint(x: 500, y: 700), panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin, CGPoint(x: 508, y: 700 - 8 - 520))
    }

    func testClampedAtRightEdge() {
        let origin = PanelPlacement.origin(cursor: CGPoint(x: 1400, y: 700), panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin.x, 1440 - 360)
    }

    func testClampedAtBottomEdge() {
        let origin = PanelPlacement.origin(cursor: CGPoint(x: 100, y: 50), panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin.y, 0)
    }

    func testClampedAtTopLeftCorner() {
        let origin = PanelPlacement.origin(cursor: CGPoint(x: -20, y: 900), panelSize: size, visibleFrame: visible)
        XCTAssertEqual(origin, CGPoint(x: 0, y: 875 - 520))
    }

    func testSecondaryScreenWithNegativeOrigin() {
        let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let origin = PanelPlacement.origin(cursor: CGPoint(x: -10, y: 800), panelSize: size, visibleFrame: left)
        XCTAssertEqual(origin.x, -360)
        XCTAssertEqual(origin.y, 800 - 8 - 520)
    }

    func testPanelTallerThanScreenKeepsTopVisible() {
        let short = CGRect(x: 0, y: 0, width: 800, height: 400)
        let origin = PanelPlacement.origin(cursor: CGPoint(x: 10, y: 10), panelSize: size, visibleFrame: short)
        XCTAssertEqual(origin.y + size.height, 400)
    }

    func testPicksScreenUnderCursor() {
        let main = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: visible)
        let left = ScreenGeometry(frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
                                  visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1055))
        XCTAssertEqual(PanelPlacement.screen(containing: CGPoint(x: -100, y: 100), in: [main, left]), left)
        XCTAssertEqual(PanelPlacement.screen(containing: CGPoint(x: 5000, y: 5000), in: [main, left]), main)
        XCTAssertNil(PanelPlacement.screen(containing: .zero, in: []))
    }

    // NSEvent.mouseLocation reports y == frame.maxY on a screen's top row; CGRect.contains
    // excludes that boundary, so the point must still resolve to the screen it's on.
    func testPointOnSecondaryScreenTopRowResolvesToThatScreen() {
        let main = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: visible)
        let secondary = ScreenGeometry(frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
                                       visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1055))
        let topRow = CGPoint(x: 2000, y: 1080)
        XCTAssertEqual(PanelPlacement.screen(containing: topRow, in: [main, secondary]), secondary)
    }
}
