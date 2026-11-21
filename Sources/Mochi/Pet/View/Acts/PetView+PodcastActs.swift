import AppKit

/// Podcasts and audiobooks: earbud nodder, note-taker, coffee break, retro radio, deep thinker.
/// Calm acts: slow movements, nothing on the beat.
extension PetView {
    // MARK: Earbud nodder

    /// One earbud in, on the side facing us (the nod is `actLift`), and now and then three dots rising.
    func drawEarbud(_ body: NSRect) {
        let bud = NSPoint(x: body.midX - facing * (body.width / 2 - 1), y: body.minY + body.height * 0.68)
        let stem = roundRect(NSRect(x: bud.x - 2, y: bud.y - 11, width: 4, height: 11), 2)
        let head = NSBezierPath(ovalIn: NSRect(x: bud.x - 5, y: bud.y - 3.5, width: 10, height: 9))
        paint(stem, .white, rgb(0.3, 0.3, 0.3), 1.3)
        paint(head, .white, rgb(0.3, 0.3, 0.3), 1.3)
        paint(NSBezierPath(ovalIn: NSRect(x: bud.x - 1.8 + facing * 1.2, y: bud.y - 0.2, width: 3.6, height: 3.2)), rgb(0.25, 0.25, 0.25))
        drawThinkingDots(body)
    }

    /// Three dots rising, one after another: thinking it over.
    func drawThinkingDots(_ body: NSRect) {
        guard let shown = moment(every: 9, lasting: 3, offset: 3) else { return }
        for i in 0..<3 {
            let appear = CGFloat(i) * 0.15
            guard shown > appear else { continue }
            let alpha = min(1, (shown - appear) * 4) * (shown > 0.85 ? (1 - shown) / 0.15 : 1)
            let r: CGFloat = 1.8 + CGFloat(i) * 0.6
            paint(circle(NSPoint(x: body.midX + facing * (10 + CGFloat(i) * 6), y: body.maxY + 4 + CGFloat(i) * 5), r),
                  NSColor(calibratedWhite: 0.45, alpha: alpha))
        }
    }

    // MARK: Note-taker

    /// A little spiral notepad on the floor, a pencil scribbling away, and now and then a bright idea.
    func drawNotepad(_ body: NSRect) {
        let floor = groundY(body)
        let pad = NSPoint(x: body.midX + facing * 7, y: floor)
        var tip = NSPoint.zero
        local(pad, angle: 0.08) {
            let sheet = roundRect(NSRect(x: -11, y: 0, width: 22, height: 15), 1.5)
            paint(sheet, rgb(1, 0.99, 0.94), ink, 1.2)
            rgb(0.55, 0.75, 0.95).setStroke()
            for ly in stride(from: CGFloat(3), to: 12, by: 2.6) {
                let line = NSBezierPath(); line.move(to: NSPoint(x: -9, y: ly)); line.line(to: NSPoint(x: 9.5, y: ly)); line.lineWidth = 0.6; line.stroke()
            }
            rgb(0.95, 0.45, 0.45).setStroke()
            let margin = NSBezierPath(); margin.move(to: NSPoint(x: -7, y: 0.5)); margin.line(to: NSPoint(x: -7, y: 14)); margin.lineWidth = 0.6; margin.stroke()
            for rx in stride(from: CGFloat(-8), through: 8, by: 4) {
                paint(NSBezierPath(ovalIn: NSRect(x: rx - 1.1, y: 13.6, width: 2.2, height: 3)), nil, rgb(0.45, 0.45, 0.5), 0.9)
            }
            // The scribble so far: a wavy line that fills the page, then starts over.
            let progress = fmod(time, 6) / 6
            let row = min(2, Int(progress * 3))
            let rowY = 10.4 - CGFloat(row) * 2.6
            let along = fmod(progress * 3, 1)
            rgb(0.25, 0.25, 0.35).setStroke()
            for r in 0...row {
                let y = 10.4 - CGFloat(r) * 2.6 + 0.9
                let end = r < row ? 1 : along
                let s = NSBezierPath(); s.move(to: NSPoint(x: -6, y: y))
                var x: CGFloat = -6
                while x < -6 + 15 * end { x += 1; s.line(to: NSPoint(x: x, y: y + sin(x * 2.2) * 0.7)) }
                s.lineWidth = 0.7; s.stroke()
            }
            tip = NSPoint(x: -6 + 15 * along, y: rowY + 0.9)
        }
        // Pencil and paw, at the end of the scribble.
        let t = NSPoint(x: pad.x + facing * tip.x, y: pad.y + tip.y + (facing * tip.x) * 0.08)
        local(t, angle: 1.0) {
            paint(roundRect(NSRect(x: 2.5, y: -1.4, width: 12, height: 2.8), 0.6), rgb(1, 0.80, 0.25), ink, 0.9)
            paint(roundRect(NSRect(x: 14, y: -1.4, width: 3, height: 2.8), 0.8), rgb(1, 0.6, 0.65), ink, 0.9)
            let point = NSBezierPath(); point.move(to: NSPoint(x: 2.5, y: -1.4)); point.line(to: NSPoint(x: 0, y: 0)); point.line(to: NSPoint(x: 2.5, y: 1.4)); point.close()
            paint(point, rgb(0.95, 0.85, 0.7), ink, 0.8)
            paw(NSPoint(x: 9, y: 0), 3.9)
        }
        // Every so often: a bright idea.
        if let idea = moment(every: 10, lasting: 2.2, offset: 4) { drawLightbulb(NSPoint(x: body.midX + facing * 14, y: body.maxY + 9), fade(idea)) }
    }

