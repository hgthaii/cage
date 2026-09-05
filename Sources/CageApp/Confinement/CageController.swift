import AppKit
import ApplicationServices
import CageCore

@MainActor
final class CageController {
    var onAccessibilityChange: ((Bool) -> Void)?
    private var lastAccessibilityTrust: Bool?
    private let state: AppState
    private let registry: GameRegistry
    private let engine = CursorConfinementEngine()
    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?
    private var eventTapInstalled = false
    private var requestedPermission = false

    init(state: AppState, registry: GameRegistry) {
        self.state = state
        self.registry = registry
    }

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ].map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func stop() {
        refreshTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers.removeAll()
        engine.uninstall()
        eventTapInstalled = false
    }

    func refresh() {
        let trusted = AXIsProcessTrusted()
        if lastAccessibilityTrust != trusted {
            lastAccessibilityTrust = trusted
            onAccessibilityChange?(trusted)
        }
        if trusted, !eventTapInstalled { eventTapInstalled = engine.install() }
        let permissionReady = trusted && eventTapInstalled
        let application = NSWorkspace.shared.frontmostApplication
        let game = registry.application(matching: application)
        let bounds = game.flatMap { _ in
            application.map { GameWindowLocator.windowBounds(processIdentifier: $0.processIdentifier) } ?? nil
        }
        let resolved = CageStateResolver.resolve(
            hasPermission: permissionReady,
            game: game,
            windowBounds: bounds
        )
        if case let .locked(_, bounds) = resolved { engine.update(bounds: bounds) }
        else { engine.update(bounds: nil) }
        state.update(resolved)

        if !trusted, !requestedPermission {
            requestedPermission = true
            requestAccessibilityPermission()
        }
    }

    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
