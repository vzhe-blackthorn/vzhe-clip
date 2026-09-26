import XCTest
@testable import VzheClip

@MainActor
final class HistoryStoreTests: XCTestCase {
    func testNewestItemComesFirst() throws {
        let store = try makeHistoryStore()
        try store.add(.text("first"), sourceApp: nil)
        try store.add(.text("second"), sourceApp: "com.apple.Safari")

        let items = try store.items()
        XCTAssertEqual(items.map(\.text), ["second", "first"])
        XCTAssertEqual(items.first?.sourceApp, "com.apple.Safari")
        XCTAssertNotNil(items.first?.id)
    }

    func testDuplicateMovesToTopWithoutNewRow() throws {
        let store = try makeHistoryStore()
        let original = try store.add(.text("a"), sourceApp: nil)
        try store.add(.text("b"), sourceApp: nil)

        let again = try store.add(.text("a"), sourceApp: nil)

        let items = try store.items()
        XCTAssertEqual(items.map(\.text), ["a", "b"])
        XCTAssertEqual(again.id, original.id)
        XCTAssertGreaterThan(again.lastUsedAt, original.lastUsedAt)
    }

    func testPruneKeepsNewestUnpinnedUpToLimit() throws {
        let store = try makeHistoryStore(limit: 5)
        for n in 1...7 { try store.add(.text("item \(n)"), sourceApp: nil) }

        XCTAssertEqual(try store.items().map(\.text), (3...7).reversed().map { "item \($0)" })
    }

    func testImageAddStoresFilesAndDimensions() throws {
        let store = try makeHistoryStore()
        let item = try store.add(.image(png: TestImages.png(width: 40, height: 20), width: 40, height: 20), sourceApp: nil)

        XCTAssertEqual(item.kind, .image)
        XCTAssertEqual(item.imageWidth, 40)
        XCTAssertEqual(item.imageHeight, 20)
        let imageURL = try XCTUnwrap(store.imageURL(for: item))
        let thumbURL = try XCTUnwrap(store.thumbnailURL(for: item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbURL.path))
    }

    func testDuplicateImageDoesNotWriteNewFiles() throws {
        let store = try makeHistoryStore()
        let png = TestImages.png(width: 10, height: 10)
        let first = try store.add(.image(png: png, width: 10, height: 10), sourceApp: nil)
        let second = try store.add(.image(png: png, width: 10, height: 10), sourceApp: nil)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.imagePath, second.imagePath)
        let files = try FileManager.default.contentsOfDirectory(atPath: store.images.directory.path)
        XCTAssertEqual(files.count, 2)
    }

    func testPrunedImageFilesAreDeleted() throws {
        let store = try makeHistoryStore(limit: 5)
        let image = try store.add(.image(png: TestImages.png(width: 10, height: 10), width: 10, height: 10), sourceApp: nil)
        for n in 1...5 { try store.add(.text("t\(n)"), sourceApp: nil) }

        XCTAssertFalse(try store.items().contains { $0.id == image.id })
        XCTAssertFalse(store.images.exists(try XCTUnwrap(image.imagePath)))
        XCTAssertFalse(store.images.exists(try XCTUnwrap(image.thumbPath)))
    }

    func testSearchIsCaseInsensitiveSubstring() throws {
        let store = try makeHistoryStore()
        try store.add(.text("Hello World"), sourceApp: nil)
        try store.add(.text("goodbye"), sourceApp: nil)

        XCTAssertEqual(try store.items(matching: "WORLD").map(\.text), ["Hello World"])
        XCTAssertEqual(try store.items(matching: "  ").count, 2)
    }

    func testSearchTreatsWildcardCharactersLiterally() throws {
        let store = try makeHistoryStore()
        try store.add(.text("100% done"), sourceApp: nil)
        try store.add(.text("snake_case"), sourceApp: nil)
        try store.add(.text("plain"), sourceApp: nil)

        XCTAssertEqual(try store.items(matching: "%").map(\.text), ["100% done"])
        XCTAssertEqual(try store.items(matching: "_").map(\.text), ["snake_case"])
    }

    func testImagesMatchSourceAppName() throws {
        let store = try makeHistoryStore(appName: { $0 == "com.apple.Preview" ? "Preview" : nil })
        try store.add(.image(png: TestImages.png(width: 10, height: 10), width: 10, height: 10), sourceApp: "com.apple.Preview")
        try store.add(.text("unrelated"), sourceApp: "com.apple.Preview")

        let found = try store.items(matching: "preview")
        XCTAssertEqual(found.map(\.kind), [.image])
    }

    func testOnChangeFiresAfterAdd() throws {
        let store = try makeHistoryStore()
        var calls = 0
        store.onChange = { calls += 1 }
        try store.add(.text("x"), sourceApp: nil)
        XCTAssertEqual(calls, 1)
    }
}
