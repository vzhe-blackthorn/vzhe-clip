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

    /// Returns nil for keys that should reach the search field.
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

        guard mods == .command, let key = characters?.lowercased() else { return nil }
        if key == "p" { return .togglePin }
        if let digit = Int(key), (1...9).contains(digit) { return .pasteIndex(digit - 1) }
        return nil
    }
}
