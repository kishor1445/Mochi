import AppKit

enum Mood { case idle, walk, sleep, happy, chase, held, jump, dance, stretch, dizzy, sad, power }

struct Heart {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var age: CGFloat      // negative = waiting to appear
}

/// Draws the pet with Core Graphics (no image assets) and forwards mouse input.
final class PetView: NSView {
    /// The pet is drawn on a 120pt design canvas and scaled to whatever size the view is.
    static let side: CGFloat = 120
    static let size = NSSize(width: side, height: side)
    private static let canvas = NSRect(origin: .zero, size: size)

    var species: Species = .mochi
    var mood: Mood = .idle
    var facing: CGFloat = 1              // local: +1 = looking right
    var time: CGFloat = 0
    var angle: CGFloat = 0               // radians; rotates the pet onto walls / ceiling
    var spin: CGFloat = 0                // extra twirl / wobble around the pet's own centre
    var gaze: CGPoint = .zero            // where the eyes look (local coordinates)
    var musicBpm: CGFloat = 0            // > 0 while music plays: headphones + bobbing to the beat
    var outfit: Outfit = .none           // what the pet is wearing
    var sweat = false                    // the Mac is working hard
    var shiver = false                   // the battery is nearly empty
    var hop: CGFloat = 0                 // extra height off the ground (backflips)
    var tap: CGFloat = 0                 // 1 right after a key press, fades fast: a little bop while you type
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
        tap = max(0, tap - dt * 7)
        for i in hearts.indices {
            hearts[i].age += dt
            if hearts[i].age > 0 { hearts[i].y += 36 * dt }
        }
        hearts.removeAll { $0.age > 1.1 }
    }

    func spawnHearts(_ n: Int) {
        for i in 0..<n {
            hearts.append(Heart(x: Self.canvas.midX + .random(in: -24...24), y: 70 + .random(in: 0...10),
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
        guard window?.isVisible == true, window?.occlusionState.contains(.visible) == true else { return }
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
        ctx.scaleBy(x: bounds.width / Self.side, y: bounds.height / Self.side)
        ctx.saveGState()
        if shiver, mood != .sleep { ctx.translateBy(x: sin(time * 46) * 1.1, y: 0) }
        ctx.translateBy(x: Self.canvas.midX, y: Self.canvas.midY)
        ctx.rotate(by: angle)
        ctx.translateBy(x: -Self.canvas.midX, y: -Self.canvas.midY)
        if spin != 0 {
            ctx.translateBy(x: Self.canvas.midX, y: 36)
            ctx.rotate(by: spin)
            ctx.translateBy(x: -Self.canvas.midX, y: -36)
        }
        var sway: CGFloat = 0
        if mood == .dance { sway = sin(time * 8) * 0.14 }
        else if species == .penguin && (mood == .walk || mood == .chase) { sway = sin(time * 10) * 0.12 }
        if sway != 0 {
            ctx.translateBy(x: Self.canvas.midX, y: 8)
            ctx.rotate(by: sway)
            ctx.translateBy(x: -Self.canvas.midX, y: -8)
        }
        drawPet(ctx)
        ctx.restoreGState()
        drawHearts()
        ctx.restoreGState()
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
        case .sad:   squash = 0.94 + 0.015 * sin(t * 1.5)    // slumped
        case .power: squash = 1.08 + 0.03 * sin(t * 22)      // puffed up and trembling with effort
        case .idle:  break
        }
        // Bob to the beat while music plays.
        if musicBpm > 0, mood == .idle || mood == .walk || mood == .chase {
            let beat = abs(sin(t * .pi * musicBpm / 60))
            lift += beat * 4
            squash -= beat * 0.04
        }
        // A quick bop for every key you press.
        if tap > 0, mood == .idle || mood == .walk || mood == .sad {
            lift += tap * 3.5
            squash -= tap * 0.045
        }
        lift += hop
        // Ghosts float.
        let hover: CGFloat = sp == .ghost ? (mood == .sleep ? 1 : 7 + sin(t * 3) * 2.5) : 0

        let baseW: CGFloat, baseH: CGFloat
        switch sp {
        case .mochi: baseW = 80; baseH = 58
        case .cat: baseW = 76; baseH = 57
        case .bunny: baseW = 68; baseH = 58
        case .penguin: baseW = 70; baseH = 68
        case .ghost: baseW = 68; baseH = 66
        case .dino: baseW = 76; baseH = 62
        case .robot: baseW = 70; baseH = 60
        case .dragon: baseW = 74; baseH = 60
        }
        let h = baseH * squash
        let w = baseW * (2 - squash)
        let body = NSRect(x: Self.canvas.midX - w / 2, y: 8 + lift + hover, width: w, height: h)

        // Shadow
        let ss = max(0.35, 1 - (lift + hover) / 60)
        NSColor.black.withAlphaComponent(0.16).setFill()
        NSBezierPath(ovalIn: NSRect(x: Self.canvas.midX - 31 * ss, y: 4, width: 62 * ss, height: 8)).fill()

        // Behind the body
        switch sp {
        case .mochi: drawSprout(ctx, body)
        case .cat: drawCatTail(body); drawCatEars(body)
        case .bunny: drawBunnyTail(body); drawBunnyEars(ctx, body)
        case .penguin: drawPenguinTuft(body); drawFlippers(ctx, body)
        case .ghost: drawGhostArms(ctx, body)
        case .dino: drawDinoTail(body); drawDinoSpikes(body)
        case .robot: drawRobotParts(body)
        case .dragon: drawDragonTail(body); drawDragonWings(body); drawDragonHorns(body)
        }

        // Body: flat colour, markings, soft shading, then the outline on top
        let path = bodyPath(body)
        sp.fur.setFill()
        path.fill()
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        if sp == .penguin { drawPenguinMarkings(body) }
        if sp == .cat || sp == .dino || sp == .dragon {
            // pale tummy
            (sp == .dino ? NSColor(calibratedRed: 0.90, green: 0.96, blue: 0.74, alpha: 1)
                         : NSColor(calibratedRed: 1, green: 0.93, blue: 0.82, alpha: 1)).setFill()
            let bw: CGFloat = sp == .cat ? 30 : 36
            NSBezierPath(ovalIn: NSRect(x: body.midX + facing * 2 - bw / 2, y: body.minY - 4, width: bw, height: h * (sp == .cat ? 0.36 : 0.42))).fill()
        }
        if sp == .robot { drawRobotPanel(body) }
        drawShading(body)
        NSGraphicsContext.restoreGraphicsState()
        sp.outline.setStroke()
        path.lineWidth = 2.5
        path.stroke()
        if sp != .ghost { drawFeet(body) }          // little paws peeking out in front
        if sp == .penguin { drawScarf(ctx, body) }
        if sp == .bunny { drawBow(ctx, body) }
        if sp == .dino { drawDinoArms(ctx, body) }

        drawFace(body)
        drawOutfit(ctx, body)
        if mood == .power { drawPower(body) }
        if sweat, mood != .sleep { drawSweat(body) }
        if musicBpm > 0 { drawHeadphones(body) }
        if mood == .sleep { drawZs(near: body) }
        if mood == .dance || (musicBpm > 0 && mood != .sleep) { drawNotes(near: body) }
    }

    /// A chubby gumdrop: full, flat-ish bottom and a slightly narrower round top.
    private func gumdrop(_ b: NSRect, belly: CGFloat, top: CGFloat) -> NSBezierPath {
        let w = b.width, h = b.height
        let my = b.minY + h * belly
        let p = NSBezierPath()
        p.move(to: NSPoint(x: b.midX, y: b.minY))
        p.curve(to: NSPoint(x: b.maxX, y: my),
                controlPoint1: NSPoint(x: b.midX + w * 0.36, y: b.minY),
                controlPoint2: NSPoint(x: b.maxX, y: b.minY + h * 0.08))
        p.curve(to: NSPoint(x: b.midX, y: b.maxY),
                controlPoint1: NSPoint(x: b.maxX, y: b.minY + h * 0.74),
                controlPoint2: NSPoint(x: b.midX + w * top, y: b.maxY))
        p.curve(to: NSPoint(x: b.minX, y: my),
                controlPoint1: NSPoint(x: b.midX - w * top, y: b.maxY),
                controlPoint2: NSPoint(x: b.minX, y: b.minY + h * 0.74))
        p.curve(to: NSPoint(x: b.midX, y: b.minY),
                controlPoint1: NSPoint(x: b.minX, y: b.minY + h * 0.08),
                controlPoint2: NSPoint(x: b.midX - w * 0.36, y: b.minY))
        p.close()
        return p
    }

    /// Soft shading inside the (already clipped) body: a tinted rim along the bottom and a little gloss.
    private func drawShading(_ body: NSRect) {
        let w = body.width, h = body.height
        let rim = NSBezierPath(rect: body.insetBy(dx: -4, dy: -4))
        rim.append(NSBezierPath(ovalIn: NSRect(x: body.minX - w * 0.10, y: body.minY + h * 0.13,
                                               width: w * 1.20, height: h * 1.1)))
        rim.windingRule = .evenOdd
        species.shade.setFill()
        rim.fill()

        if species == .cat || species == .penguin || species == .dino || species == .dragon || species == .robot {
            NSColor.white.withAlphaComponent(species == .penguin ? 0.22 : 0.45).setFill()
            let g = NSBezierPath(ovalIn: NSRect(x: -6, y: -3, width: 12, height: 6))
            var t = AffineTransform(translationByX: body.minX + w * 0.25, byY: body.maxY - h * 0.2)
            t.rotate(byRadians: 0.5)
            g.transform(using: t)
            g.fill()
        }
    }

    private func bodyPath(_ body: NSRect) -> NSBezierPath {
        switch species {
        case .mochi:
            return gumdrop(body, belly: 0.38, top: 0.30)
        case .cat, .bunny:
            return gumdrop(body, belly: 0.42, top: 0.29)
        case .penguin:
            return gumdrop(body, belly: 0.36, top: 0.26)
        case .dino, .dragon:
            return gumdrop(body, belly: 0.40, top: 0.30)
        case .robot:
            return NSBezierPath(roundedRect: body, xRadius: 18, yRadius: 18)
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
            let r = NSRect(x: body.midX + dx * body.width * 0.21 - wide / 2, y: body.minY - 3 + up, width: wide, height: 8.5)
            let p = NSBezierPath(ovalIn: r)
            species.foot.setFill(); p.fill()
            species.footOutline.setStroke(); p.lineWidth = 2; p.stroke()
        }
    }

    private func drawSprout(_ ctx: CGContext, _ body: NSRect) {
        let sway = sin(time * 3) * 0.08
        let green = NSColor(calibratedRed: 0.60, green: 0.86, blue: 0.52, alpha: 1)
        let dark = NSColor(calibratedRed: 0.30, green: 0.54, blue: 0.32, alpha: 1)
        ctx.saveGState()
        ctx.translateBy(x: body.midX + facing * 3, y: body.maxY - 4)
        // little stem
        let stem = NSBezierPath()
        stem.move(to: .zero); stem.line(to: NSPoint(x: 0, y: 7))
        stem.lineWidth = 3.5; stem.lineCapStyle = .round; dark.setStroke(); stem.stroke()
        ctx.translateBy(x: 0, y: 6)
        for (ang, len) in [(CGFloat(0.85), CGFloat(17)), (-0.75, 14)] {
            ctx.saveGState()
            ctx.rotate(by: ang + sway)
            // a pointed leaf with a centre vein
            let leaf = NSBezierPath()
            leaf.move(to: .zero)
            leaf.curve(to: NSPoint(x: 0, y: len), controlPoint1: NSPoint(x: 7, y: len * 0.25), controlPoint2: NSPoint(x: 5.5, y: len * 0.8))
            leaf.curve(to: .zero, controlPoint1: NSPoint(x: -5.5, y: len * 0.8), controlPoint2: NSPoint(x: -7, y: len * 0.25))
            leaf.lineJoinStyle = .round
            green.setFill(); leaf.fill()
            dark.setStroke(); leaf.lineWidth = 1.8; leaf.stroke()
            let vein = NSBezierPath()
            vein.move(to: NSPoint(x: 0, y: 3)); vein.line(to: NSPoint(x: 0, y: len - 5))
            vein.lineWidth = 1; vein.lineCapStyle = .round
            dark.withAlphaComponent(0.6).setStroke(); vein.stroke()
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    private func drawCatTail(_ body: NSRect) {
        let dir = -facing
        let base = NSPoint(x: body.midX + dir * (body.width / 2 - 8), y: body.minY + body.height * 0.28)
        let active = mood == .walk || mood == .chase
        let wag = sin(time * (active ? 9 : 3)) * (mood == .sad ? 2 : 9)
        let end = NSPoint(x: base.x + dir * 19 + wag, y: base.y + (mood == .sad ? 14 : 32))
        let c2 = NSPoint(x: base.x + dir * 29 + wag, y: base.y + 17)
        let p = NSBezierPath()
        p.move(to: base)
        p.curve(to: end, controlPoint1: NSPoint(x: base.x + dir * 25, y: base.y + 1), controlPoint2: c2)
        p.lineCapStyle = .round
        p.lineWidth = 11; species.outline.setStroke(); p.stroke()
        p.lineWidth = 6.5; species.fur.setStroke(); p.stroke()
        // cream tip
        let tip = NSBezierPath()
        tip.move(to: NSPoint(x: end.x + (c2.x - end.x) * 0.22, y: end.y + (c2.y - end.y) * 0.22))
        tip.line(to: end)
        tip.lineCapStyle = .round
        tip.lineWidth = 6.5
        NSColor(calibratedRed: 1, green: 0.93, blue: 0.82, alpha: 1).setStroke(); tip.stroke()
    }

    private func drawCatEars(_ body: NSRect) {
        let a = body.width / 2
        let droop: CGFloat = mood == .sad ? 5 : 0
        for side in [CGFloat(-1), 1] {
            let p1 = NSPoint(x: body.midX + side * a * 0.93, y: body.minY + body.height * 0.60)
            let p2 = NSPoint(x: body.midX + side * a * 0.16, y: body.maxY - 5)
            let apex = NSPoint(x: body.midX + side * (a * 0.80 + droop), y: body.maxY + 15 - droop)
            func ear(_ p1: NSPoint, _ apex: NSPoint, _ p2: NSPoint) -> NSBezierPath {
                // slightly bowed sides and a rounded tip
                let e = NSBezierPath()
                e.move(to: p1)
                e.curve(to: apex, controlPoint1: NSPoint(x: p1.x + side * 3, y: p1.y + (apex.y - p1.y) * 0.5),
                        controlPoint2: NSPoint(x: apex.x + side * 2, y: apex.y - 4))
                e.curve(to: p2, controlPoint1: NSPoint(x: apex.x - side * 5, y: apex.y - 1),
                        controlPoint2: NSPoint(x: p2.x + side * 6, y: p2.y + 8))
                e.close()
                e.lineJoinStyle = .round
                return e
            }
            let outer = ear(p1, apex, p2)
            species.fur.setFill(); outer.fill()
            species.outline.setStroke(); outer.lineWidth = 2.5; outer.stroke()

            let cx = (p1.x + p2.x + apex.x) / 3, cy = (p1.y + p2.y + apex.y) / 3
            func shrink(_ p: NSPoint) -> NSPoint { NSPoint(x: cx + (p.x - cx) * 0.52, y: cy + (p.y - cy) * 0.52) }
            species.accent.setFill()
            ear(shrink(p1), shrink(apex), shrink(p2)).fill()
        }
    }

    private func drawBunnyTail(_ body: NSRect) {
        let dir = -facing
        let c = NSPoint(x: body.midX + dir * (body.width / 2 - 1), y: body.minY + 12)
        // a fluffy pom-pom made of three puffs
        for (dx, dy, r) in [(CGFloat(0), CGFloat(0), CGFloat(8)), (4, 5, 5.5), (4, -4, 5.5)] {
            let p = NSBezierPath(ovalIn: NSRect(x: c.x + dir * dx - r, y: c.y + dy - r, width: r * 2, height: r * 2))
            species.outline.setStroke(); p.lineWidth = 4; p.stroke()
        }
        species.fur.setFill()
        for (dx, dy, r) in [(CGFloat(0), CGFloat(0), CGFloat(8)), (4, 5, 5.5), (4, -4, 5.5)] {
            NSBezierPath(ovalIn: NSRect(x: c.x + dir * dx - r, y: c.y + dy - r, width: r * 2, height: r * 2)).fill()
        }
    }

    private func drawBunnyEars(_ ctx: CGContext, _ body: NSRect) {
        for u in [CGFloat(-0.40), 0.40] {
            let outward: CGFloat = u < 0 ? 1 : -1       // CCW is positive rotation: left ear leans left
            var rot = outward * 0.14
            switch mood {
            case .walk, .chase: rot += facing * 0.3 + sin(time * 10 + u) * 0.08
            case .sleep:        rot = outward * 1.15
            case .happy, .dance: rot += sin(time * 9) * 0.12
            case .held:         rot += outward * 0.4
            case .dizzy:        rot += sin(time * 12 + u) * 0.25
            case .sad:          rot = outward * 0.8
            default:            rot += sin(time * 1.5 + u * 3) * 0.03
            }
            let base = NSPoint(x: body.midX + u * body.width / 2, y: body.maxY - 9)
            ctx.saveGState()
            ctx.translateBy(x: base.x, y: base.y)
            ctx.rotate(by: rot)
            // teardrop: narrow at the head, round and wide near the tip
            func ear(_ wdt: CGFloat, _ len: CGFloat, _ y0: CGFloat) -> NSBezierPath {
                let e = NSBezierPath()
                e.move(to: NSPoint(x: 0, y: y0))
                e.curve(to: NSPoint(x: 0, y: len), controlPoint1: NSPoint(x: wdt * 0.55, y: y0 + (len - y0) * 0.2),
                        controlPoint2: NSPoint(x: wdt * 1.15, y: len))
                e.curve(to: NSPoint(x: 0, y: y0), controlPoint1: NSPoint(x: -wdt * 1.15, y: len),
                        controlPoint2: NSPoint(x: -wdt * 0.55, y: y0 + (len - y0) * 0.2))
                e.close()
                return e
            }
            let outer = ear(9, 42, 0)
            species.fur.setFill(); outer.fill()
            species.outline.setStroke(); outer.lineWidth = 2.5; outer.stroke()
            species.accent.setFill()
            ear(4.6, 35, 10).fill()
            ctx.restoreGState()
        }
    }

    /// A little pink bow by the bunny's ear.
    private func drawBow(_ ctx: CGContext, _ body: NSRect) {
        let pink = NSColor(calibratedRed: 1.00, green: 0.56, blue: 0.70, alpha: 1)
        let line = NSColor(calibratedRed: 0.72, green: 0.30, blue: 0.45, alpha: 1)
        ctx.saveGState()
        ctx.translateBy(x: body.midX + facing * body.width * 0.27, y: body.maxY - 5)
        ctx.rotate(by: -facing * 0.3)
        for side in [CGFloat(-1), 1] {
            let wing = NSBezierPath()
            wing.move(to: .zero)
            wing.curve(to: NSPoint(x: side * 10, y: 0), controlPoint1: NSPoint(x: side * 4, y: 8), controlPoint2: NSPoint(x: side * 11, y: 8))
            wing.curve(to: .zero, controlPoint1: NSPoint(x: side * 11, y: -8), controlPoint2: NSPoint(x: side * 4, y: -8))
            wing.lineJoinStyle = .round
            pink.setFill(); wing.fill()
            line.setStroke(); wing.lineWidth = 1.5; wing.stroke()
        }
        let knot = NSBezierPath(ovalIn: NSRect(x: -3, y: -3, width: 6, height: 6))
        pink.setFill(); knot.fill()
        line.setStroke(); knot.lineWidth = 1.5; knot.stroke()
        ctx.restoreGState()
    }

    /// Three wispy feathers on top of the penguin's head.
    private func drawPenguinTuft(_ body: NSRect) {
        let base = NSPoint(x: body.midX + facing * 2, y: body.maxY - 3)
        let wob = sin(time * 3) * 0.06
        for a in [CGFloat(-0.55), 0, 0.55] {
            let ang = a + wob + .pi / 2
            let len: CGFloat = a == 0 ? 11 : 8
            let tip = NSPoint(x: base.x + cos(ang) * len, y: base.y + sin(ang) * len)
            let p = NSBezierPath()
            p.move(to: base); p.line(to: tip)
            p.lineCapStyle = .round
            p.lineWidth = 6.5; species.outline.setStroke(); p.stroke()
            p.lineWidth = 2.5; species.fur.setStroke(); p.stroke()
        }
    }

    // MARK: Rex the dino

    private func drawDinoTail(_ body: NSRect) {
        let dir = -facing
        let base = NSPoint(x: body.midX + dir * (body.width / 2 - 8), y: body.minY + body.height * 0.24)
        let wag = sin(time * (mood == .walk || mood == .chase ? 9 : 2.5)) * 4
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: base.x, y: base.y + 13))
        tail.curve(to: NSPoint(x: base.x + dir * 27, y: base.y + 6 + wag),
                   controlPoint1: NSPoint(x: base.x + dir * 12, y: base.y + 14), controlPoint2: NSPoint(x: base.x + dir * 22, y: base.y + 11 + wag))
        tail.curve(to: NSPoint(x: base.x, y: base.y - 8),
                   controlPoint1: NSPoint(x: base.x + dir * 20, y: base.y - 3 + wag), controlPoint2: NSPoint(x: base.x + dir * 10, y: base.y - 8))
        tail.close(); tail.lineJoinStyle = .round
        species.fur.setFill(); tail.fill()
        species.outline.setStroke(); tail.lineWidth = 2.5; tail.stroke()
    }

    /// A row of orange plates along the head and back.
    private func drawDinoSpikes(_ body: NSRect) {
        let a = body.width / 2, cy = body.minY + body.height * 0.40, b = body.height * 0.60
        for k in [CGFloat(-0.12), 0.20, 0.50, 0.76] {
            let x = body.midX - facing * k * a
            let y = cy + b * sqrt(max(0, 1 - k * k)) - 4
            let lean = -facing * k * 7
            let spike = NSBezierPath()
            spike.move(to: NSPoint(x: x - 7, y: y))
            spike.curve(to: NSPoint(x: x + 7, y: y), controlPoint1: NSPoint(x: x - 3 + lean, y: y + 15), controlPoint2: NSPoint(x: x + 3 + lean, y: y + 15))
            spike.close(); spike.lineJoinStyle = .round
            NSColor(calibratedRed: 1.00, green: 0.68, blue: 0.30, alpha: 1).setFill(); spike.fill()
            NSColor(calibratedRed: 0.72, green: 0.40, blue: 0.12, alpha: 1).setStroke(); spike.lineWidth = 2; spike.stroke()
        }
    }

    /// Famously tiny arms.
    private func drawDinoArms(_ ctx: CGContext, _ body: NSRect) {
        let excited = mood == .happy || mood == .dance || mood == .power || mood == .held
        for (i, off) in [CGFloat(0.30), 0.44].enumerated() {
            let wave = excited ? sin(time * 16 + CGFloat(i) * 2) * 0.5 : sin(time * 2 + CGFloat(i)) * 0.08
            ctx.saveGState()
            ctx.translateBy(x: body.midX + facing * body.width * off, y: body.minY + body.height * 0.24)
            ctx.rotate(by: facing * (0.9 + wave))
            let arm = NSBezierPath(roundedRect: NSRect(x: -2.5, y: -8, width: 5, height: 9), xRadius: 2.5, yRadius: 2.5)
            species.fur.setFill(); arm.fill()
            species.outline.setStroke(); arm.lineWidth = 1.8; arm.stroke()
            ctx.restoreGState()
        }
    }

    // MARK: Bolt the robot

    /// Antenna and ear bolts, behind the body.
    private func drawRobotParts(_ body: NSRect) {
        let metal = NSColor(calibratedRed: 0.62, green: 0.70, blue: 0.82, alpha: 1)
        let wob = sin(time * 3) * 1.5
        let rod = NSBezierPath()
        rod.move(to: NSPoint(x: body.midX, y: body.maxY - 3))
        rod.line(to: NSPoint(x: body.midX + wob, y: body.maxY + 11))
        rod.lineCapStyle = .round
        rod.lineWidth = 5; species.outline.setStroke(); rod.stroke()
        rod.lineWidth = 2; metal.setStroke(); rod.stroke()
        // the light blinks, and glows steady when it's excited
        let on = mood == .happy || mood == .dance || mood == .power || fmod(time, 1.4) < 0.7
        let bulb = NSBezierPath(ovalIn: NSRect(x: body.midX + wob - 5, y: body.maxY + 8, width: 10, height: 10))
        (on ? NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.48, alpha: 1) : NSColor(calibratedRed: 0.60, green: 0.30, blue: 0.36, alpha: 1)).setFill()
        bulb.fill()
        species.outline.setStroke(); bulb.lineWidth = 2; bulb.stroke()

        for side in [CGFloat(-1), 1] {
            let ear = NSBezierPath(roundedRect: NSRect(x: body.midX + side * (body.width / 2 + 1) - 5, y: body.minY + body.height * 0.42,
                                                       width: 10, height: 16), xRadius: 4, yRadius: 4)
            metal.setFill(); ear.fill()
            species.outline.setStroke(); ear.lineWidth = 2.2; ear.stroke()
        }
    }

    /// Three little status lights on the tummy.
    private func drawRobotPanel(_ body: NSRect) {
        let colors = [NSColor.systemRed, NSColor.systemYellow, NSColor.systemGreen]
        for (i, c) in colors.enumerated() {
            let lit = Int(time * 2.5) % 3 == i || mood == .power
            c.withAlphaComponent(lit ? 1 : 0.35).setFill()
            NSBezierPath(ovalIn: NSRect(x: body.midX + facing * 2 + CGFloat(i - 1) * 8 - 2.5, y: body.minY + 6, width: 5, height: 5)).fill()
        }
    }

    // MARK: Ember the dragon

    private func drawDragonTail(_ body: NSRect) {
        let dir = -facing
        let base = NSPoint(x: body.midX + dir * (body.width / 2 - 8), y: body.minY + body.height * 0.26)
        let wag = sin(time * (mood == .walk || mood == .chase ? 9 : 3)) * 6
        let end = NSPoint(x: base.x + dir * 22 + wag, y: base.y + 24)
        let p = NSBezierPath()
        p.move(to: base)
        p.curve(to: end, controlPoint1: NSPoint(x: base.x + dir * 24, y: base.y), controlPoint2: NSPoint(x: base.x + dir * 28 + wag, y: base.y + 13))
        p.lineCapStyle = .round
        p.lineWidth = 10; species.outline.setStroke(); p.stroke()
        p.lineWidth = 5.5; species.fur.setStroke(); p.stroke()
        // a little flame at the tip
        let flick = sin(time * 12) * 1.5
        let flame = NSBezierPath()
        flame.move(to: NSPoint(x: end.x - 6, y: end.y))
        flame.curve(to: NSPoint(x: end.x + flick, y: end.y + 15), controlPoint1: NSPoint(x: end.x - 7, y: end.y + 7), controlPoint2: NSPoint(x: end.x - 2, y: end.y + 9))
        flame.curve(to: NSPoint(x: end.x + 6, y: end.y), controlPoint1: NSPoint(x: end.x + 3, y: end.y + 9), controlPoint2: NSPoint(x: end.x + 7, y: end.y + 7))
        flame.curve(to: NSPoint(x: end.x - 6, y: end.y), controlPoint1: NSPoint(x: end.x + 5, y: end.y - 6), controlPoint2: NSPoint(x: end.x - 5, y: end.y - 6))
        flame.lineJoinStyle = .round
        NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.26, alpha: 1).setFill(); flame.fill()
        NSColor(calibratedRed: 0.86, green: 0.40, blue: 0.10, alpha: 1).setStroke(); flame.lineWidth = 1.8; flame.stroke()
    }

    private func drawDragonWings(_ body: NSRect) {
        let active = mood == .walk || mood == .chase || mood == .happy || mood == .jump || mood == .held || mood == .power
        let flap = mood == .sleep ? -5 : sin(time * (active ? 15 : 3.5)) * (active ? 7 : 3)
        for side in [CGFloat(-1), 1] {
            let o = NSPoint(x: body.midX + side * (body.width / 2 - 6), y: body.minY + body.height * 0.52)
            let wing = NSBezierPath()
            wing.move(to: o)
            wing.line(to: NSPoint(x: o.x + side * 19, y: o.y + 13 + flap))
            wing.curve(to: NSPoint(x: o.x + side * 17, y: o.y + 2 + flap * 0.5), controlPoint1: NSPoint(x: o.x + side * 18, y: o.y + 10 + flap), controlPoint2: NSPoint(x: o.x + side * 16, y: o.y + 6 + flap * 0.5))
            wing.curve(to: NSPoint(x: o.x + side * 11, y: o.y - 7), controlPoint1: NSPoint(x: o.x + side * 16, y: o.y - 2), controlPoint2: NSPoint(x: o.x + side * 13, y: o.y - 4))
            wing.curve(to: NSPoint(x: o.x, y: o.y - 9), controlPoint1: NSPoint(x: o.x + side * 8, y: o.y - 6), controlPoint2: NSPoint(x: o.x + side * 4, y: o.y - 6))
            wing.close(); wing.lineJoinStyle = .round
            NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.46, alpha: 1).setFill(); wing.fill()
            species.outline.setStroke(); wing.lineWidth = 2.2; wing.stroke()
        }
    }

    private func drawDragonHorns(_ body: NSRect) {
        for side in [CGFloat(-1), 1] {
            let x = body.midX + side * body.width * 0.20, y = body.maxY - 7
            let horn = NSBezierPath()
            horn.move(to: NSPoint(x: x - 5, y: y))
            horn.curve(to: NSPoint(x: x + side * 6, y: y + 18), controlPoint1: NSPoint(x: x - 4, y: y + 8), controlPoint2: NSPoint(x: x + side * 1, y: y + 13))
            horn.curve(to: NSPoint(x: x + 5, y: y), controlPoint1: NSPoint(x: x + side * 5, y: y + 9), controlPoint2: NSPoint(x: x + 5, y: y + 5))
            horn.close(); horn.lineJoinStyle = .round
            NSColor(calibratedRed: 1.00, green: 0.94, blue: 0.82, alpha: 1).setFill(); horn.fill()
            species.outline.setStroke(); horn.lineWidth = 2; horn.stroke()
        }
    }

    // MARK: Power moves

    /// Where the mouth is, shared by the face and the effects that come out of it.
    private func eyeLine(_ body: NSRect) -> CGFloat {
        body.minY + body.height * (species == .ghost ? 0.60 : (species == .penguin ? 0.56 : 0.50))
    }

    private func drawPower(_ body: NSRect) {
        let fx = body.midX + facing * 5
        let mouth = NSPoint(x: fx + facing * 6, y: eyeLine(body) - 11)
        switch species {
        case .dragon:
            // a jet of fire, growing and fading as it leaves the mouth
            for i in 0..<5 {
                let ph = fmod(time * 2.4 + CGFloat(i) * 0.2, 1)
                let c = NSPoint(x: mouth.x + facing * (5 + ph * 34), y: mouth.y + sin(ph * 7 + CGFloat(i)) * 3)
                let r = 4.5 + ph * 8
                NSColor(calibratedRed: 1.00, green: 0.45, blue: 0.12, alpha: 1 - ph).setFill()
                NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)).fill()
                NSColor(calibratedRed: 1.00, green: 0.88, blue: 0.35, alpha: 1 - ph).setFill()
                NSBezierPath(ovalIn: NSRect(x: c.x - r * 0.5, y: c.y - r * 0.5, width: r, height: r)).fill()
            }
        case .robot:
            // crackling bolts of electricity
            NSColor(calibratedRed: 1.00, green: 0.86, blue: 0.25, alpha: 1).setStroke()
            for (i, a) in [CGFloat(0.5), 1.4, 2.5, -0.4].enumerated() where Int(time * 12 + CGFloat(i) * 1.7) % 2 == 0 {
                let c = NSPoint(x: body.midX + cos(a) * (body.width / 2 + 9), y: body.midY + sin(a) * (body.height / 2 + 9))
                let z = NSBezierPath()
                z.move(to: NSPoint(x: c.x - 3, y: c.y + 8)); z.line(to: NSPoint(x: c.x + 2, y: c.y + 1))
                z.line(to: NSPoint(x: c.x - 2, y: c.y - 1)); z.line(to: NSPoint(x: c.x + 3, y: c.y - 8))
                z.lineWidth = 2.4; z.lineJoinStyle = .round; z.lineCapStyle = .round; z.stroke()
            }
        case .dino, .ghost:
            // sound waves from a mighty roar (or a very loud "boo")
            for i in 0..<3 {
                let ph = fmod(time * 1.8 + CGFloat(i) / 3, 1)
                let wave = NSBezierPath()
                let mid: CGFloat = facing > 0 ? 0 : 180
                wave.appendArc(withCenter: mouth, radius: 9 + ph * 24, startAngle: mid - 38, endAngle: mid + 38)
                wave.lineWidth = 2.6; wave.lineCapStyle = .round
                species.outline.withAlphaComponent(1 - ph).setStroke(); wave.stroke()
            }
        default:
            // a burst of twinkling stars
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3 + time * 1.5
                let tw = 0.5 + 0.5 * sin(time * 9 + CGFloat(i) * 2)
                let c = NSPoint(x: body.midX + cos(a) * (body.width / 2 + 10), y: body.midY + sin(a) * (body.height / 2 + 8))
                let r = 2.5 + tw * 3.5
                let star = NSBezierPath()
                star.move(to: NSPoint(x: c.x, y: c.y + r))
                for (dx, dy) in [(CGFloat(0.28), CGFloat(0.28)), (1, 0), (0.28, -0.28), (0, -1), (-0.28, -0.28), (-1, 0), (-0.28, 0.28)] {
                    star.line(to: NSPoint(x: c.x + dx * r, y: c.y + dy * r))
                }
                star.close()
                NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.28, alpha: 0.5 + tw * 0.5).setFill(); star.fill()
            }
        }
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
            case .happy, .dance, .jump, .power: ang = side * (2.2 + sin(time * 14) * 0.35)
            case .stretch: ang = side * 2.6
            case .held: ang = side * (2.0 + sin(time * 20) * 0.4)
            case .sleep: ang = side * 0.12
            case .dizzy: ang = side * (1.0 + sin(time * 12) * 0.3)
            case .idle: ang += sin(time * 2 + side) * 0.04
            case .sad: ang = side * 0.1
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
        NSColor(calibratedRed: 0.99, green: 0.99, blue: 1.0, alpha: 1).setFill()
        let eyeY = body.minY + body.height * 0.56
        let fx = body.midX + facing * 5
        let r = body.width * 0.225
        // heart-shaped face: a round patch around each eye, joined to the belly
        for side in [CGFloat(-1), 1] {
            NSBezierPath(ovalIn: NSRect(x: fx + side * 10 - r, y: eyeY - 2 - r, width: r * 2, height: r * 2)).fill()
        }
        NSBezierPath(ovalIn: NSRect(x: body.midX + facing * 2 - body.width * 0.34, y: body.minY - body.height * 0.02,
                                    width: body.width * 0.68, height: body.height * 0.60)).fill()
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
        let eyeY = eyeLine(body)
        let spread: CGFloat
        switch sp {
        case .dino, .dragon: spread = 12.5
        case .robot: spread = 11.5
        case .mochi: spread = 13.5
        case .cat: spread = 12.5
        case .bunny: spread = 11.5
        case .penguin: spread = 10
        case .ghost: spread = 11.5
        }
        let fx = body.midX + facing * (sp == .mochi ? 6 : 5)
        let blinking = fmod(time + 1.3, 4.3) < 0.12
        let sad = mood == .sad
        let open = mood == .happy || mood == .held || mood == .stretch || mood == .dance || mood == .power
        let cream = NSColor(calibratedRed: 1, green: 0.93, blue: 0.82, alpha: 1)

        // Cat muzzle sits under everything else on the face
        if sp == .cat {
            cream.setFill()
            NSBezierPath(ovalIn: NSRect(x: fx - 13, y: eyeY - 17, width: 26, height: 15)).fill()
        }

        // Bolt's face is a little screen
        if sp == .robot {
            let screen = NSBezierPath(roundedRect: NSRect(x: fx - 25, y: eyeY - 16, width: 50, height: 29), xRadius: 10, yRadius: 10)
            NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.27, alpha: 1).setFill(); screen.fill()
            sp.outline.setStroke(); screen.lineWidth = 1.6; screen.stroke()
        }

        // Rosy cheeks
        sp.accent.withAlphaComponent(mood == .happy || mood == .dance ? 0.85 : 0.6).setFill()
        for dx in [CGFloat(-1), 1] {
            NSBezierPath(ovalIn: NSRect(x: fx + dx * (spread + 8) - 5.5, y: eyeY - 10.5, width: 11, height: 6.5)).fill()
        }

        // Eyes
        ink.setFill(); ink.setStroke()
        for dx in [CGFloat(-1), 1] {
            let ex = fx + dx * spread
            switch mood {
            case .sleep, .stretch:
                arc(NSPoint(x: ex, y: eyeY + 2), 4.6, 200, 340, width: 2.3)
            case .happy, .dance:
                arc(NSPoint(x: ex, y: eyeY - 2.5), 5, 15, 165, width: 2.5)
            case .dizzy:
                spiral(NSPoint(x: ex, y: eyeY), 6)
            case .power:
                // scrunched shut with effort:  >  <
                let squint = NSBezierPath()
                squint.move(to: NSPoint(x: ex - dx * 4.5, y: eyeY + 4.5))
                squint.line(to: NSPoint(x: ex + dx * 3, y: eyeY))
                squint.line(to: NSPoint(x: ex - dx * 4.5, y: eyeY - 4.5))
                squint.lineWidth = 2.5; squint.lineCapStyle = .round; squint.lineJoinStyle = .round; squint.stroke()
            default:
                let wide = mood == .held
                let ew: CGFloat = wide ? 9.5 : 8.4
                let eh: CGFloat = blinking ? 1.7 : (wide ? 12.5 : 11)
                let gx = wide ? 0 : (sad ? 0 : gaze.x), gy = wide ? 0 : (sad ? -1.5 : gaze.y)
                let r = NSRect(x: ex - ew / 2 + gx, y: eyeY - eh / 2 + gy, width: ew, height: eh)
                NSBezierPath(ovalIn: r).fill()
                if !blinking {
                    // two catchlights make the eyes sparkle
                    NSColor.white.setFill()
                    NSBezierPath(ovalIn: NSRect(x: r.midX - 0.6, y: r.midY + 0.6, width: 3.7, height: 3.7)).fill()
                    NSBezierPath(ovalIn: NSRect(x: r.midX - 3.1, y: r.midY - 4, width: 1.9, height: 1.9)).fill()
                    ink.setFill()
                }
                if sad {
                    // worried brows, higher towards the middle
                    let brow = NSBezierPath()
                    brow.move(to: NSPoint(x: ex - dx * 4.5, y: eyeY + 12))
                    brow.line(to: NSPoint(x: ex + dx * 5, y: eyeY + 8.5))
                    brow.lineWidth = 1.9; brow.lineCapStyle = .round; brow.stroke()
                }
            }
        }

        if outfit == .shades {
            let dark = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.14, alpha: 1)
            for dx in [CGFloat(-1), 1] {
                let lens = NSBezierPath(roundedRect: NSRect(x: fx + dx * spread - 8.5, y: eyeY - 6, width: 17, height: 12), xRadius: 4.5, yRadius: 4.5)
                dark.setFill(); lens.fill()
                NSColor.white.withAlphaComponent(0.55).setStroke()
                let shine = NSBezierPath()
                shine.move(to: NSPoint(x: fx + dx * spread - 4.5, y: eyeY + 3)); shine.line(to: NSPoint(x: fx + dx * spread - 1, y: eyeY + 3.6))
                shine.lineWidth = 1.5; shine.lineCapStyle = .round; shine.stroke()
            }
            let bar = NSBezierPath()
            bar.move(to: NSPoint(x: fx - spread + 6, y: eyeY + 3.5)); bar.line(to: NSPoint(x: fx + spread - 6, y: eyeY + 3.5))
            bar.lineWidth = 2.4; dark.setStroke(); bar.stroke()
        }
        if outfit == .glasses {
            let frame = NSColor(calibratedRed: 0.24, green: 0.20, blue: 0.30, alpha: 1)
            for dx in [CGFloat(-1), 1] {
                let lens = NSBezierPath(ovalIn: NSRect(x: fx + dx * spread - 8, y: eyeY - 8, width: 16, height: 16))
                NSColor.white.withAlphaComponent(0.18).setFill(); lens.fill()
                frame.setStroke(); lens.lineWidth = 1.7; lens.stroke()
            }
            let bridge = NSBezierPath()
            bridge.move(to: NSPoint(x: fx - spread + 8, y: eyeY + 1))
            bridge.curve(to: NSPoint(x: fx + spread - 8, y: eyeY + 1),
                         controlPoint1: NSPoint(x: fx - 2, y: eyeY + 3.5), controlPoint2: NSPoint(x: fx + 2, y: eyeY + 3.5))
            bridge.lineWidth = 1.7; frame.setStroke(); bridge.stroke()
        }

        // Mouth / beak, tucked in close under the eyes
        ink.setFill(); ink.setStroke()
        switch sp {
        case .mochi:
            if open { openMouth(NSPoint(x: fx, y: eyeY - 9.5), 7.5, 8) }
            else if sad { arc(NSPoint(x: fx, y: eyeY - 11.5), 3, 25, 155) }
            else { kittyMouth(NSPoint(x: fx, y: eyeY - 4.5), 2.5) }
        case .cat:
            if open { openMouth(NSPoint(x: fx, y: eyeY - 12.5), 7, 6.5) }
            else { kittyMouth(NSPoint(x: fx, y: eyeY - 8), 2.7) }
            // nose: a tiny rounded heart-ish triangle
            NSColor(calibratedRed: 1, green: 0.52, blue: 0.60, alpha: 1).setFill()
            let nose = NSBezierPath()
            nose.move(to: NSPoint(x: fx - 3, y: eyeY - 3.5)); nose.line(to: NSPoint(x: fx + 3, y: eyeY - 3.5))
            nose.line(to: NSPoint(x: fx, y: eyeY - 7)); nose.close()
            nose.lineJoinStyle = .round; nose.fill()
            NSColor(calibratedRed: 1, green: 0.52, blue: 0.60, alpha: 1).setStroke(); nose.lineWidth = 1.2; nose.stroke()
            // whiskers
            NSColor(calibratedRed: 0.45, green: 0.3, blue: 0.2, alpha: 0.65).setStroke()
            for side in [CGFloat(-1), 1] {
                for k in [CGFloat(-1), 1] {
                    let p = NSBezierPath()
                    p.move(to: NSPoint(x: fx + side * 19, y: eyeY - 9 + k * 1.8))
                    p.line(to: NSPoint(x: fx + side * 30, y: eyeY - 9 + k * 4.5))
                    p.lineWidth = 1.2; p.lineCapStyle = .round; p.stroke()
                }
            }
            // forehead stripes
            NSColor(calibratedRed: 0.86, green: 0.50, blue: 0.20, alpha: 0.9).setStroke()
            for (i, dx) in [CGFloat(-5.5), 0, 5.5].enumerated() {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: fx + dx, y: body.maxY - 3))
                p.line(to: NSPoint(x: fx + dx, y: body.maxY - (i == 1 ? 11 : 8)))
                p.lineWidth = 2.2; p.lineCapStyle = .round; p.stroke()
            }
        case .bunny:
            if open { openMouth(NSPoint(x: fx, y: eyeY - 12.5), 6.5, 6.5) }
            else {
                kittyMouth(NSPoint(x: fx, y: eyeY - 8), 2.5)
                // little teeth
                NSColor.white.setFill()
                let teeth = NSBezierPath(roundedRect: NSRect(x: fx - 2.5, y: eyeY - 14, width: 5, height: 4.2), xRadius: 1.2, yRadius: 1.2)
                teeth.fill()
                ink.setStroke(); teeth.lineWidth = 0.9; teeth.stroke()
                let gap = NSBezierPath()
                gap.move(to: NSPoint(x: fx, y: eyeY - 10)); gap.line(to: NSPoint(x: fx, y: eyeY - 13.6))
                gap.lineWidth = 0.8; gap.stroke()
            }
            sp.accent.blended(withFraction: 0.35, of: .systemPink)?.setFill()
            NSBezierPath(ovalIn: NSRect(x: fx - 3, y: eyeY - 7, width: 6, height: 4.4)).fill()
        case .penguin:
            if open { openMouth(NSPoint(x: fx, y: eyeY - 11), 7, 6) }
            // a small rounded beak
            let top = eyeY - (open ? 2 : 3)
            let beak = NSBezierPath()
            beak.move(to: NSPoint(x: fx - 5.5, y: top))
            beak.curve(to: NSPoint(x: fx + 5.5, y: top), controlPoint1: NSPoint(x: fx - 3, y: top + 3), controlPoint2: NSPoint(x: fx + 3, y: top + 3))
            beak.curve(to: NSPoint(x: fx, y: top - 6.5), controlPoint1: NSPoint(x: fx + 5, y: top - 3), controlPoint2: NSPoint(x: fx + 2.5, y: top - 6.5))
            beak.curve(to: NSPoint(x: fx - 5.5, y: top), controlPoint1: NSPoint(x: fx - 2.5, y: top - 6.5), controlPoint2: NSPoint(x: fx - 5, y: top - 3))
            beak.lineJoinStyle = .round
            sp.foot.setFill(); beak.fill()
            sp.footOutline.setStroke(); beak.lineWidth = 1.5; beak.stroke()
        case .ghost:
            if open { openMouth(NSPoint(x: fx, y: eyeY - 11), 8, 9) }
            else if sad { arc(NSPoint(x: fx, y: eyeY - 12.5), 3, 25, 155) }
            else { arc(NSPoint(x: fx, y: eyeY - 5.5), 3, 205, 335) }
        case .dino, .dragon:
            // nostrils, a wide grin and one little fang
            ink.withAlphaComponent(0.55).setFill()
            for dx in [CGFloat(-2.6), 2.6] {
                NSBezierPath(ovalIn: NSRect(x: fx + dx - 1, y: eyeY - 3.5, width: 2, height: 2.4)).fill()
            }
            ink.setFill(); ink.setStroke()
            if open { openMouth(NSPoint(x: fx, y: eyeY - 12.5), 10, 9) }
            else if sad { arc(NSPoint(x: fx, y: eyeY - 14), 4, 25, 155) }
            else {
                arc(NSPoint(x: fx, y: eyeY - 6.5), 5, 200, 340)
                let fang = NSBezierPath()
                fang.move(to: NSPoint(x: fx + 1.6, y: eyeY - 11)); fang.line(to: NSPoint(x: fx + 3.2, y: eyeY - 14.5)); fang.line(to: NSPoint(x: fx + 4.8, y: eyeY - 10.4))
                fang.close(); fang.lineJoinStyle = .round
                NSColor.white.setFill(); fang.fill()
                ink.setStroke(); fang.lineWidth = 0.9; fang.stroke()
            }
        case .robot:
            // an LED mouth on the screen
            if open {
                NSBezierPath(roundedRect: NSRect(x: fx - 4.5, y: eyeY - 12.5, width: 9, height: 5.5), xRadius: 2.5, yRadius: 2.5).fill()
            } else if sad { arc(NSPoint(x: fx, y: eyeY - 12.5), 3, 25, 155) }
            else { arc(NSPoint(x: fx, y: eyeY - 6.5), 3.4, 205, 335) }
        }
    }

    // MARK: Outfits

    /// Things worn on the head (glasses are drawn with the face, where the eye positions are known).
    private func drawOutfit(_ ctx: CGContext, _ body: NSRect) {
        let top = NSPoint(x: body.midX + facing * 2, y: body.maxY)
        let line = NSColor(calibratedRed: 0.36, green: 0.26, blue: 0.30, alpha: 1)
        switch outfit {
        case .none, .glasses, .shades:
            break

        case .cap:
            // a baseball cap with the brim pointing where the pet looks
            let blue = NSColor(calibratedRed: 0.26, green: 0.52, blue: 0.96, alpha: 1)
            let navy = NSColor(calibratedRed: 0.12, green: 0.24, blue: 0.56, alpha: 1)
            let y = body.maxY - 7
            let brim = NSBezierPath(roundedRect: NSRect(x: facing > 0 ? top.x + 2 : top.x - 26, y: y - 1, width: 24, height: 6), xRadius: 3, yRadius: 3)
            navy.setFill(); brim.fill()
            let dome = NSBezierPath()
            dome.move(to: NSPoint(x: top.x - 15, y: y))
            dome.curve(to: NSPoint(x: top.x + 15, y: y), controlPoint1: NSPoint(x: top.x - 14, y: y + 18), controlPoint2: NSPoint(x: top.x + 14, y: y + 18))
            dome.close(); dome.lineJoinStyle = .round
            blue.setFill(); dome.fill()
            navy.setStroke(); dome.lineWidth = 1.8; dome.stroke()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: top.x - 2, y: y + 12, width: 4, height: 4)).fill()

        case .headband:
            // a ninja headband, knotted at the back with two tails in the wind
            let red = NSColor(calibratedRed: 0.90, green: 0.22, blue: 0.26, alpha: 1)
            let dark = NSColor(calibratedRed: 0.55, green: 0.10, blue: 0.14, alpha: 1)
            let y = body.maxY - body.height * 0.20
            let back = NSPoint(x: body.midX - facing * (body.width / 2 - 5), y: y + 3)
            for (i, dy) in [CGFloat(5), -3].enumerated() {
                let flutter = sin(time * 7 + CGFloat(i) * 1.5) * 3
                let tail = NSBezierPath()
                tail.move(to: back)
                tail.curve(to: NSPoint(x: back.x - facing * 17, y: back.y + dy + flutter),
                           controlPoint1: NSPoint(x: back.x - facing * 6, y: back.y + dy), controlPoint2: NSPoint(x: back.x - facing * 11, y: back.y + dy - flutter))
                tail.lineCapStyle = .round
                tail.lineWidth = 6; dark.setStroke(); tail.stroke()
                tail.lineWidth = 3.4; red.setStroke(); tail.stroke()
            }
            NSGraphicsContext.saveGraphicsState()
            bodyPath(body).addClip()
            let band = NSBezierPath(rect: NSRect(x: body.minX - 2, y: y, width: body.width + 4, height: 7))
            red.setFill(); band.fill()
            dark.setStroke(); band.lineWidth = 1.6; band.stroke()
            NSGraphicsContext.restoreGraphicsState()

        case .flower:
            // tucked behind one ear, on the side away from where the pet is looking
            let c = NSPoint(x: body.midX - facing * body.width * 0.30, y: body.maxY - body.height * 0.13)
            let petal = NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.76, alpha: 1)
            for i in 0..<5 {
                let a = CGFloat(i) * 2 * .pi / 5 + .pi / 2
                let r = NSRect(x: c.x + cos(a) * 4.6 - 3.8, y: c.y + sin(a) * 4.6 - 3.8, width: 7.6, height: 7.6)
                let p = NSBezierPath(ovalIn: r)
                petal.setFill(); p.fill()
                NSColor(calibratedRed: 0.80, green: 0.36, blue: 0.52, alpha: 1).setStroke(); p.lineWidth = 1; p.stroke()
            }
            NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.30, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - 2.8, y: c.y - 2.8, width: 5.6, height: 5.6)).fill()

        case .partyHat:
            ctx.saveGState()
            ctx.translateBy(x: top.x, y: top.y - 4)
            ctx.rotate(by: -facing * 0.16)
            let cone = NSBezierPath()
            cone.move(to: NSPoint(x: -10, y: 0)); cone.line(to: NSPoint(x: 0, y: 23)); cone.line(to: NSPoint(x: 10, y: 0))
            cone.close(); cone.lineJoinStyle = .round
            NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.68, alpha: 1).setFill(); cone.fill()
            NSGraphicsContext.saveGraphicsState()
            cone.addClip()
            NSColor(calibratedRed: 1.00, green: 0.86, blue: 0.36, alpha: 1).setStroke()
            for y in [CGFloat(5), 12, 19] {
                let stripe = NSBezierPath()
                stripe.move(to: NSPoint(x: -12, y: y - 3)); stripe.line(to: NSPoint(x: 12, y: y + 2))
                stripe.lineWidth = 2.6; stripe.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
            line.setStroke(); cone.lineWidth = 1.8; cone.stroke()
            let pom = NSBezierPath(ovalIn: NSRect(x: -4, y: 20, width: 8, height: 8))
            NSColor.white.setFill(); pom.fill()
            line.setStroke(); pom.lineWidth = 1.5; pom.stroke()
            ctx.restoreGState()

        case .crown:
            ctx.saveGState()
            ctx.translateBy(x: top.x, y: top.y - 3)
            ctx.rotate(by: -facing * 0.08)
            let crown = NSBezierPath()
            crown.move(to: NSPoint(x: -12, y: 0))
            for (x, y) in [(CGFloat(-13), CGFloat(13)), (-6.5, 6), (0, 15), (6.5, 6), (13, 13), (12, 0)] {
                crown.line(to: NSPoint(x: x, y: y))
            }
            crown.close(); crown.lineJoinStyle = .round
            NSColor(calibratedRed: 1.00, green: 0.82, blue: 0.30, alpha: 1).setFill(); crown.fill()
            NSColor(calibratedRed: 0.74, green: 0.50, blue: 0.10, alpha: 1).setStroke(); crown.lineWidth = 1.8; crown.stroke()
            for (x, c) in [(CGFloat(-6.5), NSColor.systemTeal), (0, NSColor.systemPink), (6.5, NSColor.systemTeal)] {
                c.setFill()
                NSBezierPath(ovalIn: NSRect(x: x - 1.8, y: 1.6, width: 3.6, height: 3.6)).fill()
            }
            ctx.restoreGState()

        case .halo:
            let bob = sin(time * 2.2) * 1.5
            let ring = NSBezierPath(ovalIn: NSRect(x: top.x - 14, y: top.y + 7 + bob, width: 28, height: 8))
            ring.lineWidth = 4.5
            NSColor(calibratedRed: 0.80, green: 0.60, blue: 0.14, alpha: 0.9).setStroke(); ring.stroke()
            ring.lineWidth = 2.6
            NSColor(calibratedRed: 1.00, green: 0.90, blue: 0.45, alpha: 1).setStroke(); ring.stroke()
        }
    }

    /// Two drops of sweat sliding down the side of the head.
    private func drawSweat(_ body: NSRect) {
        for i in 0..<2 {
            let phase = fmod(time * 0.8 + CGFloat(i) * 0.5, 1)
            let x = body.maxX - 4 + CGFloat(i) * 5
            let y = body.maxY - 6 - phase * 16
            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: x, y: y + 6))
            drop.curve(to: NSPoint(x: x, y: y - 3), controlPoint1: NSPoint(x: x + 4.5, y: y), controlPoint2: NSPoint(x: x + 3, y: y - 3))
            drop.curve(to: NSPoint(x: x, y: y + 6), controlPoint1: NSPoint(x: x - 3, y: y - 3), controlPoint2: NSPoint(x: x - 4.5, y: y))
            NSColor(calibratedRed: 0.52, green: 0.78, blue: 1.0, alpha: 1 - phase).setFill(); drop.fill()
            NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1 - phase).setStroke(); drop.lineWidth = 1; drop.stroke()
        }
    }

    /// The classic "ω" mouth: two little arcs side by side.
    private func kittyMouth(_ c: NSPoint, _ r: CGFloat) {
        arc(NSPoint(x: c.x - r, y: c.y), r, 195, 345)
        arc(NSPoint(x: c.x + r, y: c.y), r, 195, 345)
    }

    /// An open, happy mouth with a pink tongue inside.
    private func openMouth(_ c: NSPoint, _ w: CGFloat, _ h: CGFloat) {
        let r = NSRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
        let m = NSBezierPath(ovalIn: r)
        species.ink.setFill(); m.fill()
        NSGraphicsContext.saveGraphicsState()
        m.addClip()
        NSColor(calibratedRed: 1, green: 0.50, blue: 0.56, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: r.minX + w * 0.1, y: r.minY - h * 0.45, width: w * 0.8, height: h * 0.9)).fill()
        NSGraphicsContext.restoreGraphicsState()
        species.ink.setFill()
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

    private func arc(_ center: NSPoint, _ radius: CGFloat, _ start: CGFloat, _ end: CGFloat, width: CGFloat = 2) {
        let p = NSBezierPath()
        p.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
        p.lineWidth = width
        p.lineCapStyle = .round
        p.stroke()
    }

    // MARK: Accessories & effects

    private func drawHeadphones(_ body: NSRect) {
        // The "head" is the whole body, except for the ghost where it is the dome.
        let isGhost = species == .ghost
        let a = body.width / 2 + 3
        // Gumdrop bodies are widest below the middle, so the band's ellipse is centred there.
        let b = (isGhost ? body.width / 2 : body.height * 0.58) + 2
        let c = NSPoint(x: body.midX, y: isGhost ? body.maxY - body.width / 2 : body.minY + body.height * 0.42)

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
