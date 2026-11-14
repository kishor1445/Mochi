import AppKit

/// A flat place the pet can stand: the Dock/screen bottom (id 0) or the top edge of a window.
struct Platform {
    let id: Int
    let minX: CGFloat     // range the pet's centre may occupy
    let maxX: CGFloat
    let top: CGFloat      // y (AppKit coordinates) of the surface
}

/// Finds visible windows so the pet can stand on them. Needs no special permission
/// (it only reads window frames, not their contents).
enum WindowScanner {
    static func platforms(in f: NSRect) -> [Platform] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else { return [] }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? f.maxY
        let myPID = Int(ProcessInfo.processInfo.processIdentifier)

        var result: [Platform] = []
        var inFront: [CGRect] = []          // CG-coordinate frames of windows above the current one

        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  let pid = (w[kCGWindowOwnerPID as String] as? NSNumber)?.intValue, pid != myPID,
                  let number = (w[kCGWindowNumber as String] as? NSNumber)?.intValue,
                  let bounds = w[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { continue }
            let alpha = (w[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1

            defer { inFront.append(rect) }
            guard alpha > 0.5, rect.width >= 240, rect.height >= 120 else { continue }

            let top = primaryHeight - rect.minY
            guard top <= f.maxY - 76, top >= f.minY + 40 else { continue }       // room for the pet above it
            guard rect.maxX > f.minX + 100, rect.minX < f.maxX - 100 else { continue }

            // Skip windows whose top edge is hidden behind another window.
            let probe = CGPoint(x: rect.midX, y: rect.minY + 2)
            if inFront.contains(where: { $0.contains(probe) }) { continue }

            let lo = max(rect.minX + 24, f.minX + 52)
            let hi = min(rect.maxX - 24, f.maxX - 52)
            guard hi - lo >= 60 else { continue }
            result.append(Platform(id: number, minX: lo, maxX: hi, top: top))
        }
        return result
    }
}
