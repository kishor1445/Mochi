import AppKit
import Combine

/// Borderless windows must be allowed to sit partly off-screen (on walls) and under the menu bar.
final class PetWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

private struct Jump {
    var start: CGPoint
    var end: CGPoint
    var t: CGFloat
    var duration: CGFloat
    var height: CGFloat
    var target: Platform
}

/// Owns the pet window, runs the 30fps loop, moves the pet over the dock, screen edges and windows.
///
/// Position is tracked as the window's centre (cx, cy). The pet's feet touch its surface
/// `reach` points from the centre, which is why every surface snaps to `edge + reach`.
final class PetController {
    private static let half: CGFloat = PetView.side / 2     // 60
    private static let reach: CGFloat = 52                  // centre → surface

    private let settings = PetSettings.shared
    private let window: PetWindow
    let view = PetView(frame: NSRect(origin: .zero, size: PetView.size))
    private let bubble = SpeechBubble()
    private let brain: Brain
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?

    // Position & motion
    private var cx: CGFloat = 300
    private var cy: CGFloat = 100
    private var vy: CGFloat = 0
    private var surface: Surface = .floor
    private var facing: CGFloat = 1
    private var targetAngle: CGFloat = 0
    private var held = false
    private var jump: Jump?

    // Platforms
    private var platform = Platform(id: 0, minX: 0, maxX: 0, top: 0)
    private var windowPlatforms: [Platform] = []
    private var lastScan = Date.distantPast

    // Behavior
    private var action: PetAction = .idle
    private var remaining: TimeInterval = 1
    private var lastInteraction = Date()
    private var nextGreeting = Date()
    private var clickStreak = 0
    private var lastClick = Date.distantPast

    private let chaseSpeed: CGFloat = 170

    init(brain: Brain = RuleBrain()) {
        self.brain = brain

        window = PetWindow(contentRect: NSRect(origin: .zero, size: PetView.size),
                           styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = view
        window.isReleasedWhenClosed = false

        view.species = settings.species
        view.onClick = { [weak self] in self?.petted() }
        view.onDragBegan = { [weak self] in self?.dragBegan() }
        view.onDragEnded = { [weak self] in self?.dragEnded() }

        let f = screenFrame
        platform = dock(f)
        cx = f.midX
        cy = platform.top + Self.reach
        window.setFrameOrigin(NSPoint(x: cx - Self.half, y: cy - Self.half))

        settings.$species.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] s in
            guard let self else { return }
            self.view.species = s
            self.view.spawnHearts(4)
            self.say("Hi! I'm \(s.name)!", force: true)
        }.store(in: &cancellables)

