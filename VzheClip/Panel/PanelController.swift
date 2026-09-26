import AppKit
import SwiftUI

/// Borderless panel that can take keyboard focus without activating VzheClip,
/// so the app the user was typing in stays frontmost (required for auto-paste).
private final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let panelSize = CGSize(width: 360, height: 520)

    private let panel: HistoryPanel
    private let viewModel: HistoryViewModel
    private var keyMonitor: Any?

    init(viewModel: HistoryViewModel) {
        self.viewModel = viewModel
        panel = HistoryPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()

        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.delegate = self

        let hosting = NSHostingView(rootView: HistoryView(model: viewModel))
        hosting.frame = NSRect(origin: .zero, size: Self.panelSize)
        panel.contentView = hosting

        viewModel.onClose = { [weak self] in self?.hide() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        viewModel.reset()
        let mouse = NSEvent.mouseLocation
        let screens = NSScreen.screens.map { ScreenGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        if let screen = PanelPlacement.screen(containing: mouse, in: screens) {
            panel.setFrameOrigin(PanelPlacement.origin(
                cursor: mouse, panelSize: Self.panelSize, visibleFrame: screen.visibleFrame
            ))
        }
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        removeKeyMonitor()
    }

    // Clicking anywhere outside the panel takes key status away → close.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // NSEvent/NSWindow aren't Sendable, so only Sendable primitives are extracted here
            // and carried across into the MainActor-isolated closure below.
            let windowID = event.window.map(ObjectIdentifier.init)
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags
            let characters = event.charactersIgnoringModifiers
            let consumed = MainActor.assumeIsolated {
                self?.handle(windowID: windowID, keyCode: keyCode, modifiers: modifiers, characters: characters) ?? false
            }
            return consumed ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns true when the key was consumed (event should not continue to the search field).
    private func handle(
        windowID: ObjectIdentifier?, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String?
    ) -> Bool {
        guard windowID == ObjectIdentifier(panel) else { return false }
        // An input method (e.g. Pinyin, Hangul) composing marked text owns Return/arrows/Esc/⌫
        // while it's active; claiming them here would break CJK search entry.
        if let textView = panel.firstResponder as? NSTextView, textView.hasMarkedText() {
            return false
        }
        guard let command = PanelKeyCommand.from(
            keyCode: keyCode,
            modifiers: modifiers,
            characters: characters,
            searchIsEmpty: viewModel.query.isEmpty
        )
        else { return false }
        viewModel.perform(command)
        return true
    }
}
