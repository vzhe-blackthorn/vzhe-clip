import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Unit tests run hosted inside the app; skip all OS side effects in that case.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "VzheClip")
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit VzheClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }
}
