import XCTest
@testable import VzheClip

@MainActor
final class PreferencesTests: XCTestCase {
    private func makePreferences() -> Preferences {
        let suite = "VzheClipTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return Preferences(defaults: defaults)
    }

    func testDefaults() {
        let prefs = makePreferences()
        XCTAssertEqual(prefs.historyLimit, 20)
        XCTAssertEqual(prefs.denyList, ["com.1password.1password", "com.agilebits.onepassword7", "com.apple.keychainaccess"])
        XCTAssertFalse(prefs.isCapturePaused)
        XCTAssertFalse(prefs.hasCompletedOnboarding)
    }

    func testHistoryLimitIsClamped() {
        let prefs = makePreferences()
        prefs.historyLimit = 1
        XCTAssertEqual(prefs.historyLimit, 5)
        prefs.historyLimit = 1000
        XCTAssertEqual(prefs.historyLimit, 100)
        prefs.historyLimit = 42
        XCTAssertEqual(prefs.historyLimit, 42)
    }

    func testValuesPersist() {
        let prefs = makePreferences()
        prefs.denyList = ["com.example.app"]
        prefs.isCapturePaused = true
        prefs.hasCompletedOnboarding = true
        XCTAssertEqual(prefs.denyList, ["com.example.app"])
        XCTAssertTrue(prefs.isCapturePaused)
        XCTAssertTrue(prefs.hasCompletedOnboarding)
    }

    func testEmptyDenyListIsRespected() {
        let prefs = makePreferences()
        prefs.denyList = []
        XCTAssertEqual(prefs.denyList, [])
    }

    func testAppInfoResolvesFinder() {
        XCTAssertEqual(AppInfo.displayName(bundleID: "com.apple.finder"), "Finder")
        XCTAssertNotNil(AppInfo.icon(bundleID: "com.apple.finder"))
        XCTAssertNil(AppInfo.displayName(bundleID: "com.example.does-not-exist"))
    }
}
