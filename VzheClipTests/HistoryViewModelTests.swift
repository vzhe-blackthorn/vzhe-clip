import XCTest
@testable import VzheClip

@MainActor
final class HistoryViewModelTests: XCTestCase {
    /// Store with items c (newest), b, a.
    private func makeModel() throws -> (HistoryViewModel, HistoryStore) {
        let store = try makeHistoryStore()
        for text in ["a", "b", "c"] { try store.add(.text(text), sourceApp: nil) }
        let model = HistoryViewModel(store: store)
        model.isAccessibilityTrusted = { true }
        model.reset()
        return (model, store)
    }

    func testResetSelectsFirstAndClearsQuery() throws {
        let (model, _) = try makeModel()
        model.query = "b"
        model.reset()
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(model.items.map(\.text), ["c", "b", "a"])
        XCTAssertEqual(model.selectedIndex, 0)
    }

    func testResetBumpsFocusRequest() throws {
        let (model, _) = try makeModel()
        let before = model.focusRequest
        model.reset()
        XCTAssertEqual(model.focusRequest, before + 1)
    }

    func testMoveSelectionClampsAtEnds() throws {
        let (model, _) = try makeModel()
        model.moveSelection(by: -1)
        XCTAssertEqual(model.selectedIndex, 0)
        model.moveSelection(by: 1)
        model.moveSelection(by: 1)
        model.moveSelection(by: 1)
        XCTAssertEqual(model.selectedIndex, 2)
    }

    // Review Focus #5
    func testSearchKeepsSelectionValid() throws {
        let (model, _) = try makeModel()
        model.moveSelection(by: 2)            // "a"
        model.query = "b"
        XCTAssertEqual(model.items.map(\.text), ["b"])
        XCTAssertEqual(model.selectedIndex, 0)
        model.query = "zzz"
        XCTAssertNil(model.selectedID)
        model.query = ""
        XCTAssertEqual(model.selectedIndex, 0)
    }

    // Review Focus #5
    func testDeletingSelectedLastItemSelectsNewLast() throws {
        let (model, _) = try makeModel()
        model.moveSelection(by: 2)
        model.perform(.delete)
        XCTAssertEqual(model.items.map(\.text), ["c", "b"])
        XCTAssertEqual(model.items[try XCTUnwrap(model.selectedIndex)].text, "b")
    }

    func testDeletingSelectedMiddleItemSelectsNext() throws {
        let (model, _) = try makeModel()
        model.moveSelection(by: 1)
        model.perform(.delete)
        XCTAssertEqual(model.items[try XCTUnwrap(model.selectedIndex)].text, "a")
    }

    func testDeletingOnlyItemClearsSelection() throws {
        let store = try makeHistoryStore()
        try store.add(.text("solo"), sourceApp: nil)
        let model = HistoryViewModel(store: store)
        model.isAccessibilityTrusted = { true }
        model.reset()
        model.perform(.delete)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNil(model.selectedID)
    }

    func testPasteCommandsCallOnPaste() throws {
        let (model, _) = try makeModel()
        var pasted: [String?] = []
        model.onPaste = { pasted.append($0.text) }
        model.perform(.paste)
        model.perform(.pasteIndex(2))
        model.perform(.pasteIndex(7))          // out of range → ignored
        XCTAssertEqual(pasted, ["c", "a"])
    }

    func testTogglePinMovesItemToTop() throws {
        let (model, _) = try makeModel()
        model.moveSelection(by: 2)
        model.perform(.togglePin)
        XCTAssertEqual(model.items.first?.text, "a")
        XCTAssertEqual(model.items.first?.isPinned, true)
        XCTAssertEqual(model.items[try XCTUnwrap(model.selectedIndex)].text, "a")
    }

    func testCloseCallsOnClose() throws {
        let (model, _) = try makeModel()
        var closed = false
        model.onClose = { closed = true }
        model.perform(.close)
        XCTAssertTrue(closed)
    }

    func testBannerReflectsAccessibilityTrust() throws {
        let (model, _) = try makeModel()
        model.isAccessibilityTrusted = { false }
        model.reset()
        XCTAssertTrue(model.showAccessibilityBanner)
        model.isAccessibilityTrusted = { true }
        model.reset()
        XCTAssertFalse(model.showAccessibilityBanner)
    }
}
