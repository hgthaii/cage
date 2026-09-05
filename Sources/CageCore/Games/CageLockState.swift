import CoreGraphics

public enum CageLockState: Equatable, Sendable {
    case permissionRequired
    case waiting
    case locked(game: GameIdentity, bounds: CGRect)

    public var isLocked: Bool {
        if case .locked = self { return true }
        return false
    }
}

public enum CageStateResolver {
    public static func resolve(
        hasPermission: Bool,
        game: GameIdentity?,
        windowBounds: CGRect?
    ) -> CageLockState {
        guard hasPermission else { return .permissionRequired }
        guard let game,
              let windowBounds,
              let confinementBounds = CursorGeometry.confinementBounds(for: windowBounds) else {
            return .waiting
        }
        return .locked(game: game, bounds: confinementBounds)
    }
}
