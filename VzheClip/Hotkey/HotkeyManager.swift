import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleHistory = Self("toggleHistory", initial: .init(.v, modifiers: [.option]))
}

@MainActor
enum HotkeyManager {
    static func register(onToggle: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .toggleHistory, action: onToggle)
    }
}
