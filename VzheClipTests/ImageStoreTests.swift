import XCTest
@testable import VzheClip

@MainActor
final class ImageStoreTests: XCTestCase {
    func testSaveWritesOriginalAndThumbnail() throws {
        let store = try ImageStore(directory: makeTempDirectory())
        let png = TestImages.png(width: 1000, height: 500)

        let stored = try store.save(png: png)

        XCTAssertTrue(store.exists(stored.imagePath))
        XCTAssertTrue(store.exists(stored.thumbPath))
        XCTAssertEqual(try Data(contentsOf: store.url(for: stored.imagePath)), png)
        let thumbSize = try XCTUnwrap(ImageCoding.pixelSize(of: Data(contentsOf: store.url(for: stored.thumbPath))))
        XCTAssertEqual(thumbSize.width, 480)
        XCTAssertEqual(thumbSize.height, 240)
    }

    func testThumbnailLimitsLongestSideForTallImages() throws {
        let store = try ImageStore(directory: makeTempDirectory())
        let stored = try store.save(png: TestImages.png(width: 300, height: 1200))
        let size = try XCTUnwrap(ImageCoding.pixelSize(of: Data(contentsOf: store.url(for: stored.thumbPath))))
        XCTAssertEqual(size.height, 480)
        XCTAssertEqual(size.width, 120)
    }

    func testSmallImagesAreNotUpscaled() throws {
        let store = try ImageStore(directory: makeTempDirectory())
        let stored = try store.save(png: TestImages.png(width: 100, height: 50))
        let size = try XCTUnwrap(ImageCoding.pixelSize(of: Data(contentsOf: store.url(for: stored.thumbPath))))
        XCTAssertEqual(size.width, 100)
        XCTAssertEqual(size.height, 50)
    }

    func testSaveRejectsNonImageData() throws {
        let store = try ImageStore(directory: makeTempDirectory())
        XCTAssertThrowsError(try store.save(png: Data("not an image".utf8)))
    }

    func testDeleteRemovesFiles() throws {
        let store = try ImageStore(directory: makeTempDirectory())
        let stored = try store.save(png: TestImages.png(width: 10, height: 10))
        store.delete([stored.imagePath, stored.thumbPath])
        XCTAssertFalse(store.exists(stored.imagePath))
        XCTAssertFalse(store.exists(stored.thumbPath))
    }

    func testRemoveOrphansKeepsReferencedFiles() throws {
        let store = try ImageStore(directory: makeTempDirectory())
        let kept = try store.save(png: TestImages.png(width: 10, height: 10, red: 0.1))
        let orphan = try store.save(png: TestImages.png(width: 10, height: 10, red: 0.9))

        store.removeOrphans(keeping: [kept.imagePath, kept.thumbPath])

        XCTAssertTrue(store.exists(kept.imagePath))
        XCTAssertTrue(store.exists(kept.thumbPath))
        XCTAssertFalse(store.exists(orphan.imagePath))
        XCTAssertFalse(store.exists(orphan.thumbPath))
    }
}
