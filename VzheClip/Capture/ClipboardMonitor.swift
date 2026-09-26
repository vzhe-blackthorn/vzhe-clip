import AppKit

/// Polls the pasteboard's change count (macOS has no change notification).
@MainActor
final class ClipboardMonitor {
    var onCapture: ((CapturedItem, String?) -> Void)?
    var isPaused = false
    var denyList: () -> Set<String> = { [] }
    var frontmostBundleID: () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }

    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int
    private var ignoredChangeCount: Int?
    private var timer: Timer?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        lastChangeCount = pasteboard.changeCount
    }

    func start(interval: TimeInterval = 0.5) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = interval / 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call right after VzheClip itself writes to the pasteboard so that write isn't recorded.
    func ignoreChange(_ changeCount: Int) {
        ignoredChangeCount = changeCount
    }

    func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if count == ignoredChangeCount {
            ignoredChangeCount = nil
            return
        }
        guard !isPaused else { return }
        let source = frontmostBundleID()
        if let source, denyList().contains(source) { return }
        guard let item = ItemExtractor.extract(from: pasteboard) else { return }
        onCapture?(item, source)
    }
}
