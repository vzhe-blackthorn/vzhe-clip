import AppKit
import XCTest
@testable import VzheClip

func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("VzheClipTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

enum TestImages {
    /// Solid-colour RGBA image; vary `red` to get different bytes (different hash).
    static func cgImage(width: Int, height: Int, red: CGFloat = 0.5) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: red, green: 0.2, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    static func png(width: Int, height: Int, red: CGFloat = 0.5) -> Data {
        ImageCoding.pngData(from: cgImage(width: width, height: height, red: red))!
    }
}

/// Deterministic clock: every call is one second later than the previous one.
final class TestClock {
    private(set) var current = Date(timeIntervalSince1970: 1_700_000_000)

    func now() -> Date {
        current = current.addingTimeInterval(1)
        return current
    }
}

@MainActor
func makeHistoryStore(
    limit: Int = HistoryStore.defaultLimit,
    clock: TestClock = TestClock(),
    appName: @escaping @MainActor (String) -> String? = { _ in nil }
) throws -> HistoryStore {
    let images = try ImageStore(directory: makeTempDirectory())
    return try HistoryStore.inMemory(images: images, limit: limit, now: clock.now, appName: appName)
}
