import CageCore
import CoreGraphics
import Foundation

enum GameWindowLocator {
    static func windowBounds(processIdentifier: pid_t) -> CGRect? {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        return windows.compactMap { window -> CGRect? in
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == processIdentifier,
                  (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let dictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dictionary),
                  bounds.width >= 640,
                  bounds.height >= 480 else { return nil }
            return CursorGeometry.visibleWindowBounds(bounds, on: activeDisplayBounds) ?? bounds
        }
        .max { $0.width * $0.height < $1.width * $1.height }
    }

    private static var activeDisplayBounds: [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
        return displays.prefix(Int(count)).map(CGDisplayBounds)
    }
}
