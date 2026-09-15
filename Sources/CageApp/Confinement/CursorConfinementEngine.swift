import CageCore
import CoreGraphics
import Foundation

final class CursorConfinementEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var bounds: CGRect?
    private var windowPixelBounds: CGRect?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func install() -> Bool {
        guard eventTap == nil else { return true }
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CageMouseEvents.mask,
            callback: cageEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        return true
    }

    func uninstall() {
        update(bounds: nil, windowBounds: nil)
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        runLoopSource = nil
        eventTap = nil
    }

    func update(bounds newBounds: CGRect?, windowBounds: CGRect?) {
        let newWindowPixelBounds = windowBounds.flatMap(CursorGeometry.windowPixelBounds)
        lock.lock()
        let changed = bounds != newBounds
        bounds = newBounds
        windowPixelBounds = newWindowPixelBounds
        lock.unlock()
        guard changed, let newBounds, let location = CGEvent(source: nil)?.location else { return }
        let safeLocation = CursorGeometry.clamped(location, to: newBounds)
        if safeLocation != location { CGWarpMouseCursorPosition(safeLocation) }
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let isMovement = type == .mouseMoved
            || type == .leftMouseDragged
            || type == .rightMouseDragged
            || type == .otherMouseDragged

        lock.lock()
        guard let activeBounds = bounds,
              let activeWindowPixelBounds = windowPixelBounds else {
            lock.unlock()
            return Unmanaged.passUnretained(event)
        }
        lock.unlock()

        if isMovement {
            let safeLocation = CursorGeometry.clamped(event.location, to: activeBounds)
            if safeLocation != event.location {
                scheduleWarp(to: safeLocation, whileUsing: activeBounds)
            }
            return Unmanaged.passUnretained(event)
        }

        let gameLocation = CursorGeometry.clamped(event.location, to: activeWindowPixelBounds)
        if gameLocation != event.location { event.location = gameLocation }
        let safeLocation = CursorGeometry.clamped(gameLocation, to: activeBounds)
        if safeLocation != gameLocation {
            scheduleWarp(to: safeLocation, whileUsing: activeBounds)
        }
        return Unmanaged.passUnretained(event)
    }

    private func scheduleWarp(to location: CGPoint, whileUsing expectedBounds: CGRect) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let stillLocked = self.bounds == expectedBounds
            self.lock.unlock()
            if stillLocked { CGWarpMouseCursorPosition(location) }
        }
    }
}

private let cageEventTapCallback: CGEventTapCallBack = { _, type, event, context in
    guard let context else { return Unmanaged.passUnretained(event) }
    return Unmanaged<CursorConfinementEngine>.fromOpaque(context)
        .takeUnretainedValue()
        .handle(type: type, event: event)
}
