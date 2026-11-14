import AppKit

enum Mood { case idle, walk, sleep, happy, chase, held, jump, dance, stretch }

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
    var spin: CGFloat = 0                // extra twirl around the pet's own centre
    var gaze: CGPoint = .zero            // where the eyes look (local coordinates)
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
        let phase = fmod(time, 10)
        if phase < 4 { mood = .idle } else if phase < 7 { mood = .walk }
        else if phase < 9 { mood = .happy } else { mood = .sleep }
        facing = fmod(time, 20) < 10 ? 1 : -1
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
        if mood == .dance {
            ctx.translateBy(x: bounds.midX, y: 8)
            ctx.rotate(by: sin(time * 8) * 0.14)
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
        case .dance: lift = abs(sin(time * 8)) * 8; squash = 1 + 0.06 * sin(time * 16)
        case .stretch: squash = 1.18 + 0.07 * sin(time * 5)
        case .idle:  break
        }

        let baseW: CGFloat = sp == .bunny ? 62 : (sp == .cat ? 72 : 74)
        let baseH: CGFloat = sp == .bunny ? 54 : (sp == .cat ? 52 : 56)
        let h = baseH * squash
        let w = baseW * (2 - squash)
        let body = NSRect(x: bounds.midX - w / 2, y: 8 + lift, width: w, height: h)

        // Shadow
        let ss = max(0.4, 1 - lift / 60)
        NSColor.black.withAlphaComponent(0.18).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 30 * ss, y: 4, width: 60 * ss, height: 8)).fill()

        // Behind the body: tail, ears, sprout, feet
        switch sp {
        case .mochi: drawSprout(ctx, body)
        case .cat:   drawCatTail(body); drawCatEars(body)
        case .bunny: drawBunnyTail(body); drawBunnyEars(ctx, body)
        }
        drawFeet(body)

        // Body
        let path = NSBezierPath(roundedRect: body, xRadius: w * 0.45, yRadius: h * 0.5)
        sp.fur.setFill()
        path.fill()
        if sp == .cat {
            NSColor(calibratedRed: 1, green: 0.92, blue: 0.8, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: body.midX - 15, y: body.minY + 3, width: 30, height: h * 0.38)).fill()
        }
        sp.outline.setStroke()
        path.lineWidth = 2.5
        path.stroke()

        drawFace(body)
        if mood == .sleep { drawZs(near: body) }
        if mood == .dance { drawNotes(near: body) }
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

    // MARK: Parts

    private func drawFeet(_ body: NSRect) {
        let step: CGFloat = (mood == .walk || mood == .chase) ? sin(time * (mood == .chase ? 14 : 10)) : 0
        for (i, dx) in ([-1, 1] as [CGFloat]).enumerated() {
            let up = max(0, i == 0 ? step : -step) * 4
            let r = NSRect(x: body.midX + dx * body.width * 0.22 - 7, y: body.minY - 1 + up, width: 14, height: 9)
            let p = NSBezierPath(ovalIn: r)
            species.fur.setFill(); p.fill()
            species.outline.setStroke(); p.lineWidth = 2; p.stroke()
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

    private func drawCatTail(_ body: NSRect) {
        let dir = -facing
        let base = NSPoint(x: body.midX + dir * (body.width / 2 - 8), y: body.minY + body.height * 0.3)
        let active = mood == .walk || mood == .chase
        let wag = sin(time * (active ? 9 : 3)) * 9
        let p = NSBezierPath()
        p.move(to: base)
        p.curve(to: NSPoint(x: base.x + dir * 20 + wag, y: base.y + 30),
                controlPoint1: NSPoint(x: base.x + dir * 24, y: base.y + 2),
                controlPoint2: NSPoint(x: base.x + dir * 28 + wag, y: base.y + 16))
        p.lineCapStyle = .round
        p.lineWidth = 9; species.outline.setStroke(); p.stroke()
        p.lineWidth = 5; species.fur.setStroke(); p.stroke()
    }

    private func drawCatEars(_ body: NSRect) {
        let a = body.width / 2, b = body.height / 2
        func pt(_ u: CGFloat) -> NSPoint {
            NSPoint(x: body.midX + u * a, y: body.midY + b * sqrt(max(0, 1 - u * u)) - 3)
        }
        for side in [CGFloat(-1), 1] {
            let p1 = pt(side * 0.88), p2 = pt(side * 0.32)
            let apex = NSPoint(x: body.midX + side * a * 0.7, y: body.maxY + 15)
            let tri = NSBezierPath()
            tri.move(to: p1); tri.line(to: apex); tri.line(to: p2); tri.close()
            tri.lineJoinStyle = .round
            species.fur.setFill(); tri.fill()
            species.outline.setStroke(); tri.lineWidth = 2.5; tri.stroke()

            let cx = (p1.x + p2.x + apex.x) / 3, cy = (p1.y + p2.y + apex.y) / 3
            func shrink(_ p: NSPoint) -> NSPoint { NSPoint(x: cx + (p.x - cx) * 0.5, y: cy + (p.y - cy) * 0.5) }
            let inner = NSBezierPath()
            inner.move(to: shrink(p1)); inner.line(to: shrink(apex)); inner.line(to: shrink(p2)); inner.close()
            species.accent.setFill(); inner.fill()
        }
    }

    private func drawBunnyTail(_ body: NSRect) {
        let dir = -facing
        let r = NSRect(x: body.midX + dir * (body.width / 2 - 2) - 7, y: body.minY + 4, width: 14, height: 14)
        let p = NSBezierPath(ovalIn: r)
        species.fur.setFill(); p.fill()
        species.outline.setStroke(); p.lineWidth = 2; p.stroke()
    }

    private func drawBunnyEars(_ ctx: CGContext, _ body: NSRect) {
        for u in [CGFloat(-0.42), 0.42] {
            let outward: CGFloat = u < 0 ? 1 : -1       // CCW is positive rotation: left ear leans left
            var rot = outward * 0.12
            switch mood {
            case .walk, .chase: rot += facing * 0.3 + sin(time * 10 + u) * 0.08
            case .sleep:        rot = outward * 1.15
            case .happy:        rot += sin(time * 9) * 0.12
            case .held:         rot += outward * 0.4
            default:            rot += sin(time * 1.5 + u * 3) * 0.03
            }
            let base = NSPoint(x: body.midX + u * body.width / 2, y: body.maxY - 5)
            ctx.saveGState()
            ctx.translateBy(x: base.x, y: base.y)
            ctx.rotate(by: rot)
            let ear = NSBezierPath(ovalIn: NSRect(x: -7, y: 0, width: 14, height: 38))
            species.fur.setFill(); ear.fill()
            species.outline.setStroke(); ear.lineWidth = 2.5; ear.stroke()
            species.accent.setFill()
            NSBezierPath(ovalIn: NSRect(x: -3.5, y: 6, width: 7, height: 24)).fill()
            ctx.restoreGState()
        }
    }

    // MARK: Face

    private func drawFace(_ body: NSRect) {
        let sp = species
        let ink = sp.ink
        let eyeY = body.minY + body.height * 0.55
        let spread: CGFloat = sp == .cat ? 10.5 : (sp == .bunny ? 9.5 : 11)
        let fx = body.midX + facing * (sp == .mochi ? 7 : 6)
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

        // Nose / mouth, per species
        let open = mood == .happy || mood == .held || mood == .stretch || mood == .dance
        switch sp {
        case .mochi:
            if open {
                ink.setFill()
                NSBezierPath(ovalIn: NSRect(x: fx - 3, y: eyeY - 17, width: 6, height: 7)).fill()
            } else {
                arc(NSPoint(x: fx, y: eyeY - 9), 3, 200, 340)
            }
        case .cat:
            NSColor(calibratedRed: 1, green: 0.55, blue: 0.6, alpha: 1).setFill()
            let nose = NSBezierPath()
            nose.move(to: NSPoint(x: fx - 2.8, y: eyeY - 6)); nose.line(to: NSPoint(x: fx + 2.8, y: eyeY - 6))
            nose.line(to: NSPoint(x: fx, y: eyeY - 9.5)); nose.close(); nose.fill()
            ink.setStroke(); ink.setFill()
            arc(NSPoint(x: fx - 2.6, y: eyeY - 11), 2.6, 200, 340)
            arc(NSPoint(x: fx + 2.6, y: eyeY - 11), 2.6, 200, 340)
            if open { NSBezierPath(ovalIn: NSRect(x: fx - 3, y: eyeY - 18, width: 6, height: 6)).fill() }
            // whiskers
            NSColor(calibratedRed: 0.45, green: 0.3, blue: 0.2, alpha: 0.7).setStroke()
            for side in [CGFloat(-1), 1] {
                for k in 0..<3 {
                    let p = NSBezierPath()
                    p.move(to: NSPoint(x: fx + side * 15, y: eyeY - 8 + CGFloat(k - 1) * 3.5))
                    p.line(to: NSPoint(x: fx + side * 27, y: eyeY - 8 + CGFloat(k - 1) * 6.5))
                    p.lineWidth = 1.2; p.lineCapStyle = .round; p.stroke()
                }
            }
            // forehead stripes
            NSColor(calibratedRed: 0.85, green: 0.5, blue: 0.2, alpha: 0.9).setStroke()
            for (i, dx) in [CGFloat(-5), 0, 5].enumerated() {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: fx + dx, y: body.maxY - 3))
                p.line(to: NSPoint(x: fx + dx, y: body.maxY - (i == 1 ? 11 : 8)))
                p.lineWidth = 2; p.lineCapStyle = .round; p.stroke()
            }
        case .bunny:
            sp.accent.setFill()
            NSBezierPath(ovalIn: NSRect(x: fx - 2.6, y: eyeY - 9, width: 5.2, height: 4)).fill()
            ink.setStroke(); ink.setFill()
            arc(NSPoint(x: fx - 2.4, y: eyeY - 11), 2.4, 200, 340)
            arc(NSPoint(x: fx + 2.4, y: eyeY - 11), 2.4, 200, 340)
            // little teeth
            NSColor.white.setFill()
            for dx in [CGFloat(-2.4), 0.2] {
                let tooth = NSBezierPath(roundedRect: NSRect(x: fx + dx, y: eyeY - 17, width: 2.4, height: 4), xRadius: 0.8, yRadius: 0.8)
                tooth.fill()
                ink.setStroke(); tooth.lineWidth = 0.8; tooth.stroke()
            }
        }
    }

    private func arc(_ center: NSPoint, _ radius: CGFloat, _ start: CGFloat, _ end: CGFloat) {
        let p = NSBezierPath()
        p.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
        p.lineWidth = 2
        p.lineCapStyle = .round
        p.stroke()
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
