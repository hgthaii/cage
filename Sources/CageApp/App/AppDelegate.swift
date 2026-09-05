import AppKit
import CageCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private let registry = GameRegistry()
    private let updates = UpdateCoordinator()
    private var cageController: CageController?
    private var menuController: StatusMenuController?
    private var aboutController: AboutWindowController?
    private var relaunchPolicy = AccessibilityRelaunchPolicy()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let cage = CageController(state: state, registry: registry)
        let about = AboutWindowController(
            registry: registry,
            onOpenAccessibility: { [weak cage] in cage?.openAccessibilitySettings() },
            onCheckForUpdates: { [weak updates] in updates?.checkForUpdates() }
        )
        let menu = StatusMenuController(
            state: state,
            onOpenAccessibility: { [weak cage] in cage?.openAccessibilitySettings() },
            onSettings: { [weak about] in about?.present() },
            onCheckForUpdates: { [weak updates] in updates?.checkForUpdates() }
        )
        state.onChange = { [weak menu] in menu?.refresh() }
        cage.onAccessibilityChange = { [weak self, weak about] trusted in
            about?.refreshAccessibility(trusted: trusted)
            guard self?.relaunchPolicy.shouldRelaunch(trusted: trusted) == true else { return }
            Task { @MainActor [weak self] in self?.relaunchAfterGrant() }
        }
        registry.onChange = { [weak cage, weak about] in
            about?.refreshFromRegistry()
            cage?.refresh()
        }
        cageController = cage
        menuController = menu
        aboutController = about
        updates.start()
        cage.start()
        if ProcessInfo.processInfo.arguments.contains("--show-settings") {
            about.present()
        }
    }

    private func relaunchAfterGrant() {
        // Stop capturing before starting the replacement process.
        cageController?.stop()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["--show-settings"]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] _, error in
            Task { @MainActor [weak self] in
                if let error {
                    self?.cageController?.start()
                    let alert = NSAlert()
                    alert.messageText = "Couldn’t reopen Cage"
                    alert.informativeText = "Quit and reopen Cage to refresh access. \(error.localizedDescription)"
                    if let window = self?.aboutController?.window { alert.beginSheetModal(for: window) }
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        cageController?.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        aboutController?.refreshFromRegistry()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        aboutController?.present()
        return true
    }
}
