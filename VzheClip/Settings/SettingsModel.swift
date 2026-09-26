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
    @ObservationIgnored private let applyLaunchAtLogin: (Bool) -> Void
    @ObservationIgnored private let logger = Logger(subsystem: "com.vzh.VzheClip", category: "Settings")

    init(prefs: Preferences, store: HistoryStore, isLaunchAtLoginEnabled: Bool, applyLaunchAtLogin: @escaping (Bool) -> Void) {
        self.prefs = prefs
        self.store = store
        self.applyLaunchAtLogin = applyLaunchAtLogin
        historyLimit = prefs.historyLimit
        launchAtLogin = isLaunchAtLoginEnabled
        denyList = prefs.denyList
    }

    func setHistoryLimit(_ value: Int) {
        prefs.historyLimit = value
        historyLimit = prefs.historyLimit
        do { try store.setLimit(historyLimit) } catch {
            logger.error("Applying limit failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        applyLaunchAtLogin(enabled)
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
