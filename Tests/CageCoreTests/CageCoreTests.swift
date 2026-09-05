import CoreGraphics
import XCTest
@testable import CageCore

final class CageCoreTests: XCTestCase {
    func testRelaunchOnlyOnceAfterPermissionGrant() {
        var policy = AccessibilityRelaunchPolicy()
        XCTAssertFalse(policy.shouldRelaunch(trusted: false))
        XCTAssertFalse(policy.shouldRelaunch(trusted: false))
        XCTAssertTrue(policy.shouldRelaunch(trusted: true))
        XCTAssertFalse(policy.shouldRelaunch(trusted: true))
        XCTAssertFalse(policy.shouldRelaunch(trusted: false))
        XCTAssertFalse(policy.shouldRelaunch(trusted: true))
        var startup = AccessibilityRelaunchPolicy()
        XCTAssertFalse(startup.shouldRelaunch(trusted: true))
    }
    func testConfinementBoundsInsetEveryEdge() {
        let window = CGRect(x: 100, y: 200, width: 800, height: 600)
        XCTAssertEqual(
            CursorGeometry.confinementBounds(for: window),
            CGRect(x: 104, y: 204, width: 792, height: 592)
        )
    }

    func testWindowBoundsAreClippedToPhysicalDisplay() {
        let window = CGRect(x: -3, y: 0, width: 1926, height: 1084)
        let display = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        XCTAssertEqual(CursorGeometry.visibleWindowBounds(window, on: [display]), display)
    }

    func testLargestDisplayIntersectionWins() {
        let window = CGRect(x: 1500, y: 100, width: 1000, height: 800)
        let displays = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 1920, height: 1080),
        ]
        XCTAssertEqual(
            CursorGeometry.visibleWindowBounds(window, on: displays),
            CGRect(x: 1920, y: 100, width: 580, height: 800)
        )
    }

    func testClampKeepsCursorInsideAllEdges() {
        let bounds = CGRect(x: 100, y: 200, width: 800, height: 600)
        XCTAssertEqual(CursorGeometry.clamped(CGPoint(x: 50, y: 500), to: bounds).x, 100)
        XCTAssertEqual(CursorGeometry.clamped(CGPoint(x: 950, y: 500), to: bounds).x, 900)
        XCTAssertEqual(CursorGeometry.clamped(CGPoint(x: 500, y: 150), to: bounds).y, 200)
        XCTAssertEqual(CursorGeometry.clamped(CGPoint(x: 500, y: 850), to: bounds).y, 800)
    }

    func testStateLocksAnyRegisteredGame() {
        let game = GameIdentity(bundleIdentifier: "dev.example.game", displayName: "Example")
        XCTAssertEqual(
            CageStateResolver.resolve(
                hasPermission: true,
                game: game,
                windowBounds: CGRect(x: 40, y: 80, width: 1440, height: 900)
            ),
            .locked(game: game, bounds: CGRect(x: 44, y: 84, width: 1432, height: 892))
        )
    }

    func testStateReleasesWithoutForegroundGame() {
        XCTAssertEqual(
            CageStateResolver.resolve(
                hasPermission: true,
                game: nil,
                windowBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            ),
            .waiting
        )
    }

    func testPermissionStateWins() {
        let application = GameIdentity(
            bundleIdentifier: "dev.example.application",
            displayName: "Example"
        )
        XCTAssertEqual(
            CageStateResolver.resolve(
                hasPermission: false,
                game: application,
                windowBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            ),
            .permissionRequired
        )
    }

    func testConfinementCoversClicksDragsMovementAndScroll() {
        let required: [CGEventType] = [
            .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel,
        ]
        XCTAssertTrue(required.allSatisfy(CageMouseEvents.contains))
    }

    func testQuickMenuContainsOnlyApprovedActions() {
        XCTAssertEqual(StatusMenuModel.items.map(\.action), [.checkForUpdates, .settings, .quit])
        XCTAssertEqual(StatusMenuModel.items(hasAccessibilityAccess: true), StatusMenuModel.items)
    }

    func testPermissionPromptIsFirstAndDisappearsAfterGrant() {
        let denied = StatusMenuModel.items(hasAccessibilityAccess: false)
        XCTAssertEqual(denied.map(\.action), [.grantAccessibility, .checkForUpdates, .settings, .quit])
        XCTAssertEqual(Array(denied.dropFirst()), StatusMenuModel.items(hasAccessibilityAccess: true))
    }

    func testStatusIconReflectsLockState() {
        let game = GameIdentity(bundleIdentifier: "dev.example.game", displayName: "Example")
        XCTAssertEqual(StatusMenuModel.iconKind(for: .waiting), .idle)
        XCTAssertEqual(
            StatusMenuModel.iconKind(for: .locked(game: game, bounds: .zero)),
            .locked
        )
    }

    func testAllowedAppAlsoMatchesNestedAppBundle() {
        XCTAssertTrue(ApplicationPathMatcher.matches(
            candidatePath: "/Applications/Example.app/Contents/Runtime/Child.app",
            allowedPath: "/Applications/Example.app"
        ))
        XCTAssertFalse(ApplicationPathMatcher.matches(
            candidatePath: "/Applications/Example Pro.app",
            allowedPath: "/Applications/Example.app"
        ))
    }

    func testPreferredTargetUsesDeepestNonHelperApp() {
        let root = "/Applications/Container.app"
        XCTAssertEqual(
            ApplicationTargetResolver.preferredPath(
                rootPath: root,
                candidatePaths: [
                    root + "/Contents/ProductClient.app",
                    root + "/Contents/Game/Product.app",
                    root + "/Contents/Frameworks/Product Helper.app",
                ]
            ),
            root + "/Contents/Game/Product.app"
        )
    }
}
