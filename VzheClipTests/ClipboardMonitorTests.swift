import AppKit
import XCTest
@testable import VzheClip

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    private func makeMonitor() -> (ClipboardMonitor, NSPasteboard, () -> [(CapturedItem, String?)]) {
        let pasteboard = NSPasteboard.withUniqueName()
        addTeardownBlock { pasteboard.releaseGlobally() }
        let monitor = ClipboardMonitor(pasteboard: pasteboard)
        monitor.frontmostBundleID = { "com.apple.Safari" }
        var captured: [(CapturedItem, String?)] = []
        monitor.onCapture = { captured.append(($0, $1)) }
        return (monitor, pasteboard, { captured })
    }

    private func copy(_ string: String, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    func testIgnoresContentPresentAtLaunch() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        copy("before launch", to: pasteboard)
        let monitor = ClipboardMonitor(pasteboard: pasteboard)
        var count = 0
        monitor.onCapture = { _, _ in count += 1 }

        monitor.poll()

        XCTAssertEqual(count, 0)
    }

    func testCapturesEachChangeOnceWithSourceApp() {
        let (monitor, pasteboard, captured) = makeMonitor()
        copy("one", to: pasteboard)
        monitor.poll()
        monitor.poll()

        XCTAssertEqual(captured().map(\.0), [.text("one")])
        XCTAssertEqual(captured().first?.1, "com.apple.Safari")
    }

    func testIgnoredChangeIsSkippedButLaterChangesAreNot() {
        let (monitor, pasteboard, captured) = makeMonitor()
        copy("ours", to: pasteboard)
        monitor.ignoreChange(pasteboard.changeCount)
        monitor.poll()
        copy("theirs", to: pasteboard)
        monitor.poll()

        XCTAssertEqual(captured().map(\.0), [.text("theirs")])
    }

    func testPausedMonitorDoesNotCaptureAndDoesNotReplayLater() {
        let (monitor, pasteboard, captured) = makeMonitor()
        monitor.isPaused = true
        copy("while paused", to: pasteboard)
        monitor.poll()
        monitor.isPaused = false
        monitor.poll()

        XCTAssertTrue(captured().isEmpty)
    }

    func testDenyListedFrontmostAppIsSkipped() {
        let (monitor, pasteboard, captured) = makeMonitor()
        monitor.frontmostBundleID = { "com.1password.1password" }
        monitor.denyList = { ["com.1password.1password"] }
        copy("secret", to: pasteboard)
        monitor.poll()

        XCTAssertTrue(captured().isEmpty)
    }
}
