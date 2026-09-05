import CoreGraphics

public enum CursorGeometry {
    public static let defaultSafetyInset: CGFloat = 4

    public static func confinementBounds(
        for windowBounds: CGRect,
        inset: CGFloat = defaultSafetyInset
    ) -> CGRect? {
        guard windowBounds.width > inset * 2, windowBounds.height > inset * 2 else {
            return nil
        }
        return windowBounds.insetBy(dx: inset, dy: inset)
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
}
