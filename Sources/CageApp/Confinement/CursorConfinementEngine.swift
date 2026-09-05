import CageCore
import CoreGraphics
import Foundation

final class CursorConfinementEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var bounds: CGRect?
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
        update(bounds: nil)
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        runLoopSource = nil
        eventTap = nil
    }

    func update(bounds newBounds: CGRect?) {
        lock.lock()
        let changed = bounds != newBounds
        bounds = newBounds
        lock.unlock()
        guard changed, let newBounds, let location = CGEvent(source: nil)?.location else { return }
        let clamped = CursorGeometry.clamped(location, to: newBounds)
        if clamped != location { CGWarpMouseCursorPosition(clamped) }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        lock.lock()
        let activeBounds = bounds
        lock.unlock()
        guard let activeBounds else { return Unmanaged.passUnretained(event) }
        let clamped = CursorGeometry.clamped(event.location, to: activeBounds)
        if clamped != event.location { event.location = clamped }
        return Unmanaged.passUnretained(event)
    }
}

private let cageEventTapCallback: CGEventTapCallBack = { _, type, event, context in
    guard let context else { return Unmanaged.passUnretained(event) }
    return Unmanaged<CursorConfinementEngine>.fromOpaque(context)
        .takeUnretainedValue()
        .handle(type: type, event: event)
}
