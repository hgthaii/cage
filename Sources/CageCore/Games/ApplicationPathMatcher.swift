import Foundation

public enum ApplicationPathMatcher {
    public static func matches(candidatePath: String, allowedPath: String) -> Bool {
        let candidate = URL(fileURLWithPath: candidatePath).standardizedFileURL.path
        let allowed = URL(fileURLWithPath: allowedPath).standardizedFileURL.path
        return candidate == allowed || candidate.hasPrefix(allowed + "/")
    }
}