        settings.$chattiness.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.scheduleGreeting(Date())
        }.store(in: &cancellables)

        scheduleGreeting(Date())
    }

    // MARK: Public controls (menu bar, right-click, settings)

    func start() {
        window.orderFrontRegardless()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick(1.0 / 30.0) }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.say("Hi! I'm \(self.settings.species.name)!")
        }
    }

    func setContextMenu(_ menu: NSMenu) { view.menu = menu }

    func greet() {
        touch()
        if surface != .air { apply(Decision(action: .greet, duration: 2.2), forceSay: true) }
        else { say(Dialogue.greeting(species: settings.species, hour: hour), force: true) }
    }

    func petted() {
        touch()
        let now = Date()
        clickStreak = now.timeIntervalSince(lastClick) < 1.5 ? clickStreak + 1 : 1
        lastClick = now

        let wasSleeping = action == .sleep
        view.spawnHearts(3)
        if clickStreak >= 5 {
            say("Okay okay, I love you too! 💖", force: true)
            clickStreak = 0
        } else {
            say((wasSleeping ? Dialogue.startled : Dialogue.petted).randomElement() ?? "Hehe!", force: true)
        }
        action = .happy
        remaining = 1.8
    }

    func sleepNow() {
        touch()
        action = .sleep
        remaining = 30
        say("Zzz…", force: true)
    }

    func comeHere() {
        touch()
        apply(Decision(action: .chase, duration: 8))
        say("Coming!", force: true)
    }

    // MARK: Geometry

    private var screenFrame: NSRect { (window.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame }
    private var hour: Int { Calendar.current.component(.hour, from: Date()) }

    private func dock(_ f: NSRect) -> Platform {
        Platform(id: 0, minX: f.minX + 52, maxX: f.maxX - 52, top: f.minY)
    }

    private func allPlatforms(_ f: NSRect) -> [Platform] {
        [dock(f)] + (settings.walkOnWindows ? windowPlatforms : [])
    }

    /// Local facing ↔ direction along the surface axis (x on floor/ceiling, y on walls).
    /// The mapping is its own inverse.
    private func map(_ v: CGFloat, _ s: Surface) -> CGFloat {
        (s == .ceiling || s == .leftWall) ? -v : v
    }

    private func angle(for s: Surface) -> CGFloat {
        switch s {
        case .floor, .air: return 0
        case .leftWall: return -.pi / 2
        case .rightWall: return .pi / 2
        case .ceiling: return .pi
        }
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), max(lo, hi)) }

    /// Pin the pet to its surface and keep it inside the screen.
    private func snap(_ f: NSRect) {
        let r = Self.reach
        switch surface {
        case .floor:
            cx = clamp(cx, platform.minX, platform.maxX)
            cy = platform.top + r
        case .ceiling:
            cx = clamp(cx, f.minX + 52, f.maxX - 52)
            cy = f.maxY - r
        case .leftWall:
            cx = f.minX + r
            cy = clamp(cy, f.minY + 52, f.maxY - 52)
        case .rightWall:
            cx = f.maxX - r
            cy = clamp(cy, f.minY + 52, f.maxY - 52)
        case .air:
            break
        }
    }

    // MARK: Platforms (windows)

    private func refreshPlatforms(_ now: Date, _ f: NSRect) {
        guard now.timeIntervalSince(lastScan) > 0.25 else { return }
        lastScan = now
        windowPlatforms = settings.walkOnWindows ? WindowScanner.platforms(in: f) : []

        if surface == .floor, platform.id != 0, jump == nil {
            if let p = windowPlatforms.first(where: { $0.id == platform.id }) {
                platform = p                       // the window moved: follow it
            } else {
                surface = .air; vy = 0             // window closed / hidden: fall
            }
        }
    }

    private func reachable(_ p: Platform, feet: CGFloat) -> Bool {
        guard p.id != platform.id, p.top > feet + 30, p.top - feet < 600 else { return false }
        let dx = cx < p.minX ? p.minX - cx : (cx > p.maxX ? cx - p.maxX : 0)
        return dx < 450
    }

    // MARK: Tick

    private func tick(_ dt: CGFloat) {
        let now = Date()
        let f = screenFrame
        view.advance(dt)
        if platform.id == 0 { platform = dock(f) }
        refreshPlatforms(now, f)

        // Safety net: if the pet ever ends up outside every screen, bring it back.
        if !held, !isOnScreen() { bringBack() }

        if held {
            cx = window.frame.midX
            cy = window.frame.midY
            view.mood = .held
            targetAngle = 0
        } else if var j = jump {
            j.t += dt / j.duration
            if j.t >= 1 {
                jump = nil
                land(on: j.target, f)
            } else {
                jump = j
                cx = j.start.x + (j.end.x - j.start.x) * j.t
                cy = j.start.y + (j.end.y - j.start.y) * j.t + sin(j.t * .pi) * j.height
                view.mood = .jump
                targetAngle = 0
            }
        } else if surface == .air {
            fall(dt, f)
        } else if surface != .floor && !settings.climbEdges {
            surface = .air; vy = 0                 // climbing turned off: let go
        } else {
            remaining -= TimeInterval(dt)
            maybeGreet(now)
            if remaining <= 0 { apply(brain.nextDecision(context(f))) }
            behave(dt, f)
            targetAngle = angle(for: surface)
        }
        finish(dt, f)
    }

    private func finish(_ dt: CGFloat, _ f: NSRect) {
        // Smoothly rotate onto the new surface.
        var diff = targetAngle - view.angle
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        view.angle += diff * min(1, dt * 10)

        // Eyes follow the cursor (converted into the pet's rotated frame).
        let m = NSEvent.mouseLocation
        let vx = m.x - cx, vyy = m.y - (cy - 20)
        let dist = hypot(vx, vyy)
        let ux = dist > 1 ? vx / dist : 0, uy = dist > 1 ? vyy / dist : 0
        let a = view.angle
        let strength = min(1, dist / 150) * 2.6
        view.gaze = CGPoint(x: (ux * cos(a) + uy * sin(a)) * strength,
                            y: (-ux * sin(a) + uy * cos(a)) * strength)
        view.facing = facing

        window.setFrameOrigin(NSPoint(x: cx - Self.half, y: cy - Self.half))
        view.needsDisplay = true

        if bubble.visible {
            let head = settings.species.headRoom
            switch surface {
            case .ceiling:
                bubble.update(centerX: cx, aboveY: cy + 46, belowY: cy - 4 - head - 2, preferBelow: true, limit: f)
            case .leftWall, .rightWall:
                bubble.update(centerX: cx, aboveY: cy + 46, belowY: cy - 46, preferBelow: false, limit: f)
            default:
                bubble.update(centerX: cx, aboveY: cy + 4 + head + 2, belowY: cy - 60, preferBelow: false, limit: f)
            }
        }
    }

    // MARK: Falling & landing

    private func fall(_ dt: CGFloat, _ f: NSRect) {
        let prevFeet = cy - Self.reach
        vy -= 1800 * dt
        cy += vy * dt
        let newFeet = cy - Self.reach
        cx = clamp(cx, f.minX + 52, f.maxX - 52)
        view.mood = .held
        targetAngle = 0

        let hits = allPlatforms(f).filter { p in
            let inside = p.id == 0 || (cx >= p.minX && cx <= p.maxX)
            return inside && prevFeet >= p.top - 1 && newFeet <= p.top
        }
        if let best = hits.max(by: { $0.top < $1.top }) { land(on: best, f) }
    }

    private func land(on p: Platform, _ f: NSRect) {
        platform = p
        surface = .floor
        vy = 0
        cx = clamp(cx, p.minX, p.maxX)
        cy = p.top + Self.reach
        if p.id != 0, Double.random(in: 0..<1) < 0.5 {
            say(Dialogue.landedWindow.randomElement() ?? "Nice!")
        }
        action = .idle
        remaining = 1.5
        targetAngle = 0
    }

    private func startLeap() -> Bool {
        let feet = cy - Self.reach
        guard let p = windowPlatforms.filter({ reachable($0, feet: feet) }).randomElement() else { return false }
        let end = CGPoint(x: clamp(cx, p.minX, p.maxX), y: p.top + Self.reach)
        let start = CGPoint(x: cx, y: cy)
        let dist = hypot(end.x - start.x, end.y - start.y)
        facing = end.x >= start.x ? 1 : -1
        jump = Jump(start: start, end: end, t: 0,
                    duration: max(0.55, min(1.1, dist / 700 + 0.4)),
                    height: max(90, end.y - start.y + 70), target: p)
        surface = .air
        say(Dialogue.leaping.randomElement() ?? "Hup!")
        return true
    }

    // MARK: Dragging

    private func dragBegan() {
        held = true
        jump = nil
        touch()
        if Double.random(in: 0..<1) < 0.35 { say(Dialogue.dragged.randomElement() ?? "Wheee!", force: true) }
    }

    private func dragEnded() {
        held = false
        let f = screenFrame
        cx = window.frame.midX
        cy = window.frame.midY
        vy = 0

        // Let go close to a screen edge and the pet clings to it instead of dropping to the dock.
        let dl = cx - f.minX, dr = f.maxX - cx, dt = f.maxY - cy
        let nearest = min(dl, dr, dt)
        if settings.climbEdges && nearest < 95 {
            if nearest == dt { surface = .ceiling }
            else if nearest == dl { surface = .leftWall }
            else { surface = .rightWall }
            snap(f)
            action = .idle
            remaining = 2
            say(Dialogue.clung.randomElement() ?? "Got a grip!")
        } else {
            // Never let go outside the screen: pull it back inside before it falls.
            cx = clamp(cx, f.minX + 52, f.maxX - 52)
            cy = min(cy, f.maxY - 52)
            surface = .air
        }
    }

    // MARK: Behavior

    private func touch() { lastInteraction = Date() }

    private func apply(_ d: Decision, forceSay: Bool = false) {
        action = d.action
        remaining = d.duration
        switch d.action {
        case .walk(let axis):
            facing = map(axis, surface)
        case .chase where !settings.followCursor:
            action = .idle
        case .leap:
            if !startLeap() { action = .idle; remaining = 1.5 }
        case .greet:
            say(Dialogue.greeting(species: settings.species, hour: hour), force: forceSay)
        case .stretch:
            if Double.random(in: 0..<1) < 0.5 { say("*yaaawn*") }
        case .dance:
            if Double.random(in: 0..<1) < 0.5 { say("♪ La la la ♪") }
        case .zoomies:
            if Double.random(in: 0..<1) < 0.5 { say("Zoomies!!") }
        default:
            break
        }
        view.spin = 0
    }

    /// A random trick, on demand (menu bar / right-click).
    func trick() {
        touch()
        let options: [Decision] = [
            Decision(action: .dance, duration: 4),
            Decision(action: .spin, duration: 0.9),
            Decision(action: .stretch, duration: 2.4),
            Decision(action: .zoomies, duration: 3.5),
            Decision(action: .lookAround, duration: 3)
        ]
        if surface != .air, jump == nil, !held, let d = options.randomElement() { apply(d) }
    }

    /// Rescue: put the pet back on screen and let it drop in from the top.
    func bringBack() {
        touch()
        held = false
        jump = nil
        let f = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        surface = .air
        vy = 0
        cx = f.midX
        cy = f.maxY - 100
        view.angle = 0
        targetAngle = 0
        view.spin = 0
        window.setFrameOrigin(NSPoint(x: cx - Self.half, y: cy - Self.half))
        window.orderFrontRegardless()
        say("Phew, I'm back!", force: true)
    }

    private func isOnScreen() -> Bool {
        let p = CGPoint(x: cx, y: cy)
        return NSScreen.screens.contains { $0.frame.insetBy(dx: -20, dy: -20).contains(p) }
    }

    private func scheduleGreeting(_ now: Date) {
        if let r = settings.chattiness.interval {
            nextGreeting = now.addingTimeInterval(.random(in: r))
        } else {
            nextGreeting = now.addingTimeInterval(60)
        }
    }

    private func maybeGreet(_ now: Date) {
        guard now >= nextGreeting else { return }
        scheduleGreeting(now)
        if settings.chattiness != .off, action != .sleep, !bubble.visible {
            apply(Decision(action: .greet, duration: 2.2))
        }
    }

    func say(_ text: String, force: Bool = false) {
        guard force || settings.chattiness != .off else { return }
        bubble.say(text)
    }

    private func behave(_ dt: CGFloat, _ f: NSRect) {
        switch action {
        case .idle, .leap:
            view.mood = .idle
            lookAtCursor()
        case .sleep:
            view.mood = .sleep
        case .happy, .greet:
            view.mood = .happy
        case .walk:
            view.mood = .walk
            advance(settings.species.walkSpeed * dt, autonomous: true, f)
        case .chase:
            chase(dt, f)
        case .stretch:
            view.mood = .stretch
        case .dance:
            view.mood = .dance
        case .spin:
            view.mood = .happy
            view.spin += 2 * .pi * dt / 0.9
        case .lookAround:
            view.mood = .idle
            facing = sin(view.time * 2.5) > 0 ? 1 : -1
        case .zoomies:
            view.mood = .chase
            if Double.random(in: 0..<1) < 0.03 { turnAround() }
            advance(settings.species.walkSpeed * 3.5 * dt, autonomous: true, f)
        }
        snap(f)
    }

    /// Distance from the pet to the cursor along the current surface's axis.
    private func cursorDelta() -> CGFloat {
        let m = NSEvent.mouseLocation
        switch surface {
        case .floor, .ceiling: return m.x - cx
        case .leftWall, .rightWall: return m.y - cy
        case .air: return 0
        }
    }

    private func lookAtCursor() {
        let d = cursorDelta()
        let m = NSEvent.mouseLocation
        if abs(d) > 40, hypot(m.x - cx, m.y - cy) < 500 {
            facing = map(d > 0 ? 1 : -1, surface)
        }
    }

    private func chase(_ dt: CGFloat, _ f: NSRect) {
        let d = cursorDelta()
        if abs(d) < 28 {
            view.mood = .idle
            return
        }
        facing = map(d > 0 ? 1 : -1, surface)
        view.mood = .chase
        advance(chaseSpeed * dt, autonomous: false, f)
    }

    /// Move along the surface. When `autonomous`, reaching an end makes a decision
    /// (turn around, climb the wall, hop off a window).
    private func advance(_ distance: CGFloat, autonomous: Bool, _ f: NSRect) {
        let s = map(facing, surface)
        switch surface {
        case .floor, .ceiling: cx += s * distance
        case .leftWall, .rightWall: cy += s * distance
        case .air: return
        }
        if autonomous { handleEnds(f, s) }
    }

    private func turnAround() { facing = -facing }

    private func handleEnds(_ f: NSRect, _ s: CGFloat) {
        let was = surface
        switch surface {
        case .floor:
            if cx <= platform.minX && s < 0 { floorEnd(f, left: true, s) }
            else if cx >= platform.maxX && s > 0 { floorEnd(f, left: false, s) }

        case .ceiling:
            let left = cx <= f.minX + 52 && s < 0
            let right = cx >= f.maxX - 52 && s > 0
            if left || right {
                if Double.random(in: 0..<1) < 0.6 {
                    surface = left ? .leftWall : .rightWall
                    facing = map(-1, surface)              // head down the wall
                    snap(f)
                } else { turnAround() }
            }

        case .leftWall, .rightWall:
            if cy >= f.maxY - 52 && s > 0 {
                if Double.random(in: 0..<1) < 0.6 {
                    surface = .ceiling
                    facing = map(was == .leftWall ? 1 : -1, .ceiling)
                    snap(f)
                } else { turnAround() }
            } else if cy <= f.minY + 52 && s < 0 {
                surface = .floor
                platform = dock(f)
                facing = map(was == .leftWall ? 1 : -1, .floor)
                snap(f)
            }

        case .air:
            break
        }
    }

    private func floorEnd(_ f: NSRect, left: Bool, _ s: CGFloat) {
        if platform.id == 0 {
            if settings.climbEdges && Double.random(in: 0..<1) < 0.5 {
                surface = left ? .leftWall : .rightWall
                facing = map(1, surface)                    // head up the wall
                snap(f)
                if Double.random(in: 0..<1) < 0.4 { say(Dialogue.clung.randomElement() ?? "Climbing!") }
            } else {
                turnAround()
            }
        } else if Double.random(in: 0..<1) < 0.4 {
            surface = .air                                  // hop off the window edge
            vy = 0
            cx += s * 30
        } else {
            turnAround()
        }
    }

    private func context(_ f: NSRect) -> PetContext {
        let frac: CGFloat
        switch surface {
        case .floor: frac = (cx - platform.minX) / max(1, platform.maxX - platform.minX)
        case .ceiling: frac = (cx - (f.minX + 52)) / max(1, f.width - 104)
        case .leftWall, .rightWall: frac = (cy - (f.minY + 52)) / max(1, f.height - 104)
        case .air: frac = 0.5
        }
        let m = NSEvent.mouseLocation
        let feet = cy - Self.reach
        return PetContext(surface: surface,
                          axisFraction: frac,
                          cursorDistance: hypot(m.x - cx, m.y - cy),
                          secondsSinceInteraction: Date().timeIntervalSince(lastInteraction),
                          hour: hour,
                          platformAbove: surface == .floor && windowPlatforms.contains { reachable($0, feet: feet) })
    }
}
