import AppKit
import Carbon.HIToolbox
import os

@MainActor
final class Paster {
    var isTrusted: () -> Bool = { PermissionsHelper.isTrusted }
    var postCommandV: () -> Void = { Paster.sendCommandV() }

    private let pasteboard: NSPasteboard
    private let store: HistoryStore
    private let monitor: ClipboardMonitor
    private let logger = Logger(subsystem: "com.vzh.VzheClip", category: "Paster")

    init(pasteboard: NSPasteboard = .general, store: HistoryStore, monitor: ClipboardMonitor) {
        self.pasteboard = pasteboard
        self.store = store
        self.monitor = monitor
    }

    /// Puts `item` on the clipboard, hides the panel and, if Accessibility is granted,
    /// sends ⌘V to the frontmost app. Returns whether ⌘V was sent.
    ///
    /// If the item's data can't be written (e.g. an image whose file went missing), the
    /// pasteboard is left untouched, the panel is still hidden, and no ⌘V is posted.
    @discardableResult
    func paste(_ item: ClipItem, hidePanel: () -> Void) -> Bool {
        guard write(item) else {
            hidePanel()
            return false
        }
        monitor.ignoreChange(pasteboard.changeCount)
        if let id = item.id {
            do { try store.markUsed(id: id) } catch {
                logger.error("markUsed failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        hidePanel()

        guard isTrusted() else { return false }
        Task { @MainActor [postCommandV] in
            // Give the target app a moment to regain key focus after the panel hides.
            try? await Task.sleep(for: .milliseconds(50))
            postCommandV()
        }
        return true
    }

    /// Writes `item` to the pasteboard. Returns whether the write happened; on failure
    /// (e.g. the image file backing `item` is missing) the pasteboard is left untouched.
    @discardableResult
    func write(_ item: ClipItem) -> Bool {
        switch item.kind {
        case .text:
            pasteboard.clearContents()
            pasteboard.setString(item.text ?? "", forType: .string)
            return true
        case .image:
            guard let url = store.imageURL(for: item), let png = try? Data(contentsOf: url) else {
                logger.error("Image file missing for item \(item.id ?? -1, privacy: .public)")
                return false
            }
            pasteboard.clearContents()
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            pasteboard.setData(png, forType: .png)
            if let tiff = NSImage(data: png)?.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
            return true
        }
    }

    static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