    func drawLightbulb(_ c: NSPoint, _ alpha: CGFloat) {
        for i in 0..<6 {
            let a = CGFloat(i) * .pi / 5 + .pi * 0.0
            let ray = NSBezierPath(); ray.move(to: NSPoint(x: c.x + cos(a) * 7.5, y: c.y + 1 + sin(a) * 7.5))
            ray.line(to: NSPoint(x: c.x + cos(a) * 10, y: c.y + 1 + sin(a) * 10)); ray.lineWidth = 1.2; ray.lineCapStyle = .round
            rgb(1, 0.8, 0.2, alpha).setStroke(); ray.stroke()
        }
        paint(circle(NSPoint(x: c.x, y: c.y + 1), 5), rgb(1, 0.88, 0.3, alpha), rgb(0.6, 0.45, 0.1, alpha), 1)
        paint(roundRect(NSRect(x: c.x - 2.4, y: c.y - 6.5, width: 4.8, height: 3.4), 0.8), rgb(0.6, 0.6, 0.65, alpha), rgb(0.35, 0.35, 0.4, alpha), 0.8)
    }

    // MARK: Coffee break

    /// A mug in one paw with steam curling up; every so often it lifts it for a slow sip.
    func drawCoffee(_ body: NSRect) {
        let rest = handPoint(body, side: 1, height: 0.26)
        let mouth = mouthPoint(body)
        // Lift, hold a sip, put it back down.
        var lift: CGFloat = 0
        if let s = moment(every: 7, lasting: 2.4, offset: 2) { lift = s < 0.25 ? s / 0.25 : (s > 0.75 ? (1 - s) / 0.25 : 1) }
        let sipAt = NSPoint(x: mouth.x + facing * 9, y: mouth.y - 3)
        let p = NSPoint(x: rest.x + (sipAt.x - rest.x) * lift, y: rest.y + (sipAt.y - rest.y) * lift)
        local(p, angle: -0.35 * lift) {
            let handle = NSBezierPath(ovalIn: NSRect(x: 3, y: -4, width: 7, height: 8))
            paint(handle, nil, ink, 3.6)
            paint(handle, nil, rgb(0.30, 0.68, 0.70), 2)
            let mug = roundRect(NSRect(x: -6.5, y: -7, width: 12, height: 13), 2.5)
            paint(mug, rgb(0.30, 0.68, 0.70), ink, 1.2)
            paint(NSBezierPath(rect: NSRect(x: -6.5, y: -2, width: 12, height: 2.4)), rgb(1, 1, 1, 0.55))
            paint(NSBezierPath(ovalIn: NSRect(x: -5.5, y: 3.2, width: 10, height: 3)), rgb(0.42, 0.26, 0.16))
            paw(NSPoint(x: -6, y: -2.5), 4)
        }
        guard lift < 0.2 else { return }
        // Steam: two wavy wisps rising and fading.
        for i in 0..<2 {
            let t = fmod(time * 0.5 + CGFloat(i) * 0.5, 1)
            let x0 = p.x + CGFloat(i * 4 - 2), y0 = p.y + 8 + t * 12
            let wisp = NSBezierPath(); wisp.move(to: NSPoint(x: x0, y: y0))
            wisp.curve(to: NSPoint(x: x0, y: y0 + 8), controlPoint1: NSPoint(x: x0 + 3, y: y0 + 2.6), controlPoint2: NSPoint(x: x0 - 3, y: y0 + 5.4))
            wisp.lineWidth = 1.3; wisp.lineCapStyle = .round
            NSColor(calibratedWhite: 0.6, alpha: 0.55 * (1 - t)).setStroke(); wisp.stroke()
        }
    }

    // MARK: Retro radio

