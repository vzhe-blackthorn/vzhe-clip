import Foundation

struct StoredImage: Equatable, Sendable {
    let imagePath: String
    let thumbPath: String
}

enum ImageStoreError: Error {
    case thumbnailFailed
}

/// Owns the image files next to the database. Paths handed out are relative to `directory`.
final class ImageStore: Sendable {
    static let thumbnailMaxPixelSize = 480

    let directory: URL

    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(png: Data) throws -> StoredImage {
        guard let thumb = ImageCoding.thumbnail(of: png, maxPixelSize: Self.thumbnailMaxPixelSize),
              let thumbData = ImageCoding.pngData(from: thumb)
        else { throw ImageStoreError.thumbnailFailed }

        let base = UUID().uuidString
        let stored = StoredImage(imagePath: "\(base).png", thumbPath: "\(base)_thumb.png")
        try png.write(to: url(for: stored.imagePath), options: .atomic)
        do {
            try thumbData.write(to: url(for: stored.thumbPath), options: .atomic)
        } catch {
            delete([stored.imagePath])
            throw error
        }
        return stored
    }

    func url(for relativePath: String) -> URL {
        directory.appendingPathComponent(relativePath)
    }

    func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: relativePath).path)
    }

    func delete(_ relativePaths: [String]) {
        for path in relativePaths {
            try? FileManager.default.removeItem(at: url(for: path))
        }
    }

    func removeOrphans(keeping referenced: Set<String>) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        delete(names.filter { !referenced.contains($0) })
    }
}
