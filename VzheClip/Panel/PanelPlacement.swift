import CoreGraphics

struct ScreenGeometry: Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
}

/// All coordinates are AppKit screen coordinates (origin bottom-left, y grows upward).
enum PanelPlacement {
    static let cursorOffset: CGFloat = 8

    static func screen(containing point: CGPoint, in screens: [ScreenGeometry]) -> ScreenGeometry? {
        screens.first { contains($0.frame, point) } ?? screens.first
    }

    /// Inclusive containment: `CGRect.contains` excludes `maxX`/`maxY`, but
    /// `NSEvent.mouseLocation` reports `y == frame.maxY` on a screen's top row.
    private static func contains(_ frame: CGRect, _ point: CGPoint) -> Bool {
        (frame.minX...frame.maxX).contains(point.x) && (frame.minY...frame.maxY).contains(point.y)
    }

    /// Top-left corner goes just below-right of the cursor, then the panel is clamped
    /// inside `visibleFrame`. If it doesn't fit, the left and top edges win.
    static func origin(cursor: CGPoint, panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        var x = cursor.x + cursorOffset
        var y = cursor.y - cursorOffset - panelSize.height
        x = max(visibleFrame.minX, min(x, visibleFrame.maxX - panelSize.width))
        y = min(visibleFrame.maxY - panelSize.height, max(y, visibleFrame.minY))
        return CGPoint(x: x, y: y)
    }
}
