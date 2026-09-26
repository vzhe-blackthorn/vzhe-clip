import AppKit
import Carbon.HIToolbox
import XCTest
@testable import VzheClip

@MainActor
final class PanelKeyCommandTests: XCTestCase {
    private func command(_ keyCode: Int, _ modifiers: NSEvent.ModifierFlags = [], _ chars: String? = nil, searchIsEmpty: Bool = true) -> PanelKeyCommand? {
        PanelKeyCommand.from(keyCode: UInt16(keyCode), modifiers: modifiers, characters: chars, searchIsEmpty: searchIsEmpty)
    }

    func testNavigationAndActions() {
        XCTAssertEqual(command(kVK_UpArrow, [.numericPad, .function]), .moveUp)
        XCTAssertEqual(command(kVK_DownArrow, [.numericPad, .function]), .moveDown)
        XCTAssertEqual(command(kVK_Return), .paste)
        XCTAssertEqual(command(kVK_ANSI_KeypadEnter), .paste)
        XCTAssertEqual(command(kVK_Escape), .close)
    }

    func testCommandDigitsPasteByIndex() {
        XCTAssertEqual(command(kVK_ANSI_1, .command, "1"), .pasteIndex(0))
        XCTAssertEqual(command(kVK_ANSI_9, .command, "9"), .pasteIndex(8))
        XCTAssertNil(command(kVK_ANSI_0, .command, "0"))
        XCTAssertNil(command(kVK_ANSI_1, [], "1"), "plain digits go to the search field")
        XCTAssertNil(command(kVK_ANSI_1, [.command, .shift], "1"))
    }

    func testCommandPTogglesPin() {
        XCTAssertEqual(command(kVK_ANSI_P, .command, "p"), .togglePin)
        XCTAssertNil(command(kVK_ANSI_P, [], "p"))
    }

    func testDeleteOnlyWhenSearchIsEmpty() {
        XCTAssertEqual(command(kVK_Delete, [], nil, searchIsEmpty: true), .delete)
        XCTAssertNil(command(kVK_Delete, [], nil, searchIsEmpty: false), "backspace edits the search text")
    }

    func testOrdinaryTypingIsNotACommand() {
        XCTAssertNil(command(kVK_ANSI_A, [], "a"))
        XCTAssertNil(command(kVK_Space, [], " "))
    }
}
