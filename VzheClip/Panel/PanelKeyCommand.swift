import AppKit
import Carbon.HIToolbox

enum PanelKeyCommand: Equatable {
    case moveUp
    case moveDown
    case paste
    /// 0-based index into the visible list (⌘1 → 0).
    case pasteIndex(Int)
    case togglePin
    case delete
    case close

    /// ⌘1…⌘9 and ⌘P, keyed by physical position (`kVK_ANSI_*`) rather than the character
    /// the active keyboard layout produces for that key: AZERTY turns ⌘1 into "&", and
    /// Cyrillic layouts turn ⌘P into "з", but the *position* of the key is layout-independent.
    private static let digitKeyCodes: [Int: Int] = [
        kVK_ANSI_1: 0, kVK_ANSI_2: 1, kVK_ANSI_3: 2, kVK_ANSI_4: 3, kVK_ANSI_5: 4,
        kVK_ANSI_6: 5, kVK_ANSI_7: 6, kVK_ANSI_8: 7, kVK_ANSI_9: 8,
    ]

    /// Returns nil for keys that should reach the search field. `characters` is unused for
    /// the ⌘-digit/⌘P mapping (see `digitKeyCodes`) but is kept for callers/tests.
    static func from(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String?, searchIsEmpty: Bool) -> PanelKeyCommand? {
        let mods = modifiers.intersection([.command, .option, .control, .shift])
        switch Int(keyCode) {
        case kVK_UpArrow: return .moveUp
        case kVK_DownArrow: return .moveDown
        case kVK_Return, kVK_ANSI_KeypadEnter: return .paste
        case kVK_Escape: return .close
        case kVK_Delete where searchIsEmpty && mods.isEmpty: return .delete
        default: break
        }

        guard mods == .command else { return nil }
        if Int(keyCode) == kVK_ANSI_P { return .togglePin }
        if let index = digitKeyCodes[Int(keyCode)] { return .pasteIndex(index) }
        return nil
    }
}
