import AppKit
import Observation
import os

@MainActor
@Observable
final class HistoryViewModel {
    var query = "" {
        didSet { if query != oldValue { reload() } }
    }
    private(set) var items: [ClipItem] = []
    var selectedID: Int64?
    private(set) var showAccessibilityBanner = false
    /// Incremented on every `reset()`; the view focuses the search field when it changes.
    private(set) var focusRequest = 0

    @ObservationIgnored var isAccessibilityTrusted: () -> Bool = { PermissionsHelper.isTrusted }
    @ObservationIgnored var onPaste: ((ClipItem) -> Void)?
    @ObservationIgnored var onClose: (() -> Void)?
    // If the app was never prompted, it isn't listed in System Settings yet, so ask for
    // trust (showing the system prompt) before opening the pane.
    @ObservationIgnored var openAccessibilitySettings: () -> Void = {
        PermissionsHelper.requestTrust()
        PermissionsHelper.openAccessibilitySettings()
    }

    @ObservationIgnored private let store: HistoryStore
    @ObservationIgnored private let logger = Logger(subsystem: "com.vzh.VzheClip", category: "HistoryViewModel")

    init(store: HistoryStore) {
        self.store = store
    }

    var selectedIndex: Int? {
        items.firstIndex { $0.id == selectedID }
    }

    /// Called every time the panel opens.
    func reset() {
        query = ""
        reload()
        selectedID = items.first?.id
        showAccessibilityBanner = !isAccessibilityTrusted()
        focusRequest += 1
    }

    func reload() {
        do {
            items = try store.items(matching: query)
        } catch {
            logger.error("Loading history failed: \(error.localizedDescription, privacy: .public)")
            items = []
        }
        if selectedIndex == nil { selectedID = items.first?.id }
    }

    func moveSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        let next = min(max((selectedIndex ?? 0) + delta, 0), items.count - 1)
        selectedID = items[next].id
    }

    func perform(_ command: PanelKeyCommand) {
        switch command {
        case .moveUp: moveSelection(by: -1)
        case .moveDown: moveSelection(by: 1)
        case .paste: pasteSelected()
        case .pasteIndex(let index): paste(at: index)
        case .togglePin: if let index = selectedIndex { togglePin(items[index]) }
        case .delete: if let index = selectedIndex { delete(items[index]) }
        case .close: onClose?()
        }
    }

    func paste(_ item: ClipItem) {
        onPaste?(item)
    }

    func paste(at index: Int) {
        guard items.indices.contains(index) else { return }
        paste(items[index])
    }

    func pasteSelected() {
        if let index = selectedIndex { paste(items[index]) }
    }

    func togglePin(_ item: ClipItem) {
        guard let id = item.id else { return }
        do { try store.togglePin(id: id) } catch {
            logger.error("Pin failed: \(error.localizedDescription, privacy: .public)")
        }
        reload()
    }

    func delete(_ item: ClipItem) {
        guard let id = item.id, let index = items.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = selectedID == id
        do { try store.delete(id: id) } catch {
            logger.error("Delete failed: \(error.localizedDescription, privacy: .public)")
        }
        reload()
        if wasSelected {
            selectedID = items.isEmpty ? nil : items[min(index, items.count - 1)].id
        }
    }

    func thumbnail(for item: ClipItem) -> NSImage? {
        store.thumbnailURL(for: item).flatMap(NSImage.init(contentsOf:))
    }

    func appIcon(for item: ClipItem) -> NSImage? {
        item.sourceApp.flatMap(AppInfo.icon(bundleID:))
    }
}
