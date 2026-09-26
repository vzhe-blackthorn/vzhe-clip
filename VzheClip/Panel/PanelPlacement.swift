import CoreGraphics

struct ScreenGeometry: Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
}

/// All coordinates are AppKit screen coordinates (origin bottom-left, y grows upward).
enum PanelPlacement {
    static let cursorOffset: CGFloat = 8

    static func screen(containing point: CGPoint, in screens: [ScreenGeometry]) -> ScreenGeometry? {
        screens.first { $0.frame.contains(point) } ?? screens.first
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
