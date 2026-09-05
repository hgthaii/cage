import Sparkle

@MainActor
final class UpdateCoordinator {
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func start() {
        _ = controller
    }

    func checkForUpdates() {
        start()
        controller.checkForUpdates(nil)
    }
}
