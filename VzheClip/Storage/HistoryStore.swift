import CryptoKit
import Foundation
import GRDB
import os

extension ClipItem: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "items"

    init(row: Row) throws {
        let kindRaw: String = row["kind"]
        let created: Double = row["created_at"]
        let lastUsed: Double = row["last_used_at"]
        id = row["id"]
        kind = ItemKind(rawValue: kindRaw) ?? .text
        text = row["text"]
        imagePath = row["image_path"]
        thumbPath = row["thumb_path"]
        imageWidth = row["image_w"]
        imageHeight = row["image_h"]
        contentHash = row["content_hash"]
        sourceApp = row["source_app"]
        isPinned = row["is_pinned"]
        createdAt = Date(timeIntervalSince1970: created)
        lastUsedAt = Date(timeIntervalSince1970: lastUsed)
    }

    func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["kind"] = kind.rawValue
        container["text"] = text
        container["image_path"] = imagePath
        container["thumb_path"] = thumbPath
        container["image_w"] = imageWidth
        container["image_h"] = imageHeight
        container["content_hash"] = contentHash
        container["source_app"] = sourceApp
        container["is_pinned"] = isPinned
        container["created_at"] = createdAt.timeIntervalSince1970
        container["last_used_at"] = lastUsedAt.timeIntervalSince1970
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// The only component that touches the database. All mutations call `onChange`.
@MainActor
final class HistoryStore {
    static let defaultLimit = 20
    static let limitRange = 5...100

    static func clampLimit(_ value: Int) -> Int {
        min(max(value, limitRange.lowerBound), limitRange.upperBound)
    }

    private static let logger = Logger(subsystem: "com.vzh.VzheClip", category: "HistoryStore")

    let images: ImageStore
    private(set) var limit: Int
    var onChange: (() -> Void)?

    private let dbQueue: DatabaseQueue
    private let now: () -> Date
    private let appName: @MainActor (String) -> String?

    init(
        dbQueue: DatabaseQueue,
        images: ImageStore,
        limit: Int = HistoryStore.defaultLimit,
        now: @escaping () -> Date = Date.init,
        appName: @escaping @MainActor (String) -> String? = { _ in nil }
    ) throws {
        self.dbQueue = dbQueue
        self.images = images
        self.limit = Self.clampLimit(limit)
        self.now = now
        self.appName = appName
        try Self.migrator.migrate(dbQueue)
    }

    static func inMemory(
        images: ImageStore,
        limit: Int = HistoryStore.defaultLimit,
        now: @escaping () -> Date = Date.init,
        appName: @escaping @MainActor (String) -> String? = { _ in nil }
    ) throws -> HistoryStore {
        try HistoryStore(dbQueue: DatabaseQueue(), images: images, limit: limit, now: now, appName: appName)
    }

    private nonisolated static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE items (
                  id            INTEGER PRIMARY KEY AUTOINCREMENT,
                  kind          TEXT    NOT NULL CHECK (kind IN ('text','image')),
                  text          TEXT,
                  image_path    TEXT,
                  thumb_path    TEXT,
                  image_w       INTEGER,
                  image_h       INTEGER,
                  content_hash  TEXT    NOT NULL UNIQUE,
                  source_app    TEXT,
                  is_pinned     INTEGER NOT NULL DEFAULT 0,
                  created_at    REAL    NOT NULL,
                  last_used_at  REAL    NOT NULL
                );
                CREATE INDEX items_order ON items (is_pinned DESC, last_used_at DESC);
                """)
        }
        return migrator
    }

    // MARK: - Adding

    @discardableResult
    func add(_ captured: CapturedItem, sourceApp: String?) throws -> ClipItem {
        let hash = Self.hash(of: captured)
        let timestamp = now()

        if var existing = try dbQueue.read({ db in
            try ClipItem.fetchOne(db, sql: "SELECT * FROM items WHERE content_hash = ?", arguments: [hash])
        }) {
            existing.lastUsedAt = timestamp
            let updated = existing
            try dbQueue.write { db in try updated.update(db) }
            onChange?()
            return updated
        }

        var item = ClipItem(
            id: nil, kind: .text, text: nil, imagePath: nil, thumbPath: nil,
            imageWidth: nil, imageHeight: nil, contentHash: hash, sourceApp: sourceApp,
            isPinned: false, createdAt: timestamp, lastUsedAt: timestamp
        )
        var stored: StoredImage?
        switch captured {
        case .text(let string):
            item.text = string
        case .image(let png, let width, let height):
            let saved = try images.save(png: png)
            stored = saved
            item.kind = .image
            item.imagePath = saved.imagePath
            item.thumbPath = saved.thumbPath
            item.imageWidth = width
            item.imageHeight = height
        }

        let toInsert = item
        do {
            item = try dbQueue.write { db in
                var copy = toInsert
                try copy.insert(db)
                return copy
            }
        } catch {
            if let stored { images.delete([stored.imagePath, stored.thumbPath]) }
            throw error
        }

        try prune()
        onChange?()
        return item
    }

    private static func hash(of captured: CapturedItem) -> String {
        let data: Data
        switch captured {
        case .text(let string): data = Data("text:".utf8) + Data(string.utf8)
        case .image(let png, _, _): data = Data("image:".utf8) + png
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Reading

    /// Pinned first, then most recently used. Rows whose image file vanished are dropped.
    func items(matching query: String = "") throws -> [ClipItem] {
        let all = try dbQueue.read { db in
            try ClipItem.fetchAll(db, sql: "SELECT * FROM items ORDER BY is_pinned DESC, last_used_at DESC")
        }

        var present: [ClipItem] = []
        var missing: [ClipItem] = []
        for item in all {
            if item.kind == .image, !(item.imagePath.map(images.exists) ?? false) {
                missing.append(item)
            } else {
                present.append(item)
            }
        }
        if !missing.isEmpty {
            let ids = missing.compactMap(\.id)
            try dbQueue.write { db in
                for id in ids { try db.execute(sql: "DELETE FROM items WHERE id = ?", arguments: [id]) }
            }
            images.delete(missing.flatMap(\.filePaths))
            Self.logger.info("Dropped \(ids.count) items with missing image files")
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return present }
        return present.filter { matches($0, trimmed) }
    }

    private func matches(_ item: ClipItem, _ query: String) -> Bool {
        switch item.kind {
        case .text:
            return item.text?.localizedCaseInsensitiveContains(query) ?? false
        case .image:
            guard let bundleID = item.sourceApp, let name = appName(bundleID) else { return false }
            return name.localizedCaseInsensitiveContains(query)
        }
    }

    func imageURL(for item: ClipItem) -> URL? {
        item.imagePath.map(images.url(for:))
    }

    func thumbnailURL(for item: ClipItem) -> URL? {
        item.thumbPath.map(images.url(for:))
    }

    // MARK: - Pruning

    /// Deletes unpinned items beyond `limit` (oldest first) together with their files.
    private func prune() throws {
        let limit = self.limit
        let doomed = try dbQueue.write { db -> [ClipItem] in
            let selection = "SELECT * FROM items WHERE is_pinned = 0 ORDER BY last_used_at DESC LIMIT -1 OFFSET ?"
            let rows = try ClipItem.fetchAll(db, sql: selection, arguments: [limit])
            for row in rows {
                if let id = row.id { try db.execute(sql: "DELETE FROM items WHERE id = ?", arguments: [id]) }
            }
            return rows
        }
        images.delete(doomed.flatMap(\.filePaths))
    }
}
