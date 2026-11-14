import AppKit

enum Mood { case idle, walk, sleep, happy, chase, held, jump, dance, stretch, dizzy }

struct Heart {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var age: CGFloat      // negative = waiting to appear
}

/// Draws the pet with Core Graphics (no image assets) and forwards mouse input.
final class PetView: NSView {
    static let side: CGFloat = 120
    static let size = NSSize(width: side, height: side)

    var species: Species = .mochi
    var mood: Mood = .idle
    var facing: CGFloat = 1              // local: +1 = looking right
    var time: CGFloat = 0
    var angle: CGFloat = 0               // radians; rotates the pet onto walls / ceiling
    var spin: CGFloat = 0                // extra twirl / wobble around the pet's own centre
    var gaze: CGPoint = .zero            // where the eyes look (local coordinates)
    var musicBpm: CGFloat = 0            // > 0 while music plays: headphones + bobbing to the beat
    var isPreview = false                // settings-panel mini version

    var onClick: (() -> Void)?
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?

    private var hearts: [Heart] = []
    private var dragged = false
    private var previewTimer: Timer?

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { isPreview ? nil : super.hitTest(point) }

    // MARK: Animation clock

    func advance(_ dt: CGFloat) {
        time += dt
        for i in hearts.indices {
            hearts[i].age += dt
            if hearts[i].age > 0 { hearts[i].y += 36 * dt }
        }
        hearts.removeAll { $0.age > 1.1 }
    }

    func spawnHearts(_ n: Int) {
        for i in 0..<n {
            hearts.append(Heart(x: bounds.midX + .random(in: -24...24), y: 70 + .random(in: 0...10),
                                size: .random(in: 5...8), age: -CGFloat(i) * 0.15))
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        previewTimer?.invalidate()
        previewTimer = nil
        guard isPreview, window != nil else { return }
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.previewTick() }
        RunLoop.main.add(t, forMode: .common)
        previewTimer = t
    }