    /// A little vintage radio beside it, sound waves coming out; the pet leans in to listen (`actSway`).
    func drawRadio(_ body: NSRect) {
        let floor = groundY(body)
        let base = NSPoint(x: body.midX + facing * (body.width / 2 - 6), y: floor)
        local(base) {
            // Antenna and handle first, behind the case.
            ink.setStroke()
            let antenna = NSBezierPath(); antenna.move(to: NSPoint(x: 5, y: 15)); antenna.line(to: NSPoint(x: 13, y: 29)); antenna.lineWidth = 1.2; antenna.stroke()
            paint(circle(NSPoint(x: 13, y: 29), 1.4), rgb(0.85, 0.85, 0.9), ink, 0.9)
            let handle = NSBezierPath(); handle.move(to: NSPoint(x: -7, y: 15)); handle.curve(to: NSPoint(x: 5, y: 15), controlPoint1: NSPoint(x: -6, y: 20), controlPoint2: NSPoint(x: 4, y: 20))
            handle.lineWidth = 2; handle.stroke()

            let box = roundRect(NSRect(x: -12, y: 0, width: 26, height: 16), 4)
            paint(box, rgb(0.86, 0.38, 0.26), ink, 1.3)
            paint(roundRect(NSRect(x: -10, y: 2, width: 22, height: 12), 2.5), rgb(0.98, 0.92, 0.80))
            // Speaker grille and a tuning dial.
            paint(circle(NSPoint(x: -3, y: 8), 4.6), rgb(0.62, 0.42, 0.30), ink, 0.9)
            for gx in stride(from: CGFloat(-6), through: 0, by: 2) {
                for gy in stride(from: CGFloat(5), through: 11, by: 2) where hypot(gx + 3, gy - 8) < 3.6 {
                    paint(circle(NSPoint(x: gx, y: gy), 0.45), rgb(0.35, 0.22, 0.15))
                }
            }
            paint(circle(NSPoint(x: 7.5, y: 9.5), 2.6), rgb(0.95, 0.82, 0.4), ink, 0.9)
            let needle = NSBezierPath(); needle.move(to: NSPoint(x: 7.5, y: 9.5)); needle.line(to: NSPoint(x: 7.5 + cos(time * 0.4) * 2, y: 9.5 + sin(time * 0.4) * 2))
            needle.lineWidth = 0.8; ink.setStroke(); needle.stroke()
            paint(roundRect(NSRect(x: 4.5, y: 3.5, width: 6, height: 1.6), 0.6), rgb(0.55, 0.35, 0.25))

            // Sound waves going out away from the pet.
            for i in 0..<3 {
                let t = fmod(time * 0.8 + CGFloat(i) / 3, 1)
                let r = 5 + t * 11
                let wave = NSBezierPath()
                wave.appendArc(withCenter: NSPoint(x: 13, y: 8), radius: r, startAngle: -35, endAngle: 35)
                wave.lineWidth = 1.3; wave.lineCapStyle = .round
                rgb(0.86, 0.38, 0.26, (1 - t) * 0.8).setStroke(); wave.stroke()
            }
        }
        paw(NSPoint(x: base.x - facing * 10, y: floor + 12))
    }

    // MARK: Deep thinker

    /// Paw on chin; above its head a "?" forms, turns over for a moment, then becomes a "!".
    func drawThinker(_ body: NSRect) {
        let mouth = mouthPoint(body)
        paw(NSPoint(x: mouth.x + facing * 3, y: mouth.y - 6.5), 4.4)
        let spot = NSPoint(x: body.midX + facing * 15, y: body.maxY + 10)
        let t = fmod(time, 8)
        if t < 3.4 {
            let grow = min(1, t / 0.5)
            label("?", at: NSPoint(x: spot.x, y: spot.y + sin(time * 2) * 1.5), size: 10 + 4 * grow, color: rgb(0.45, 0.50, 0.75, min(1, (3.4 - t) * 3)))
        } else if t < 5.2 {
            for i in 0..<3 {
                let on = fmod(time * 3 + CGFloat(i) * 0.33, 1) > 0.5
                paint(circle(NSPoint(x: spot.x - 5 + CGFloat(i) * 5, y: spot.y - 2), 1.5), NSColor(calibratedWhite: 0.5, alpha: on ? 0.9 : 0.35))
            }
        } else if t < 7.4 {
            let pop = min(1, (t - 5.2) / 0.25)
            label("!", at: NSPoint(x: spot.x, y: spot.y + 1), size: 9 + 6 * pop, color: rgb(1, 0.55, 0.15, min(1, (7.4 - t) * 3)))
            for i in 0..<4 {
                let a = CGFloat(i) * .pi / 6 + .pi / 4
                let ray = NSBezierPath()
                ray.move(to: NSPoint(x: spot.x + cos(a) * 8, y: spot.y + sin(a) * 8))
                ray.line(to: NSPoint(x: spot.x + cos(a) * (10 + pop * 2), y: spot.y + sin(a) * (10 + pop * 2)))
                ray.lineWidth = 1.2; ray.lineCapStyle = .round; rgb(1, 0.55, 0.15, 0.8).setStroke(); ray.stroke()
            }
        }
    }
}
