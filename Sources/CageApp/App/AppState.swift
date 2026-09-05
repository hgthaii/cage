import CageCore
import Foundation

@MainActor
final class AppState {
    private(set) var lockState: CageLockState = .waiting
    var onChange: (() -> Void)?

    func update(_ newState: CageLockState) {
        guard newState != lockState else { return }
        lockState = newState
        onChange?()
    }
}
