/// Relaunch only after access changes from denied to granted, never at a trusted startup.
public struct AccessibilityRelaunchPolicy {
    private var previousTrust: Bool?
    private var requestedRelaunch = false

    public init() {}

    public mutating func shouldRelaunch(trusted: Bool) -> Bool {
        defer { previousTrust = trusted }
        guard previousTrust == false, trusted, !requestedRelaunch else { return false }
        requestedRelaunch = true
        return true
    }
}
