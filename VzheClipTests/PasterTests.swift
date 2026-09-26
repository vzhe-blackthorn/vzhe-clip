import AppKit
import XCTest
@testable import VzheClip

@MainActor
final class PasterTests: XCTestCase {
    private struct Fixture {
        let pasteboard: NSPasteboard
        let store: HistoryStore
        let monitor: ClipboardMonitor
        let paster: Paster
    }

    private func makeFixture(trusted: Bool) throws -> Fixture {
        let pasteboard = NSPasteboard.withUniqueName()
        addTeardownBlock { pasteboard.releaseGlobally() }
        let store = try makeHistoryStore()
        let monitor = ClipboardMonitor(pasteboard: pasteboard)
        let paster = Paster(pasteboard: pasteboard, store: store, monitor: monitor)
        paster.isTrusted = { trusted }
        return Fixture(pasteboard: pasteboard, store: store, monitor: monitor, paster: paster)
    }

    func testCopyOnlyWhenNotTrusted() throws {
        let f = try makeFixture(trusted: false)
        let item = try f.store.add(.text("hello"), sourceApp: nil)
        var posted = false
        f.paster.postCommandV = { posted = true }
        var hidden = false

        let sent = f.paster.paste(item, hidePanel: { hidden = true })

        XCTAssertFalse(sent)
        XCTAssertTrue(hidden)
        XCTAssertFalse(posted)
        XCTAssertEqual(f.pasteboard.string(forType: .string), "hello")
    }

    // Review Focus #1
    func testPastingDoesNotCreateANewHistoryEntry() throws {
        let f = try makeFixture(trusted: false)
        let older = try f.store.add(.text("older"), sourceApp: nil)
        try f.store.add(.text("newer"), sourceApp: nil)
        var recaptured: [CapturedItem] = []
        f.monitor.onCapture = { item, _ in recaptured.append(item) }

        f.paster.paste(older, hidePanel: {})
        f.monitor.poll()

        XCTAssertTrue(recaptured.isEmpty)
        XCTAssertEqual(try f.store.items().map(\.text), ["older", "newer"], "pasted item is bumped, not duplicated")
    }

    func testPostsCommandVWhenTrusted() async throws {
        let f = try makeFixture(trusted: true)
        let item = try f.store.add(.text("go"), sourceApp: nil)
        let posted = expectation(description: "⌘V posted")
        f.paster.postCommandV = { posted.fulfill() }

        let sent = f.paster.paste(item, hidePanel: {})

        XCTAssertTrue(sent)
        await fulfillment(of: [posted], timeout: 1)
    }

    func testImageIsWrittenAsPNGAndTIFF() throws {
        let f = try makeFixture(trusted: false)
        let png = TestImages.png(width: 8, height: 8)
        let item = try f.store.add(.image(png: png, width: 8, height: 8), sourceApp: nil)

        f.paster.write(item)

        XCTAssertEqual(f.pasteboard.data(forType: .png), png)
        XCTAssertNotNil(f.pasteboard.data(forType: .tiff))
    }

    // Fix round 1: missing image file must not wipe the clipboard or fire ⌘V.
    func testMissingImageFileLeavesClipboardUntouchedAndSkipsPaste() async throws {
        let f = try makeFixture(trusted: true)
        f.pasteboard.clearContents()
        f.pasteboard.setString("previous", forType: .string)
        let png = TestImages.png(width: 8, height: 8)
        let item = try f.store.add(.image(png: png, width: 8, height: 8), sourceApp: nil)
        if let url = f.store.imageURL(for: item) {
            try FileManager.default.removeItem(at: url)
        }
        let notPosted = expectation(description: "⌘V not posted")
        notPosted.isInverted = true
        f.paster.postCommandV = { notPosted.fulfill() }
        var hidden = false

        let sent = f.paster.paste(item, hidePanel: { hidden = true })

        XCTAssertFalse(sent)
        XCTAssertTrue(hidden)
        XCTAssertEqual(f.pasteboard.string(forType: .string), "previous")
        await fulfillment(of: [notPosted], timeout: 0.2)
    }
}
