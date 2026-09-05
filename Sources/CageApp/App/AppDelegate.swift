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
        cage.onAccessibilityChange = { [weak about] trusted in
            about?.refreshAccessibility(trusted: trusted)
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
