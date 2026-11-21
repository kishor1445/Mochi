import AppKit

/// What the pet has on for whatever is playing (headphones for music are in PetView+Effects).
enum MediaGear: Equatable {
    case none
    case podcast    // one earbud in, nodding along, thinking dots now and then
    case video      // sitting in the flicker of the screen's light
    case movie      // 3D glasses, a bucket of popcorn and the screen's light

    /// The screen's light falls on the pet.
    var glows: Bool { self == .video || self == .movie }
}

/// Drawing the watching and listening gear.
extension PetView {
    /// Where the mouth roughly is, for popcorn on its way in.
    private func mouth(_ body: NSRect) -> NSPoint {
        NSPoint(x: body.midX + facing * 5, y: body.minY + body.height * 0.42)
    }

    // MARK: Pose

    /// A slow nod while listening, the way you agree along with someone talking. Added to the body's lift.
    var listeningNod: CGFloat {
        guard watching == .podcast, mood == .idle || mood == .sad else { return 0 }
        return abs(sin(time * 2.1)) * 1.8
    }

    // MARK: The screen's light

    /// A soft, shifting light over the front of the body, like the glow of a screen in a dark room.
    /// Drawn while the body is the clip, so it stays on the pet.
    func drawScreenGlow(_ body: NSRect) {
        guard watching.glows, mood != .sleep else { return }
        // Two slow waves make a flicker that never quite repeats: scenes changing.
        let flicker = 0.5 + 0.5 * sin(time * 2.3) * sin(time * 0.9 + 1)
        let cool = NSColor(calibratedRed: 0.55, green: 0.75, blue: 1.0, alpha: 1)
        let warm = NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.55, alpha: 1)
        // Mostly the cool light of a screen, warming a little now and then as the scene changes.
        let tint = cool.blended(withFraction: CGFloat(0.15 + 0.15 * sin(time * 0.37)), of: warm) ?? cool
        let strength: CGFloat = watching == .movie ? 0.26 : 0.22
        let g = NSGradient(starting: tint.withAlphaComponent(strength + CGFloat(flicker) * 0.16),
                           ending: tint.withAlphaComponent(strength * 0.25))
        // Brightest on the side facing the screen (towards the viewer, so the middle of the face).
        g?.draw(in: NSBezierPath(ovalIn: body.insetBy(dx: -body.width * 0.15, dy: -body.height * 0.1)),
                relativeCenterPosition: NSPoint(x: facing * 0.15, y: 0.25))
    }

    /// The screen, reflected as a small bright rectangle in each eye while watching a video.
    /// (During a film the 3D glasses are in the way.)
    func drawScreenReflection(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) {
        guard watching == .video, mood == .idle || mood == .walk || mood == .sad else { return }
        let flicker = CGFloat(0.75 + 0.25 * sin(time * 3.1))
        for dx in [CGFloat(-1), 1] {
            let r = NSRect(x: fx + dx * spread + gaze.x * 0.6 - 2.6, y: eyeY + gaze.y * 0.6 - 0.6, width: 5.2, height: 3.6)
            NSColor(calibratedRed: 0.80, green: 0.92, blue: 1.0, alpha: 0.95 * flicker).setFill()
            NSBezierPath(roundedRect: r, xRadius: 0.8, yRadius: 0.8).fill()
        }
    }

    // MARK: Films

    /// Red and blue cardboard 3D glasses, in place of whatever eyewear the pet has on.
    func draw3DGlasses(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) {
        let frame = NSColor(calibratedWhite: 0.97, alpha: 1)
        let edge = NSColor(calibratedWhite: 0.35, alpha: 1)
        let bar = NSBezierPath(roundedRect: NSRect(x: fx - spread - 10, y: eyeY - 7.5, width: spread * 2 + 20, height: 15),
                               xRadius: 4, yRadius: 4)
        frame.setFill(); bar.fill()
        edge.setStroke(); bar.lineWidth = 1.3; bar.stroke()
        // Red on the left, blue on the right, as seen by the viewer.
        for (dx, color) in [(CGFloat(-1), NSColor(calibratedRed: 0.93, green: 0.18, blue: 0.24, alpha: 0.9)),
                            (1, NSColor(calibratedRed: 0.10, green: 0.72, blue: 0.95, alpha: 0.9))] {
            let lens = NSBezierPath(roundedRect: NSRect(x: fx + dx * spread - 7.5, y: eyeY - 5, width: 15, height: 10),
                                    xRadius: 3, yRadius: 3)
            color.setFill(); lens.fill()
            NSColor.white.withAlphaComponent(0.6).setStroke()
            let shine = NSBezierPath()
            shine.move(to: NSPoint(x: fx + dx * spread - 4.5, y: eyeY + 2.2)); shine.line(to: NSPoint(x: fx + dx * spread - 1.5, y: eyeY + 2.8))
            shine.lineWidth = 1.2; shine.lineCapStyle = .round; shine.stroke()
        }
    }

    /// A striped bucket of popcorn held in front, and now and then a piece on its way to the mouth.
    func drawPopcorn(_ body: NSRect) {
        guard watching == .movie, mood != .sleep, mood != .held, mood != .jump else { return }
        let w: CGFloat = 17, h: CGFloat = 18
        let x = body.midX + facing * (body.width / 2 - 10) - w / 2
        let y = body.minY + 1
        let red = NSColor(calibratedRed: 0.88, green: 0.17, blue: 0.20, alpha: 1)

        // Popcorn heaped over the rim.
        let cream = NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.80, alpha: 1)
        let butter = NSColor(calibratedRed: 0.93, green: 0.78, blue: 0.40, alpha: 1)
        for (dx, dy, r) in [(CGFloat(2.5), CGFloat(h - 1), CGFloat(3.6)), (7.5, h + 1.5, 4), (12.5, h - 0.5, 3.6),
                            (5, h + 4, 3.2), (10.5, h + 4.5, 3.2)] {
            let puff = NSBezierPath(ovalIn: NSRect(x: x + dx - r, y: y + dy - r, width: r * 2, height: r * 2))
            cream.setFill(); puff.fill()
            butter.setStroke(); puff.lineWidth = 0.8; puff.stroke()
        }

        // The bucket: narrower at the bottom, red and white stripes.
        let bucket = NSBezierPath()
        bucket.move(to: NSPoint(x: x, y: y + h))
        bucket.line(to: NSPoint(x: x + w, y: y + h))
        bucket.line(to: NSPoint(x: x + w - 2.5, y: y))
        bucket.line(to: NSPoint(x: x + 2.5, y: y))
        bucket.close()
        NSColor.white.setFill(); bucket.fill()
        NSGraphicsContext.saveGraphicsState()
        bucket.addClip()
        red.setFill()
        for i in stride(from: 0, to: 4, by: 2) {
            NSBezierPath(rect: NSRect(x: x + CGFloat(i) * w / 4 + 1, y: y, width: w / 4, height: h)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        NSColor(calibratedRed: 0.45, green: 0.08, blue: 0.10, alpha: 1).setStroke()
        bucket.lineWidth = 1.2; bucket.stroke()

        // Every few seconds a piece flies up to the mouth.
        let cycle: CGFloat = 4.2
        let t = fmod(time, cycle) / 0.7
        if t < 1 {
            let from = NSPoint(x: x + w / 2, y: y + h + 3)
            let to = mouth(body)
            let px = from.x + (to.x - from.x) * t
            let py = from.y + (to.y - from.y) * t + sin(t * .pi) * 14
            let r: CGFloat = 2.6
            let piece = NSBezierPath(ovalIn: NSRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
            cream.setFill(); piece.fill()
            butter.setStroke(); piece.lineWidth = 0.8; piece.stroke()
        }
    }

    /// Chewing right after a piece of popcorn goes in.
    var munching: Bool {
        guard watching == .movie, mood == .idle else { return false }
        let t = fmod(time, 4.2)
        return t > 0.7 && t < 1.6
    }

    // MARK: Podcasts

    /// One earbud in, on the side facing us, and now and then three dots rising: thinking it over.
    func drawPodcastGear(_ body: NSRect) {
        guard watching == .podcast, mood != .held else { return }
        let bud = NSPoint(x: body.midX - facing * (body.width / 2 - 1), y: body.minY + body.height * 0.68)
        let stem = NSBezierPath(roundedRect: NSRect(x: bud.x - 2, y: bud.y - 11, width: 4, height: 11), xRadius: 2, yRadius: 2)
        let head = NSBezierPath(ovalIn: NSRect(x: bud.x - 5, y: bud.y - 3.5, width: 10, height: 9))
        let edge = NSColor(calibratedWhite: 0.30, alpha: 1)
        NSColor.white.setFill(); stem.fill(); head.fill()
        edge.setStroke(); stem.lineWidth = 1.3; stem.stroke(); head.lineWidth = 1.3; head.stroke()
        // The speaker grille, so it reads as an earbud at a glance.
        NSColor(calibratedWhite: 0.25, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: bud.x - 1.8 + facing * 1.2, y: bud.y - 0.2, width: 3.6, height: 3.2)).fill()

        guard mood != .sleep else { return }
        let cycle = fmod(time, 9)
        guard cycle > 6 else { return }
        let shown = (cycle - 6) / 3                     // 0…1 over three seconds
        for i in 0..<3 {
            let appear = CGFloat(i) * 0.15
            guard shown > appear else { continue }
            let alpha = min(1, (shown - appear) * 4) * (shown > 0.85 ? (1 - shown) / 0.15 : 1)
            let r: CGFloat = 1.8 + CGFloat(i) * 0.6
            let p = NSPoint(x: body.midX + facing * (10 + CGFloat(i) * 6), y: body.maxY + 4 + CGFloat(i) * 5)
            NSColor(calibratedWhite: 0.45, alpha: alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)).fill()
        }
    }
}
