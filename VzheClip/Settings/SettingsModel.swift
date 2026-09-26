import Foundation
import Observation
import os

@MainActor
@Observable
final class SettingsModel {
    private(set) var historyLimit: Int
    private(set) var launchAtLogin: Bool
    private(set) var denyList: [String]
    var newDenyEntry = ""
    var isConfirmingClear = false

    @ObservationIgnored private let prefs: Preferences
    @ObservationIgnored private let store: HistoryStore
    @ObservationIgnored private let isLaunchAtLoginEnabled: () -> Bool
    @ObservationIgnored private let applyLaunchAtLogin: (Bool) -> Void
    @ObservationIgnored private let logger = Logger(subsystem: "com.vzh.VzheClip", category: "Settings")

    init(
        prefs: Preferences, store: HistoryStore,
        isLaunchAtLoginEnabled: @escaping () -> Bool,
        applyLaunchAtLogin: @escaping (Bool) -> Void
    ) {
        self.prefs = prefs
        self.store = store
        self.isLaunchAtLoginEnabled = isLaunchAtLoginEnabled
        self.applyLaunchAtLogin = applyLaunchAtLogin
        historyLimit = prefs.historyLimit
        launchAtLogin = isLaunchAtLoginEnabled()
        denyList = prefs.denyList
    }

    /// Re-reads everything that can have changed underneath a cached Settings window:
    /// the actual launch-at-login status, and the history limit / deny-list from prefs.
    func refresh() {
        historyLimit = prefs.historyLimit
        denyList = prefs.denyList
        launchAtLogin = isLaunchAtLoginEnabled()
    }

    func setHistoryLimit(_ value: Int) {
        prefs.historyLimit = value
        historyLimit = prefs.historyLimit
        do { try store.setLimit(historyLimit) } catch {
            logger.error("Applying limit failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Optimistic UI is wrong here: applying the change can silently fail (SMAppService
    /// throws, or the user has to approve it in System Settings), so re-read the actual
    /// status afterward instead of assuming the toggle took effect.
    func setLaunchAtLogin(_ enabled: Bool) {
        applyLaunchAtLogin(enabled)
        launchAtLogin = isLaunchAtLoginEnabled()
    }

    func addDenyEntry() {
        let entry = newDenyEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        newDenyEntry = ""
        guard !entry.isEmpty, !denyList.contains(entry) else { return }
        denyList.append(entry)
        prefs.denyList = denyList
    }

    func removeDenyEntry(_ entry: String) {
        denyList.removeAll { $0 == entry }
        prefs.denyList = denyList
    }

    func clearHistory() {
        do { try store.clearUnpinned() } catch {
            logger.error("Clear failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
