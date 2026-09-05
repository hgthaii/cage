import AppKit
import CageCore

@MainActor
final class GameRegistry {
    private enum Keys {
        static let games = "cage.games"
    }

    private let defaults: UserDefaults
    private(set) var games: [GameIdentity]
    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.games),
           let decoded = try? JSONDecoder().decode([GameIdentity].self, from: data) {
            games = decoded.map(Self.resolveStoredIdentity)
        } else {
            games = []
        }
    }

    func application(matching runningApplication: NSRunningApplication?) -> GameIdentity? {
        guard let runningApplication else { return nil }
        if let bundleIdentifier = runningApplication.bundleIdentifier,
           let exactMatch = games.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return exactMatch
        }
        guard let candidatePath = runningApplication.bundleURL?.path else { return nil }
        return games.first { allowedApplication in
            guard let allowedPath = allowedApplication.applicationPath else { return false }
            return ApplicationPathMatcher.matches(
                candidatePath: candidatePath,
                allowedPath: allowedPath
            )
        }
    }

    func add(_ game: GameIdentity) {
        games.removeAll { $0.bundleIdentifier == game.bundleIdentifier }
        games.append(game)
        games.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        save()
    }

    func remove(bundleIdentifier: String) {
        games.removeAll { $0.bundleIdentifier == bundleIdentifier }
        save()
    }

    func identity(for applicationURL: URL) -> GameIdentity? {
        let targetURL = Self.preferredTarget(in: applicationURL)
        guard let bundle = Bundle(url: targetURL),
              let bundleIdentifier = bundle.bundleIdentifier else { return nil }
        let rootBundle = Bundle(url: applicationURL)
        let displayName = (rootBundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (rootBundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? applicationURL.deletingPathExtension().lastPathComponent
        return GameIdentity(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationPath: targetURL.path
        )
    }

    private static func resolveStoredIdentity(_ identity: GameIdentity) -> GameIdentity {
        guard let storedPath = identity.applicationPath else { return identity }
        let rootURL = URL(fileURLWithPath: storedPath)
        guard let resolved = identityForMigration(rootURL: rootURL, displayName: identity.displayName) else {
            return identity
        }
        return resolved
    }

    private static func identityForMigration(rootURL: URL, displayName: String) -> GameIdentity? {
        let targetURL = preferredTarget(in: rootURL)
        guard let bundleIdentifier = Bundle(url: targetURL)?.bundleIdentifier else { return nil }
        return GameIdentity(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationPath: targetURL.path
        )
    }

    private static func preferredTarget(in rootURL: URL) -> URL {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return rootURL }

        var candidates: [String] = []
        while let url = enumerator.nextObject() as? URL {
            let components = url.pathComponents
            if components.contains(where: { ["Frameworks", "Helpers", "Library", "PlugIns", "XPCServices"].contains($0) }) {
                enumerator.skipDescendants()
                continue
            }
            if url.pathExtension.lowercased() == "app" {
                candidates.append(url.path)
                enumerator.skipDescendants()
            }
        }
        let path = ApplicationTargetResolver.preferredPath(
            rootPath: rootURL.path,
            candidatePaths: candidates
        )
        return URL(fileURLWithPath: path)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(games) {
            defaults.set(data, forKey: Keys.games)
        }
        onChange?()
    }
}
