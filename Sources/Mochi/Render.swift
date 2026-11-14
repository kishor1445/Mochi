import AppKit

/// Developer helper: `Mochi --render <dir>` writes a contact sheet of every pet and mood to a PNG.
enum Render {
    static func run(to path: String) {
        let moods: [Mood] = [.idle, .walk, .happy, .sleep, .held, .dance, .stretch, .dizzy, .sad]
        let cell = PetView.side
        let sheet = NSImage(size: NSSize(width: cell * CGFloat(moods.count), height: cell * CGFloat(Species.allCases.count + 2)))
        sheet.lockFocus()
        NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
        NSRect(origin: .zero, size: sheet.size).fill()
        for (row, sp) in Species.allCases.enumerated() {
            for (col, m) in moods.enumerated() {
                let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
                v.species = sp; v.mood = m; v.time = 0.6; v.facing = 1
                if m == .walk { v.time = 0.15 }
                let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
                v.cacheDisplay(in: v.bounds, to: rep)
                let img = NSImage(size: v.bounds.size); img.addRepresentation(rep)
                img.draw(at: NSPoint(x: CGFloat(col) * cell, y: sheet.size.height - cell * CGFloat(row + 1)),
                         from: .zero, operation: .sourceOver, fraction: 1)
            }
        }
        // bottom row: wall / ceiling orientations for the penguin
        for (col, a) in [CGFloat(0), -.pi / 2, .pi / 2, .pi].enumerated() {
            let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
            v.species = .penguin; v.mood = .idle; v.angle = a; v.time = 0.6
            let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
            v.cacheDisplay(in: v.bounds, to: rep)
            let img = NSImage(size: v.bounds.size); img.addRepresentation(rep)
            img.draw(at: NSPoint(x: CGFloat(col) * cell, y: cell), from: .zero, operation: .sourceOver, fraction: 1)
        }
        for (i, sp) in Species.allCases.enumerated() {
            let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
            v.species = sp; v.mood = .idle; v.musicBpm = 120; v.time = 0.45
            let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
            v.cacheDisplay(in: v.bounds, to: rep)
            let img = NSImage(size: v.bounds.size); img.addRepresentation(rep)
            img.draw(at: NSPoint(x: CGFloat(i) * cell, y: 0), from: .zero, operation: .sourceOver, fraction: 1)
        }
        sheet.unlockFocus()
        if let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}

import SwiftUI

extension Render {
    /// Writes each settings tab and the menu header next to `path` (…-behavior.png, …-general.png, …-menu.png).
    static func settings(to path: String) {
        let s = PetSettings.shared
        let size = SettingsView.size
        snapshot(PetTab(settings: s, onSayHi: {}, onTreat: {}, onPlay: {}).frame(width: size.width, height: size.height), to: path)
        snapshot(BehaviorTab(settings: s).frame(width: size.width, height: size.height),
                 to: path.replacingOccurrences(of: ".png", with: "-behavior.png"))
        snapshot(GeneralTab(settings: s, onBringBack: {}).frame(width: size.width, height: size.height),
                 to: path.replacingOccurrences(of: ".png", with: "-general.png"))
        snapshot(MenuHeader(mind: .shared, species: s.species), to: path.replacingOccurrences(of: ".png", with: "-menu.png"))
    }

    private static func snapshot<V: View>(_ view: V, to path: String) {
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSAppearance(named: .aqua)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let win = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        win.contentView = host
        host.layoutSubtreeIfNeeded()
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path)) }
    }
}
