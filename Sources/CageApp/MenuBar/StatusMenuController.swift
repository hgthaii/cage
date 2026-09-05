import AppKit
import ApplicationServices
import CageCore

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let state: AppState
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let onOpenAccessibility: () -> Void
    private let onSettings: () -> Void
    private let onCheckForUpdates: () -> Void

    init(
        state: AppState,
        onOpenAccessibility: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void
    ) {
        self.state = state
        self.onOpenAccessibility = onOpenAccessibility
        self.onSettings = onSettings
        self.onCheckForUpdates = onCheckForUpdates
        super.init()
        configureMenu()
        refresh()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        configureMenu()
        refresh()
    }

    func refresh() {
        let locked = state.lockState.isLocked
        let resourceName = locked ? "StatusIconLocked" : "StatusIconIdle"
        let image = Bundle.main.url(forResource: resourceName, withExtension: "svg")
            .flatMap(NSImage.init(contentsOf:))
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = tooltip
        statusItem.button?.setAccessibilityLabel(tooltip)
    }

    private var tooltip: String {
        if case let .locked(game, _) = state.lockState {
            return "Cage — Locked to \(game.displayName)"
        }
        return AppIdentity.productName
    }

    private func configureMenu() {
        menu.delegate = self
        menu.removeAllItems()
        for model in StatusMenuModel.items(hasAccessibilityAccess: AXIsProcessTrusted()) {
            let selector: Selector
            let key: String
            switch model.action {
            case .grantAccessibility: selector = #selector(openAccessibility); key = ""
            case .checkForUpdates: selector = #selector(checkForUpdates); key = ""
            case .settings: selector = #selector(showSettings); key = ","
            case .quit:
                menu.addItem(.separator())
                selector = #selector(quit); key = "q"
            }
            let item = NSMenuItem(title: model.title, action: selector, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        statusItem.menu = menu
    }

    @objc private func openAccessibility() { onOpenAccessibility() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func showSettings() { onSettings() }
    @objc private func checkForUpdates() { onCheckForUpdates() }
}
