import Foundation

enum ItemKind: String, Sendable {
    case text
    case image
}

/// A clipboard entry as read from the pasteboard, before it is stored.
enum CapturedItem: Equatable, Sendable {
    case text(String)
    case image(png: Data, width: Int, height: Int)
}

/// A stored history entry.
struct ClipItem: Equatable, Identifiable, Sendable {
    var id: Int64?
    var kind: ItemKind
    var text: String?
    var imagePath: String?
    var thumbPath: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var contentHash: String
    var sourceApp: String?
    var isPinned: Bool
    var createdAt: Date
    var lastUsedAt: Date

    /// Image files owned by this item, relative to the ImageStore directory.
    var filePaths: [String] { [imagePath, thumbPath].compactMap { $0 } }
}
