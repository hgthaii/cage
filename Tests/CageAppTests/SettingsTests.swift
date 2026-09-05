import AppKit
import CageCore
import XCTest
@testable import CageApp

@MainActor
final class SettingsTests: XCTestCase {
    func testEscapeAndCommandWCloseSettingsWithoutQuitting() async throws {
        _ = NSApplication.shared
        let window = RecordingSettingsWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        for (key, code, flags) in [("\u{1b}", UInt16(53), NSEvent.ModifierFlags()), ("w", UInt16(13), .command)] {
            let event = try XCTUnwrap(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: key,
                charactersIgnoringModifiers: key, isARepeat: false, keyCode: code
            ))
            XCTAssertTrue(window.performKeyEquivalent(with: event))
        }
        XCTAssertEqual(window.closeRequests, 2)
        window.cancelOperation(nil)
        XCTAssertEqual(window.closeRequests, 3)
    }
    func testPermissionGrantAndRevocationUpdateControlsAndBanner() async throws {
        try await MainActor.run {
            let controller = makeSettings()
            controller.refreshAccessibility(trusted: false)
            let root = try XCTUnwrap(controller.window?.contentView)
            let add = try button("Add App…", in: root)
            let grant = try button("Grant Access…", in: root)
            let startup = try XCTUnwrap(descendants(root).compactMap { $0 as? NSSwitch }.first)
            XCTAssertFalse(add.isEnabled)
            XCTAssertFalse(startup.isEnabled)
            XCTAssertTrue(grant.isEnabled)
            XCTAssertFalse(grant.isHiddenOrHasHiddenAncestor)

            controller.refreshAccessibility(trusted: true)
            XCTAssertTrue(add.isEnabled)
            if #available(macOS 13.0, *) { XCTAssertTrue(startup.isEnabled) }
            XCTAssertTrue(grant.isHiddenOrHasHiddenAncestor)

            controller.refreshAccessibility(trusted: false)
            XCTAssertFalse(add.isEnabled)
            XCTAssertFalse(startup.isEnabled)
            XCTAssertFalse(grant.isHiddenOrHasHiddenAncestor)
        }
    }

    func testAppListKeepsFixedHeightAndScrollsWithManyItems() async throws {
        try await MainActor.run {
            let controller = makeSettings(appCount: 10)
            controller.refreshAccessibility(trusted: true)
            let root = try XCTUnwrap(controller.window?.contentView)
            root.layoutSubtreeIfNeeded()
            let scroll = try XCTUnwrap(descendants(root).compactMap { $0 as? NSScrollView }.first)
            let document = try XCTUnwrap(scroll.documentView)
            XCTAssertTrue(scroll.hasVerticalScroller)
            XCTAssertEqual(scroll.superview?.frame.height, 190)
            XCTAssertGreaterThan(document.frame.height, scroll.contentView.bounds.height)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: document.frame.height - scroll.contentView.bounds.height))
            scroll.reflectScrolledClipView(scroll.contentView)
            XCTAssertGreaterThan(scroll.contentView.bounds.minY, 0)
            XCTAssertEqual(scroll.contentView.bounds.maxY, document.frame.maxY, accuracy: 1)
            XCTAssertEqual(descendants(document).compactMap { $0 as? NSImageView }.count, 10)
            let removeButtons = descendants(document).compactMap { $0 as? NSButton }
            XCTAssertTrue(removeButtons.allSatisfy(\.isEnabled))
            controller.refreshAccessibility(trusted: false)
            XCTAssertTrue(removeButtons.allSatisfy { !$0.isEnabled })
        }
    }

    func testAboutActionsAndTabSelection() async throws {
        try await MainActor.run {
            let controller = makeSettings()
            let root = try XCTUnwrap(controller.window?.contentView)
            let tabs = try XCTUnwrap(descendants(root).compactMap { $0 as? SettingsTabBar }.first)
            try button("About", in: tabs).performClick(nil)
            XCTAssertEqual(tabs.selectedIndex, 1)
            let labels = descendants(root).compactMap { $0 as? NSTextField }
                .filter { !$0.isHiddenOrHasHiddenAncestor }.map(\.stringValue)
            XCTAssertTrue(labels.contains("Developed by hgthaii"))
            XCTAssertTrue(labels.contains("Based on MouseLock by mxrlkn"))
            let update = try button("Check for Updates…", in: root)
            let report = try button("Report a Bug…", in: root)
            XCTAssertFalse(update.isHiddenOrHasHiddenAncestor)
            controller.refreshAccessibility(trusted: false)
            XCTAssertFalse(update.isEnabled)
            XCTAssertFalse(report.isEnabled)
            controller.refreshAccessibility(trusted: true)
            XCTAssertTrue(update.isEnabled)
            XCTAssertTrue(report.isEnabled)
            try button("General", in: tabs).performClick(nil)
            XCTAssertEqual(tabs.selectedIndex, 0)
            XCTAssertTrue(update.isHiddenOrHasHiddenAncestor)
        }
    }

    @MainActor
    private func makeSettings(appCount: Int = 0) -> AboutWindowController {
        _ = NSApplication.shared
        let suite = "Cage.SettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let apps = (0..<appCount).map {
            GameIdentity(bundleIdentifier: "test.app.\($0)", displayName: "Test App \($0)")
        }
        // Registered defaults stay in memory; no user allow list or preferences are written.
        defaults.register(defaults: ["cage.games": try! JSONEncoder().encode(apps)])
        return AboutWindowController(
            registry: GameRegistry(defaults: defaults),
            onOpenAccessibility: {},
            onCheckForUpdates: {}
        )
    }

    @MainActor
    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }

    @MainActor
    private func button(_ title: String, in view: NSView) throws -> NSButton {
        try XCTUnwrap(descendants(view).compactMap { $0 as? NSButton }.first { $0.title == title })
    }
}

@MainActor
private final class RecordingSettingsWindow: SettingsWindow {
    var closeRequests = 0
    override func performClose(_ sender: Any?) { closeRequests += 1 }
}
