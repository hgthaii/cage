public enum StatusMenuAction: Equatable, Sendable {
    case grantAccessibility
    case settings
    case checkForUpdates
    case quit
}

public struct StatusMenuItemModel: Equatable, Sendable {
    public let title: String
    public let action: StatusMenuAction

    public init(title: String, action: StatusMenuAction) {
        self.title = title
        self.action = action
    }
}

public enum StatusIconKind: Equatable, Sendable {
    case idle
    case locked
}

public enum StatusMenuModel {
    public static let items = [
        StatusMenuItemModel(title: "Check for Updates…", action: .checkForUpdates),
        StatusMenuItemModel(title: "Settings…", action: .settings),
        StatusMenuItemModel(title: "Quit Cage", action: .quit),
    ]

    public static func items(hasAccessibilityAccess: Bool) -> [StatusMenuItemModel] {
        guard !hasAccessibilityAccess else { return items }
        return [StatusMenuItemModel(title: "Grant Accessibility Access…", action: .grantAccessibility)] + items
    }

    public static func iconKind(for state: CageLockState) -> StatusIconKind {
        state.isLocked ? .locked : .idle
    }
}