    private func previewTick() {
        advance(1.0 / 30.0)
        let phase = fmod(time, 12)
        if phase < 4 { mood = .idle } else if phase < 7 { mood = .walk }
        else if phase < 9 { mood = .happy } else if phase < 11 { mood = .dance } else { mood = .sleep }
        facing = fmod(time, 24) < 12 ? 1 : -1
        needsDisplay = true
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) { dragged = false }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        if !dragged { dragged = true; onDragBegan?() }
        var o = window.frame.origin
        o.x += event.deltaX
        o.y -= event.deltaY
        window.setFrameOrigin(o)
    }

    override func mouseUp(with event: NSEvent) {
        if dragged { onDragEnded?() } else { onClick?() }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.rotate(by: angle)
        ctx.translateBy(x: -bounds.midX, y: -bounds.midY)
        if spin != 0 {
            ctx.translateBy(x: bounds.midX, y: 36)
            ctx.rotate(by: spin)
            ctx.translateBy(x: -bounds.midX, y: -36)
        }
        var sway: CGFloat = 0
        if mood == .dance { sway = sin(time * 8) * 0.14 }
        else if species == .penguin && (mood == .walk || mood == .chase) { sway = sin(time * 10) * 0.12 }
        if sway != 0 {
            ctx.translateBy(x: bounds.midX, y: 8)
            ctx.rotate(by: sway)
            ctx.translateBy(x: -bounds.midX, y: -8)
        }
        drawPet(ctx)
        ctx.restoreGState()
        drawHearts()
    }

    private func drawPet(_ ctx: CGContext) {
        let sp = species
        let t = time
        var squash: CGFloat = 1 + 0.03 * sin(t * 2)    // breathing
        var lift: CGFloat = 0

        switch mood {
        case .walk:  let s = abs(sin(t * 10)); lift = s * 6 * sp.hopFactor;  squash = 1 - 0.05 * s
        case .chase: let s = abs(sin(t * 14)); lift = s * 9 * sp.hopFactor;  squash = 1 - 0.07 * s
        case .happy: lift = abs(sin(t * 9)) * 16; squash = 1.05
        case .sleep: squash = 1 + 0.06 * sin(t * 1.4)
        case .held:  squash = 1.12
        case .jump:  squash = 1.15
        case .dance: lift = abs(sin(t * 8)) * 8; squash = 1 + 0.06 * sin(t * 16)
        case .stretch: squash = 1.18 + 0.07 * sin(t * 5)
        case .dizzy: squash = 1 + 0.03 * sin(t * 3)
        case .idle:  break
        }
        // Bob to the beat while music plays.
        if musicBpm > 0, mood == .idle || mood == .walk || mood == .chase {
            let beat = abs(sin(t * .pi * musicBpm / 60))
            lift += beat * 4
            squash -= beat * 0.04
        }
        // Ghosts float.
        let hover: CGFloat = sp == .ghost ? (mood == .sleep ? 1 : 7 + sin(t * 3) * 2.5) : 0

        let baseW: CGFloat = sp == .mochi ? 74 : (sp == .penguin ? 64 : 66)
        let baseH: CGFloat = sp == .mochi ? 56 : (sp == .penguin ? 68 : 66)
        let h = baseH * squash
        let w = baseW * (2 - squash)
        let body = NSRect(x: bounds.midX - w / 2, y: 8 + lift + hover, width: w, height: h)

        // Shadow
        let ss = max(0.35, 1 - (lift + hover) / 60)
        NSColor.black.withAlphaComponent(0.18).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 30 * ss, y: 4, width: 60 * ss, height: 8)).fill()

        // Behind the body
        switch sp {
        case .mochi: drawSprout(ctx, body)
        case .penguin: drawFlippers(ctx, body)
        case .ghost: drawGhostArms(ctx, body)
        }
        if sp != .ghost { drawFeet(body) }

        // Body
        let path = bodyPath(body)
        sp.fur.setFill()
        path.fill()
        if sp == .penguin { drawPenguinMarkings(body) }
        sp.outline.setStroke()
        path.lineWidth = 2.5
        path.stroke()
        if sp == .penguin { drawScarf(ctx, body) }

        drawFace(body)
        if musicBpm > 0 { drawHeadphones(body) }
        if mood == .sleep { drawZs(near: body) }
        if mood == .dance || (musicBpm > 0 && mood != .sleep) { drawNotes(near: body) }
    }

    private func bodyPath(_ body: NSRect) -> NSBezierPath {
        switch species {
        case .mochi:
            return NSBezierPath(roundedRect: body, xRadius: body.width * 0.45, yRadius: body.height * 0.5)
        case .penguin:
            return NSBezierPath(roundedRect: body, xRadius: body.width * 0.5, yRadius: body.height * 0.46)
        case .ghost:
            // dome on top, wavy hem at the bottom
            let r = body.width / 2
            let hemY = body.minY + 10
            let p = NSBezierPath()
            p.move(to: NSPoint(x: body.minX, y: hemY))
            p.line(to: NSPoint(x: body.minX, y: body.maxY - r))
            p.appendArc(withCenter: NSPoint(x: body.midX, y: body.maxY - r), radius: r,
                        startAngle: 180, endAngle: 0, clockwise: true)
            p.line(to: NSPoint(x: body.maxX, y: hemY))
            let n = 3
            let sw = body.width / CGFloat(n)
            for i in 0..<n {
                let x1 = body.maxX - sw * CGFloat(i), x2 = x1 - sw
                let sag = hemY - 13 + sin(time * 6 + CGFloat(i)) * 2
                p.curve(to: NSPoint(x: x2, y: hemY),
                        controlPoint1: NSPoint(x: x1 - sw * 0.1, y: sag),
                        controlPoint2: NSPoint(x: x2 + sw * 0.1, y: sag))
            }
            p.close()
            p.lineJoinStyle = .round
            return p
        }
    }

    // MARK: Parts

    private func drawFeet(_ body: NSRect) {
        let step: CGFloat = (mood == .walk || mood == .chase) ? sin(time * (mood == .chase ? 14 : 10)) : 0
        let wide: CGFloat = species == .penguin ? 17 : 14
        for (i, dx) in ([-1, 1] as [CGFloat]).enumerated() {
            let up = max(0, i == 0 ? step : -step) * 4
            let r = NSRect(x: body.midX + dx * body.width * 0.22 - wide / 2, y: body.minY - 1 + up, width: wide, height: 9)
            let p = NSBezierPath(ovalIn: r)
            species.foot.setFill(); p.fill()
            species.footOutline.setStroke(); p.lineWidth = 2; p.stroke()
        }
    }

    private func drawSprout(_ ctx: CGContext, _ body: NSRect) {
        let sway = sin(time * 3) * 0.08
        ctx.saveGState()
        ctx.translateBy(x: body.midX + facing * 4, y: body.maxY - 3)
        for ang in [CGFloat(0.7), -0.7] {
            ctx.saveGState()
            ctx.rotate(by: ang + sway)
            let leaf = NSBezierPath(ovalIn: NSRect(x: -4, y: 0, width: 8, height: 15))
            NSColor(calibratedRed: 0.55, green: 0.82, blue: 0.5, alpha: 1).setFill(); leaf.fill()
            NSColor(calibratedRed: 0.28, green: 0.5, blue: 0.3, alpha: 1).setStroke(); leaf.lineWidth = 1.5; leaf.stroke()
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    /// A limb that hangs from `pivot` and swings by `ang` (positive = counter-clockwise).
    private func drawLimb(_ ctx: CGContext, pivot: NSPoint, size: NSSize, ang: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: pivot.x, y: pivot.y)
        ctx.rotate(by: ang)
        let p = NSBezierPath(ovalIn: NSRect(x: -size.width / 2, y: -size.height, width: size.width, height: size.height))
        species.fur.setFill(); p.fill()
        species.outline.setStroke(); p.lineWidth = 2.2; p.stroke()
        ctx.restoreGState()
    }

    private func drawFlippers(_ ctx: CGContext, _ body: NSRect) {
        for side in [CGFloat(-1), 1] {
            var ang = side * 0.3
            switch mood {
            case .walk, .chase: ang += sin(time * 10 + (side < 0 ? 0 : .pi)) * 0.28
            case .happy, .dance, .jump: ang = side * (2.2 + sin(time * 14) * 0.35)
            case .stretch: ang = side * 2.6
            case .held: ang = side * (2.0 + sin(time * 20) * 0.4)
            case .sleep: ang = side * 0.12
            case .dizzy: ang = side * (1.0 + sin(time * 12) * 0.3)
            case .idle: ang += sin(time * 2 + side) * 0.04
            }
            let pivot = NSPoint(x: body.midX + side * (body.width / 2 - 3), y: body.minY + body.height * 0.56)
            drawLimb(ctx, pivot: pivot, size: NSSize(width: 12, height: 26), ang: ang)
        }
    }

    private func drawGhostArms(_ ctx: CGContext, _ body: NSRect) {
        for side in [CGFloat(-1), 1] {
            var ang = side * 0.95
            switch mood {
            case .happy, .dance, .jump: ang = side * (2.2 + sin(time * 12) * 0.35)
            case .stretch: ang = side * 2.6
            case .held: ang = side * (2.0 + sin(time * 20) * 0.4)
            case .dizzy: ang = side * (1.2 + sin(time * 12) * 0.4)
            case .walk, .chase: ang += sin(time * 8 + side) * 0.2
            default: ang += sin(time * 2.4 + side) * 0.1
            }
            let pivot = NSPoint(x: body.midX + side * (body.width / 2 - 2), y: body.minY + body.height * 0.42)
            drawLimb(ctx, pivot: pivot, size: NSSize(width: 9, height: 18), ang: ang)
        }
    }

    private func drawPenguinMarkings(_ body: NSRect) {
        let white = NSColor(calibratedRed: 0.98, green: 0.98, blue: 1.0, alpha: 1)
        white.setFill()
        let eyeY = body.minY + body.height * 0.58
        let fx = body.midX + facing * 5
        // face patch + belly, merged into one white shape
        NSBezierPath(ovalIn: NSRect(x: fx - body.width * 0.37, y: eyeY - 3 - body.height * 0.17,
                                    width: body.width * 0.74, height: body.height * 0.34)).fill()
        NSBezierPath(ovalIn: NSRect(x: body.midX + facing - body.width * 0.33, y: body.minY + body.height * 0.04,
                                    width: body.width * 0.66, height: body.height * 0.52)).fill()
    }

    private func drawScarf(_ ctx: CGContext, _ body: NSRect) {
        let red = NSColor(calibratedRed: 0.92, green: 0.30, blue: 0.34, alpha: 1)
        let y = body.minY + body.height * 0.27
        let band = NSBezierPath(roundedRect: NSRect(x: body.midX - body.width * 0.40, y: y, width: body.width * 0.80, height: 9),
                                xRadius: 4.5, yRadius: 4.5)
        red.setFill(); band.fill()
        species.outline.setStroke(); band.lineWidth = 1.8; band.stroke()
        // the dangling end sits on the back side
        let tailX = body.midX - facing * (body.width * 0.30)
        let tail = NSBezierPath(roundedRect: NSRect(x: tailX - 4, y: y - 9, width: 8, height: 13), xRadius: 2, yRadius: 2)
        red.setFill(); tail.fill()
        species.outline.setStroke(); tail.lineWidth = 1.6; tail.stroke()
    }

    // MARK: Face

    private func drawFace(_ body: NSRect) {
        let sp = species
        let ink = sp.ink
        let eyeY = body.minY + body.height * (sp == .mochi ? 0.55 : 0.58)
        let spread: CGFloat = sp == .mochi ? 11 : (sp == .penguin ? 9.5 : 10)
        let fx = body.midX + facing * (sp == .mochi ? 7 : 5)
        let blinking = fmod(time + 1.3, 4.3) < 0.12

        // Cheeks
        sp.accent.withAlphaComponent(0.55).setFill()
        for dx in [CGFloat(-1), 1] {
            NSBezierPath(ovalIn: NSRect(x: fx + dx * (spread + 7) - 5, y: eyeY - 12, width: 10, height: 6)).fill()
        }

        // Eyes
        ink.setFill(); ink.setStroke()
        for dx in [CGFloat(-1), 1] {
            let ex = fx + dx * spread
            switch mood {
            case .sleep, .stretch:
                arc(NSPoint(x: ex, y: eyeY + 1), 4, 200, 340)
            case .happy, .dance:
                arc(NSPoint(x: ex, y: eyeY - 2), 4.5, 20, 160)
            case .dizzy:
                spiral(NSPoint(x: ex, y: eyeY), 5.5)
            default:
                let wide = mood == .held
                let ew: CGFloat = wide ? 7.5 : 6.4
                let eh: CGFloat = blinking ? 1.5 : (wide ? 10 : 8.4)
                let gx = wide ? 0 : gaze.x, gy = wide ? 0 : gaze.y
                let r = NSRect(x: ex - ew / 2 + gx, y: eyeY - eh / 2 + gy, width: ew, height: eh)
                NSBezierPath(ovalIn: r).fill()
                if !blinking {
                    NSColor.white.setFill()
                    NSBezierPath(ovalIn: NSRect(x: r.midX + 0.4, y: r.midY + eh * 0.12, width: 2.4, height: 2.4)).fill()
                    ink.setFill()
                }
            }
        }

        // Mouth / beak
        let open = mood == .happy || mood == .held || mood == .stretch || mood == .dance
        switch sp {
        case .mochi:
            if open {
                ink.setFill()
                NSBezierPath(ovalIn: NSRect(x: fx - 3, y: eyeY - 17, width: 6, height: 7)).fill()
            } else {
                arc(NSPoint(x: fx, y: eyeY - 9), 3, 200, 340)
            }
        case .penguin:
            if open {
                ink.setFill()
                NSBezierPath(ovalIn: NSRect(x: fx - 3.5, y: eyeY - 14, width: 7, height: 5)).fill()
            }
            let beak = NSBezierPath(ovalIn: NSRect(x: fx - 5.5, y: eyeY - (open ? 9 : 10.5), width: 11, height: 7))
            sp.foot.setFill(); beak.fill()
            sp.footOutline.setStroke(); beak.lineWidth = 1.4; beak.stroke()
        case .ghost:
            ink.setFill()
            let mw: CGFloat = open ? 6.5 : 4.5, mh: CGFloat = open ? 9 : 6
            NSBezierPath(ovalIn: NSRect(x: fx - mw / 2, y: eyeY - 9 - mh + 4, width: mw, height: mh)).fill()
        }
    }

    private func spiral(_ c: NSPoint, _ r: CGFloat) {
        let turns: CGFloat = 2.2
        let total = turns * 2 * .pi
        let p = NSBezierPath()
        var a: CGFloat = 0
        var first = true
        while a <= total {
            let rr = r * a / total
            let ang = a + time * 8
            let pt = NSPoint(x: c.x + cos(ang) * rr, y: c.y + sin(ang) * rr)
            if first { p.move(to: pt); first = false } else { p.line(to: pt) }
            a += 0.4
        }
        p.lineWidth = 1.4
        p.lineCapStyle = .round
        p.stroke()
    }

    private func arc(_ center: NSPoint, _ radius: CGFloat, _ start: CGFloat, _ end: CGFloat) {
        let p = NSBezierPath()
        p.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
        p.lineWidth = 2
        p.lineCapStyle = .round
        p.stroke()
    }

    // MARK: Accessories & effects

    private func drawHeadphones(_ body: NSRect) {
        // The "head" is the whole body, except for the ghost where it is the dome.
        let isGhost = species == .ghost
        let a = body.width / 2 + 3
        let b = (isGhost ? body.width / 2 : body.height / 2) + 3
        let c = NSPoint(x: body.midX, y: isGhost ? body.maxY - body.width / 2 : body.midY)

        let band = NSBezierPath()
        var deg: CGFloat = 18
        while deg <= 162 {
            let r = deg * .pi / 180
            let pt = NSPoint(x: c.x + a * cos(r), y: c.y + b * sin(r))
            if deg == 18 { band.move(to: pt) } else { band.line(to: pt) }
            deg += 6
        }
        band.lineWidth = 4
        band.lineCapStyle = .round
        NSColor(calibratedWhite: 0.22, alpha: 1).setStroke()
        band.stroke()

        for deg in [CGFloat(12), 168] {
            let r = deg * .pi / 180
            let p = NSPoint(x: c.x + a * cos(r), y: c.y + b * sin(r))
            let cup = NSBezierPath(roundedRect: NSRect(x: p.x - 4.5, y: p.y - 8, width: 9, height: 16), xRadius: 4, yRadius: 4)
            NSColor(calibratedRed: 0.95, green: 0.36, blue: 0.5, alpha: 1).setFill(); cup.fill()
            NSColor(calibratedRed: 0.3, green: 0.1, blue: 0.18, alpha: 1).setStroke(); cup.lineWidth = 1.5; cup.stroke()
        }
    }

    private func drawZs(near body: NSRect) {
        for i in 0..<2 {
            let phase = fmod(time * 0.6 + CGFloat(i) * 0.5, 1)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 14),
                .foregroundColor: NSColor.systemIndigo.withAlphaComponent(1 - phase)
            ]
            ("z" as NSString).draw(at: NSPoint(x: body.maxX - 6 + phase * 10, y: body.maxY - 6 + phase * 16),
                                   withAttributes: attrs)
        }
    }

    private func drawNotes(near body: NSRect) {
        for i in 0..<2 {
            let phase = fmod(time * 0.9 + CGFloat(i) * 0.5, 1)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 16),
                .foregroundColor: NSColor.systemPink.withAlphaComponent(1 - phase)
            ]
            let side: CGFloat = i == 0 ? -1 : 1
            ("♪" as NSString).draw(at: NSPoint(x: body.midX + side * (body.width / 2 - 4) + side * phase * 8,
                                               y: body.maxY - 10 + phase * 22), withAttributes: attrs)
        }
    }

    private func drawHearts() {
        for h in hearts where h.age >= 0 {
            let alpha = max(0, 1 - h.age / 1.1)
            let s = h.size
            let p = NSBezierPath()
            p.move(to: NSPoint(x: h.x, y: h.y - s * 0.9))
            p.curve(to: NSPoint(x: h.x - s, y: h.y + s * 0.2),
                    controlPoint1: NSPoint(x: h.x - s * 0.4, y: h.y - s * 0.6),
                    controlPoint2: NSPoint(x: h.x - s, y: h.y - s * 0.3))
            p.curve(to: NSPoint(x: h.x, y: h.y + s * 0.35),
                    controlPoint1: NSPoint(x: h.x - s, y: h.y + s * 0.9),
                    controlPoint2: NSPoint(x: h.x - s * 0.2, y: h.y + s * 0.9))
            p.curve(to: NSPoint(x: h.x + s, y: h.y + s * 0.2),
                    controlPoint1: NSPoint(x: h.x + s * 0.2, y: h.y + s * 0.9),
                    controlPoint2: NSPoint(x: h.x + s, y: h.y + s * 0.9))
            p.curve(to: NSPoint(x: h.x, y: h.y - s * 0.9),
                    controlPoint1: NSPoint(x: h.x + s, y: h.y - s * 0.3),
                    controlPoint2: NSPoint(x: h.x + s * 0.4, y: h.y - s * 0.6))
            NSColor(calibratedRed: 1, green: 0.35, blue: 0.5, alpha: alpha).setFill()
            p.fill()
        }
    }
}
