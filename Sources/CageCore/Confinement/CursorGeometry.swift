import CoreGraphics

public enum CursorGeometry {
    public static let defaultSafetyInset: CGFloat = 4
    public static let farEdgePixelInset: CGFloat = 1

    public static func confinementBounds(
        for windowBounds: CGRect,
        inset: CGFloat = defaultSafetyInset
    ) -> CGRect? {
        guard windowBounds.width > inset * 2, windowBounds.height > inset * 2 else {
            return nil
        }
        return windowBounds.insetBy(dx: inset, dy: inset)
    }

    public static func windowPixelBounds(for windowBounds: CGRect) -> CGRect? {
        guard windowBounds.width > farEdgePixelInset,
              windowBounds.height > farEdgePixelInset else { return nil }
        return CGRect(
            x: windowBounds.minX,
            y: windowBounds.minY,
            width: windowBounds.width - farEdgePixelInset,
            height: windowBounds.height - farEdgePixelInset
        )
    }

    public static func visibleWindowBounds(
        _ windowBounds: CGRect,
        on displays: [CGRect]
    ) -> CGRect? {
        displays
            .map { windowBounds.intersection($0) }
            .filter { !$0.isNull && !$0.isEmpty }
            .max { first, second in first.width * first.height < second.width * second.height }
    }

    public static func clamped(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    /// Removes only the part of a mouse delta that would keep moving beyond an edge.
    /// Games that track a virtual cursor from deltas then stay in sync with the
    /// absolute macOS cursor that Cage confines.
    public static func confinedDelta(
        _ delta: CGPoint,
        at location: CGPoint,
        within bounds: CGRect
    ) -> CGPoint {
        let x = (location.x <= bounds.minX && delta.x < 0)
            || (location.x >= bounds.maxX && delta.x > 0) ? 0 : delta.x
        let y = (location.y <= bounds.minY && delta.y < 0)
            || (location.y >= bounds.maxY && delta.y > 0) ? 0 : delta.y
        return CGPoint(x: x, y: y)
    }
}
