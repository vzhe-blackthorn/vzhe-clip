import AppKit
import KeyboardShortcuts
import os
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    /// Unit tests run hosted inside the app; skip all OS side effects in that case.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private let logger = Logger(subsystem: "com.vzh.VzheClip", category: "App")
    private let prefs = Preferences()

    private var statusItem: NSStatusItem?
    private var store: HistoryStore?
    private var monitor: ClipboardMonitor?
    private var panel: PanelController?
    private var paster: Paster?
    private var settingsWindow: NSWindow?
    private var settingsModel: SettingsModel?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }
        do {
            try start()
        } catch {
            logger.fault("Startup failed: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = "VzheClip couldn't start"
            alert.informativeText = error.localizedDescription
            NSApp.activate()
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    private func start() throws {
        installMainMenu()

        let support = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("VzheClip", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)

        let images = try ImageStore(directory: support.appendingPathComponent("images", isDirectory: true))
        let store = try HistoryStore.openOnDisk(
            directory: support, images: images, limit: prefs.historyLimit, appName: AppInfo.displayName(bundleID:)
        )
        try store.removeOrphanedImages()

        let monitor = ClipboardMonitor()
        monitor.isPaused = prefs.isCapturePaused
        monitor.denyList = { [prefs] in Set(prefs.denyList) }
        monitor.onCapture = { [weak store, logger] item, source in
            do { try store?.add(item, sourceApp: source) } catch {
                logger.error("Storing clip failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        monitor.start()

        let viewModel = HistoryViewModel(store: store)
        let panel = PanelController(viewModel: viewModel)
        let paster = Paster(store: store, monitor: monitor)
        viewModel.onPaste = { [weak paster, weak panel] item in
            paster?.paste(item, hidePanel: { panel?.hide() })
        }
        store.onChange = { [weak viewModel] in viewModel?.reload() }

        HotkeyManager.register { [weak panel] in panel?.toggle() }

        self.store = store
        self.monitor = monitor
        self.panel = panel
        self.paster = paster

        setUpStatusItem()
        runFirstLaunchIfNeeded()
    }

    // MARK: - Main menu

    /// LSUIElement apps get no main menu for free, so ⌘C/⌘V/⌘X/⌘A/⌘Z would otherwise do
    /// nothing in text fields (the panel search field, the Settings deny-list field).
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = NSMenu()
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        // "undo:"/"redo:" aren't exposed by any public Swift-visible class; NSResponder
        // handles them for the first responder's undo manager without further wiring.
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "VzheClip")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if !PermissionsHelper.isTrusted {
            menu.addItem(menuItem("⚠︎ Enable Accessibility for Auto-Paste…", #selector(openAccessibility)))
            menu.addItem(.separator())
        }
        let show = menuItem("Show History", #selector(showHistory))
        show.setShortcut(for: .toggleHistory)
        menu.addItem(show)
        let pause = menuItem("Pause Capture", #selector(togglePause))
        pause.state = (monitor?.isPaused ?? false) ? .on : .off
        menu.addItem(pause)
        menu.addItem(menuItem("Clear History…", #selector(clearHistory)))
        menu.addItem(.separator())
        let settings = menuItem("Settings…", #selector(showSettings))
        settings.keyEquivalent = ","
        menu.addItem(settings)
        menu.addItem(NSMenuItem(title: "Quit VzheClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func showHistory() {
        panel?.show()
    }

    @objc private func togglePause() {
        guard let monitor else { return }
        monitor.isPaused.toggle()
        prefs.isCapturePaused = monitor.isPaused
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear all unpinned items?"
        alert.informativeText = "Pinned items are kept."
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        let response = alert.runModal()
        // VzheClip has no window of its own once the alert is gone; step back down so the
        // app the user was working in (not VzheClip) is frontmost for their next ⌥V paste.
        NSApp.hide(nil)
        guard response == .alertFirstButtonReturn else { return }
        do { try store?.clearUnpinned() } catch {
            logger.error("Clear failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    @objc private func openAccessibility() {
        PermissionsHelper.requestTrust()
        PermissionsHelper.openAccessibilitySettings()
    }

    @objc private func showSettings() {
        guard let store else { return }
        if settingsWindow == nil {
            let model = SettingsModel(
                prefs: prefs, store: store,
                isLaunchAtLoginEnabled: { LoginItem.isEnabled },
                applyLaunchAtLogin: { LoginItem.setEnabled($0) }
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "VzheClip Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            settingsModel = model
            settingsWindow = window
        }
        // The cached window can go stale (launch-at-login toggled outside the app, limit/
        // deny-list changed elsewhere), so re-read everything each time it's shown.
        settingsModel?.refresh()
        NSApp.activate()
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - First run

    private func runFirstLaunchIfNeeded() {
        guard !prefs.hasCompletedOnboarding else { return }
        prefs.hasCompletedOnboarding = true
        LoginItem.setEnabled(true)

        let view = OnboardingView(
            onGrant: { PermissionsHelper.requestTrust() },
            onDone: { [weak self] in self?.onboardingWindow?.close() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome to VzheClip"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        onboardingWindow = window
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    /// The Settings and onboarding windows are VzheClip's only windows; once either closes,
    /// step back down so the previously frontmost app (not VzheClip) is frontmost again for
    /// the user's next ⌥V paste.
    func windowWillClose(_ notification: Notification) {
        NSApp.hide(nil)
    }
}
