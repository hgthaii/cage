import Foundation

public enum ApplicationTargetResolver {
    private static let ignoredContainers: Set<String> = [
        "Frameworks", "Helpers", "Library", "PlugIns", "XPCServices",
    ]

    public static func preferredPath(rootPath: String, candidatePaths: [String]) -> String {
        let root = URL(fileURLWithPath: rootPath).standardizedFileURL
        return candidatePaths
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
            .filter { candidate in
                let relativeComponents = Array(candidate.pathComponents.dropFirst(root.pathComponents.count))
                return !relativeComponents.contains { ignoredContainers.contains($0) }
            }
            .max { first, second in
                first.pathComponents.count < second.pathComponents.count
            }?
            .path ?? root.path
    }
}
