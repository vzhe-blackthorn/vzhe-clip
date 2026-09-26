import XCTest
@testable import VzheClip

@MainActor
final class HistoryStoreManagementTests: XCTestCase {
    func testPinnedItemsComeFirstAndDoNotCountTowardLimit() throws {
        let store = try makeHistoryStore(limit: 5)
        let pinned = try store.add(.text("keep me"), sourceApp: nil)
        try store.togglePin(id: XCTUnwrap(pinned.id))
        for n in 1...6 { try store.add(.text("t\(n)"), sourceApp: nil) }

        let items = try store.items()
        XCTAssertEqual(items.count, 6)
        XCTAssertEqual(items.first?.text, "keep me")
        XCTAssertEqual(items.first?.isPinned, true)
        XCTAssertEqual(items.dropFirst().map(\.text), ["t6", "t5", "t4", "t3", "t2"])
    }

    func testUnpinnedItemBecomesNewestInsteadOfBeingPruned() throws {
        let store = try makeHistoryStore(limit: 5)
        let old = try store.add(.text("old"), sourceApp: nil)
        let id = try XCTUnwrap(old.id)
        try store.togglePin(id: id)
        for n in 1...5 { try store.add(.text("t\(n)"), sourceApp: nil) }

        try store.togglePin(id: id)

        let items = try store.items()
        XCTAssertEqual(items.map(\.text), ["old", "t5", "t4", "t3", "t2"])
        XCTAssertEqual(items.first?.isPinned, false)
    }

    func testMarkUsedMovesItemToTop() throws {
        let store = try makeHistoryStore()
        let a = try store.add(.text("a"), sourceApp: nil)
        try store.add(.text("b"), sourceApp: nil)

        try store.markUsed(id: XCTUnwrap(a.id))

        XCTAssertEqual(try store.items().map(\.text), ["a", "b"])
    }

    func testDeleteRemovesRowAndFiles() throws {
        let store = try makeHistoryStore()
        let image = try store.add(.image(png: TestImages.png(width: 10, height: 10), width: 10, height: 10), sourceApp: nil)

        try store.delete(id: XCTUnwrap(image.id))

        XCTAssertTrue(try store.items().isEmpty)
        XCTAssertFalse(store.images.exists(try XCTUnwrap(image.imagePath)))
    }

    func testClearUnpinnedKeepsPinnedItems() throws {
        let store = try makeHistoryStore()
        let pinned = try store.add(.text("pinned"), sourceApp: nil)
        try store.togglePin(id: XCTUnwrap(pinned.id))
        try store.add(.text("a"), sourceApp: nil)
        try store.add(.image(png: TestImages.png(width: 10, height: 10), width: 10, height: 10), sourceApp: nil)

        try store.clearUnpinned()

        XCTAssertEqual(try store.items().map(\.text), ["pinned"])
        let files = try FileManager.default.contentsOfDirectory(atPath: store.images.directory.path)
        XCTAssertTrue(files.isEmpty)
    }

    func testSetLimitClampsAndPrunesImmediately() throws {
        let store = try makeHistoryStore(limit: 20)
        let pinned = try store.add(.text("pinned"), sourceApp: nil)
        try store.togglePin(id: XCTUnwrap(pinned.id))
        for n in 1...10 { try store.add(.text("t\(n)"), sourceApp: nil) }

        try store.setLimit(2)

        XCTAssertEqual(store.limit, 5)
        let items = try store.items()
        XCTAssertEqual(items.count, 6)
        XCTAssertEqual(items.first?.text, "pinned")

        try store.setLimit(500)
        XCTAssertEqual(store.limit, 100)
    }

    func testMissingImageFileDropsTheRow() throws {
        let store = try makeHistoryStore()
        let image = try store.add(.image(png: TestImages.png(width: 10, height: 10), width: 10, height: 10), sourceApp: nil)
        try store.add(.text("still here"), sourceApp: nil)
        try FileManager.default.removeItem(at: XCTUnwrap(store.imageURL(for: image)))

        XCTAssertEqual(try store.items().map(\.text), ["still here"])
        XCTAssertEqual(try store.items().count, 1)
    }

    func testRemoveOrphanedImagesKeepsReferencedFiles() throws {
        let store = try makeHistoryStore()
        let image = try store.add(.image(png: TestImages.png(width: 10, height: 10), width: 10, height: 10), sourceApp: nil)
        let orphan = store.images.url(for: "orphan.png")
        try Data("x".utf8).write(to: orphan)

        try store.removeOrphanedImages()

        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
        XCTAssertTrue(store.images.exists(try XCTUnwrap(image.imagePath)))
    }

    func testOpenOnDiskPersistsAcrossInstances() throws {
        let dir = try makeTempDirectory()
        let images = try ImageStore(directory: dir.appendingPathComponent("images"))
        do {
            let store = try HistoryStore.openOnDisk(directory: dir, images: images, limit: 20, appName: { _ in nil })
            try store.add(.text("persisted"), sourceApp: nil)
        }
        let reopened = try HistoryStore.openOnDisk(directory: dir, images: images, limit: 20, appName: { _ in nil })
        XCTAssertEqual(try reopened.items().map(\.text), ["persisted"])
    }

    func testOpenOnDiskRecoversFromCorruptDatabase() throws {
        let dir = try makeTempDirectory()
        try Data(repeating: 0x41, count: 4096).write(to: dir.appendingPathComponent("history.sqlite"))
        let images = try ImageStore(directory: dir.appendingPathComponent("images"))

        let store = try HistoryStore.openOnDisk(directory: dir, images: images, limit: 20, appName: { _ in nil })

        XCTAssertTrue(try store.items().isEmpty)
        try store.add(.text("fresh"), sourceApp: nil)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("history.sqlite.corrupt-") }, "names: \(names)")
    }
}
