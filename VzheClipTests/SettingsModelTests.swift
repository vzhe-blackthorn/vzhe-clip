import XCTest
@testable import VzheClip

@MainActor
final class SettingsModelTests: XCTestCase {
    private func makeModel(store: HistoryStore? = nil) throws -> (SettingsModel, Preferences, HistoryStore, () -> [Bool]) {
        let suite = "VzheClipTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        let store = try store ?? makeHistoryStore()
        var loginCalls: [Bool] = []
        let model = SettingsModel(prefs: prefs, store: store, isLaunchAtLoginEnabled: false,
                                  applyLaunchAtLogin: { loginCalls.append($0) })
        return (model, prefs, store, { loginCalls })
    }

    // Review Focus #3
    func testLoweringLimitPrunesImmediatelyAndKeepsPins() throws {
        let store = try makeHistoryStore(limit: 20)
        let pinned = try store.add(.text("pinned"), sourceApp: nil)
        try store.togglePin(id: XCTUnwrap(pinned.id))
        for n in 1...12 { try store.add(.text("t\(n)"), sourceApp: nil) }
        let (model, prefs, _, _) = try makeModel(store: store)

        model.setHistoryLimit(5)

        XCTAssertEqual(model.historyLimit, 5)
        XCTAssertEqual(prefs.historyLimit, 5)
        let items = try store.items()
        XCTAssertEqual(items.count, 6)
        XCTAssertTrue(items.contains { $0.text == "pinned" })
    }

    func testLimitIsClamped() throws {
        let (model, _, store, _) = try makeModel()
        model.setHistoryLimit(0)
        XCTAssertEqual(model.historyLimit, 5)
        XCTAssertEqual(store.limit, 5)
    }

    func testLaunchAtLoginIsApplied() throws {
        let (model, _, _, calls) = try makeModel()
        model.setLaunchAtLogin(true)
        XCTAssertTrue(model.launchAtLogin)
        XCTAssertEqual(calls(), [true])
    }

    func testAddDenyEntryTrimsAndIgnoresDuplicatesAndBlanks() throws {
        let (model, prefs, _, _) = try makeModel()
        model.newDenyEntry = "  com.example.app  "
        model.addDenyEntry()
        model.newDenyEntry = "com.example.app"
        model.addDenyEntry()
        model.newDenyEntry = "   "
        model.addDenyEntry()

        XCTAssertEqual(model.denyList.filter { $0 == "com.example.app" }.count, 1)
        XCTAssertEqual(prefs.denyList, model.denyList)
        XCTAssertEqual(model.newDenyEntry, "")
    }

    func testRemoveDenyEntry() throws {
        let (model, prefs, _, _) = try makeModel()
        model.removeDenyEntry("com.apple.keychainaccess")
        XCTAssertFalse(prefs.denyList.contains("com.apple.keychainaccess"))
    }

    func testClearHistoryKeepsPins() throws {
        let store = try makeHistoryStore()
        let pinned = try store.add(.text("pinned"), sourceApp: nil)
        try store.togglePin(id: XCTUnwrap(pinned.id))
        try store.add(.text("gone"), sourceApp: nil)
        let (model, _, _, _) = try makeModel(store: store)

        model.clearHistory()

        XCTAssertEqual(try store.items().map(\.text), ["pinned"])
    }
}
