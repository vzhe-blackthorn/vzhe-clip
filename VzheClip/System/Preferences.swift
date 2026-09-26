import Foundation

@MainActor
final class Preferences {
    static let defaultDenyList = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.apple.keychainaccess",
    ]

    private enum Key {
        static let historyLimit = "historyLimit"
        static let denyList = "denyList"
        static let isCapturePaused = "isCapturePaused"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var historyLimit: Int {
        get { HistoryStore.clampLimit(defaults.object(forKey: Key.historyLimit) as? Int ?? HistoryStore.defaultLimit) }
        set { defaults.set(HistoryStore.clampLimit(newValue), forKey: Key.historyLimit) }
    }

    var denyList: [String] {
        get { defaults.stringArray(forKey: Key.denyList) ?? Self.defaultDenyList }
        set { defaults.set(newValue, forKey: Key.denyList) }
    }

    var isCapturePaused: Bool {
        get { defaults.bool(forKey: Key.isCapturePaused) }
        set { defaults.set(newValue, forKey: Key.isCapturePaused) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }
}
