import Foundation

public struct GameIdentity: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let bundleIdentifier: String
    public var displayName: String
    public var applicationPath: String?

    public var id: String { bundleIdentifier }

    public init(
        bundleIdentifier: String,
        displayName: String,
        applicationPath: String? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.applicationPath = applicationPath
    }
}
