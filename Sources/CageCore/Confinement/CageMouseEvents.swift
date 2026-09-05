import CoreGraphics

public enum CageMouseEvents {
    public static let confinedTypes: [CGEventType] = [
        .mouseMoved,
        .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        .rightMouseDown, .rightMouseUp, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged,
        .scrollWheel,
    ]

    public static let mask = confinedTypes.reduce(CGEventMask(0)) { mask, type in
        mask | (CGEventMask(1) << type.rawValue)
    }

    public static func contains(_ type: CGEventType) -> Bool {
        mask & (CGEventMask(1) << type.rawValue) != 0
    }
}
