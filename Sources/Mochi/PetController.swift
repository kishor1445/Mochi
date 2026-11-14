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

/// Owns the pet window, runs the 30fps loop, moves the pet over the dock, screen edges and windows,
/// and reacts to music, treats, the cursor and what you are doing.
///
/// Position is tracked as the window's centre (cx, cy). The pet's feet touch its surface
/// `reach` points from the centre, which is why every surface snaps to `edge + reach`.
final class PetController {
    /// How big the pet is on screen, relative to its 120pt design size.
    private var scale: CGFloat { settings.petSize.scale }
    private var half: CGFloat { PetView.side / 2 * scale }
    private var reach: CGFloat { 52 * scale }               // centre → surface

    private let settings = PetSettings.shared
    /// The main pet owns the needs, reminders, focus sessions and toys. A companion just lives alongside it.
    let isMain: Bool
    weak var buddy: PetController?
    private var species: Species { isMain ? settings.species : settings.companionSpecies }
    private let mind = PetMind.shared
    private let window: PetWindow
    let view = PetView(frame: NSRect(origin: .zero, size: PetView.size))
    private let bubble = SpeechBubble()
    private let brain: Brain
    private let audio = AudioWatcher.shared
    private let log = DailyLog.shared
    private let calendar = CalendarWatcher()
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
    private var vx: CGFloat = 0                     // sideways speed while thrown
    private var thrown = false
    private var bounces = 0
    private var dragVelocity = CGPoint.zero

    // Hide and peek
    private enum HidePhase { case none, going, hidden }
    private var hidePhase = HidePhase.none
    private var hideSide: CGFloat = -1              // which screen edge: -1 left, +1 right
    private var hideShift: CGFloat = 0              // how far the window is slid past the edge

    // Two pets
    private var nextVisit = Date().addingTimeInterval(.random(in: 25...60))

    // Power
    private var pauseReasons = Set<String>()
    private var fps = 0
    private var lastFrame = Date()
    private var jump: Jump?
    private var forceClimb = false

    // Platforms
    private var platform = Platform(id: 0, minX: 0, maxX: 0, top: 0)
    private var windowPlatforms: [Platform] = []
    private var lastScan = Date.distantPast
    private var freezeUntil = Date.distantPast      // ignore window changes while Spaces slide
    private var lastFreeze = Date.distantPast
    private var missingScans = 0
    private var dockHidden = false                  // space is reserved for the Dock but it isn't drawn

    // Slipping off walls / ceiling
    private var gripTime: TimeInterval = 0
    private var slipTimer: CGFloat = 0
    private var slipped = false

    // Behavior
    private var action: PetAction = .idle
    private var remaining: TimeInterval = 1
    private var lastInteraction = Date()
    private var nextGreeting = Date()
    private var clickStreak = 0
    private var lastClick = Date.distantPast

    // Awareness
    private var media: MediaActivity = .none
    private var userAway = false
    private var activeSeconds: TimeInterval = 0
    private var lastSlow = Date.distantPast
    private var lastHour = -1
    private var lastBattery = Date.distantPast
    private var batteryWarned = false
    private var wasCharging: Bool?

    // Cursor interactions
    private var lastMouse = NSEvent.mouseLocation
    private var lastMouseDelta = CGPoint.zero
    private var shake: CGFloat = 0
    private var dizzyCooldown = Date.distantPast
    private var hoverTime: CGFloat = 0
    private var hoverReacted = false

    // Typing along (only ever a count of key presses, never which keys)
    private var keyCount = SystemInfo.keyPressCount()
    private var lastKey = Date.distantPast
    private var typingRate: Double = 0              // keys per second, smoothed
    private var typingStreak: TimeInterval = 0      // how long you've been typing without a real pause
    private var fastTyping: TimeInterval = 0
    private var nextTypingCheer: TimeInterval = 60
    private var fastCheerAfter = Date.distantPast

    // Gentle reminders, busy Mac, calendar
    private var reminderElapsed: [ReminderKind: TimeInterval] = [:]
    private var lastReminder = Date.distantPast
    private var lastCPU = SystemInfo.cpuTicks()
    private var lastCPUCheck = Date.distantPast
    private var busySeconds: TimeInterval = 0
    private var busyCooldown = Date.distantPast
    private var hotCooldown = Date.distantPast
    private var lastCalendarCheck = Date.distantPast
    private var focusPlanned = 0

    private var treat: Treat?
    private var ball: Ball?
    private var lastKickLine = Date.distantPast

    /// When the running focus session ends (nil = no session).
    private(set) var focusEnds: Date?

    private let chaseSpeed: CGFloat = 170

    init(brain: Brain = MindBrain(), isMain: Bool = true) {
        self.brain = brain
        self.isMain = isMain

        let side = PetView.side * PetSettings.shared.petSize.scale
        window = PetWindow(contentRect: NSRect(x: 0, y: 0, width: side, height: side),
                           styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        // Visible on every Space and over full-screen apps; stays put while Spaces slide.
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.animationBehavior = .none
        window.hidesOnDeactivate = false
        window.contentView = view
        window.isReleasedWhenClosed = false

        // Swiping between Spaces shuffles every window's position: pause window tracking until it settles.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.freezeUntil = Date().addingTimeInterval(1.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.window.orderFrontRegardless() }
        }

        BubbleView.scale = settings.petSize.bubbleScale
        view.species = species
        view.outfit = wornOutfit
        view.onClick = { [weak self] in self?.petted() }
        view.onDragBegan = { [weak self] in self?.dragBegan() }
        view.onDragEnded = { [weak self] in self?.dragEnded() }

        checkDock()
        let f = screenFrame
        platform = dock(f)
        cx = f.midX + (isMain ? 0 : 140)
        cy = platform.top + reach
        window.setFrameOrigin(NSPoint(x: cx - half, y: cy - half))

        (isMain ? settings.$species : settings.$companionSpecies).dropFirst().receive(on: DispatchQueue.main).sink { [weak self] s in
            guard let self else { return }
            self.view.species = s
            self.view.spawnHearts(4)
            self.say("Hi! I'm \(s.name)!", force: true)
        }.store(in: &cancellables)

        settings.$petSize.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] size in
            guard let self else { return }
            let side = PetView.side * size.scale
            BubbleView.scale = size.bubbleScale
            self.bubble.rescale()
            self.window.setContentSize(NSSize(width: side, height: side))
            if self.surface == .floor { self.cy = self.platform.top + self.reach }
            self.window.setFrameOrigin(NSPoint(x: self.cx - self.half, y: self.cy - self.half))
        }.store(in: &cancellables)

        settings.$chattiness.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.scheduleGreeting(Date())
        }.store(in: &cancellables)

        if isMain {
            settings.$outfit.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
                guard let self else { return }
                self.view.outfit = self.wornOutfit
            }.store(in: &cancellables)

            mind.onLevelUp = { [weak self] level in
                guard let self else { return }
                self.view.spawnHearts(6)
                self.say("We're \(PetMind.title(level).lowercased())s now! 💞", force: true)
                // A new level unlocks a new thing to wear: mention it once the first bubble has gone.
                if let gift = Outfit.allCases.first(where: { $0.unlockLevel == level }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                        self?.say(Dialogue.newOutfit(gift), force: true)
                    }
                }
            }
        }

        scheduleGreeting(Date())
    }

    // MARK: Public controls (menu bar, right-click, settings)

    func start() {
        window.orderFrontRegardless()
        audio.start()
        lastFrame = Date()
        schedule(30)
        DispatchQueue.main.asyncAfter(deadline: .now() + (isMain ? 0.8 : 2.4)) { [weak self] in
            guard let self else { return }
            if !self.isMain {
                self.say("Hi! I'm \(self.species.name)!")
            } else if self.settings.dailyCheckIn, self.log.hasFreshYesterday, self.log.current.activeSeconds < 120,
                      let y = self.log.yesterday {
                // First visit of the day: a quick look back.
                self.say(y.summary(prefix: "Yesterday"), force: true, seconds: 7)
            } else if self.mind.isNew {
                self.say("Hi! I'm \(self.species.name)! Nice to meet you!")
            } else if self.mind.awaySeconds > 8 * 3600 {
                self.mind.reunited()
                self.view.spawnHearts(4)
                self.say(Dialogue.missedYou.randomElement() ?? "I missed you!")
            } else {
                self.say("Hi! I'm \(self.species.name)!")
            }
        }
    }

    func setContextMenu(_ menu: NSMenu) { view.menu = menu }

    /// Remove this pet from the screen for good (used when the second pet is switched off).
    func stop() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
        treat?.remove(); treat = nil
        ball?.remove(); ball = nil
        bubble.hide()
        window.orderOut(nil)
    }

    // MARK: Power

    /// Stop animating entirely (Mac asleep, display off, screen locked). Nothing runs until `resume`.
    func pause(_ reason: String) {
        pauseReasons.insert(reason)
        timer?.invalidate()
        timer = nil
        fps = 0
        if isMain { mind.save(); log.publish() }
    }

    func resume(_ reason: String) {
        pauseReasons.remove(reason)
        guard pauseReasons.isEmpty, timer == nil else { return }
        lastFrame = Date()
        lastSlow = Date()                          // time spent asleep doesn't count as time awake
        keyCount = SystemInfo.keyPressCount()
        lastCPU = SystemInfo.cpuTicks()
        schedule(30)
        window.orderFrontRegardless()
    }

    private func schedule(_ rate: Int) {
        timer?.invalidate()
        fps = rate
        let t = Timer(timeInterval: 1.0 / Double(rate), repeats: true) { [weak self] _ in self?.frame() }
        t.tolerance = 0.2 / Double(rate)           // lets macOS line the wake-ups up with other work
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Full speed only when something is moving; a napping pet barely costs anything.
    private var wantedFPS: Int {
        if held || jump != nil || surface == .air || treat != nil || ball != nil || bubble.visible { return 30 }
        if action == .sleep { return 6 }
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return 15 }
        switch action {
        case .idle, .lookAround, .mope, .leap, .climbEdge:
            // Just standing there: breathing and blinking look fine at half speed.
            return view.musicBpm > 0 || view.tap > 0 || slipTimer > 0 || abs(hideShift) > 0.5 ? 30 : 15
        case .hide where hidePhase == .hidden:
            return 15
        default:
            return 30
        }
    }

    private func frame() {
        let now = Date()
        let dt = CGFloat(min(0.2, max(0.001, now.timeIntervalSince(lastFrame))))
        lastFrame = now
        tick(dt)
        let want = wantedFPS
        if want != fps, timer != nil { schedule(want) }
    }

    private var wornOutfit: Outfit {
        isMain && settings.outfit.unlockLevel <= mind.level ? settings.outfit : .none
    }

    /// Focus sessions belong to the main pet; a companion keeps quiet along with it.
    private var focusing: Bool { (isMain ? focusEnds : buddy?.focusEnds) != nil }

    func greet() {
        touch()
        if surface != .air { apply(Decision(action: .greet, duration: 2.2), forceSay: true) }
        else { say(greetingLine(), force: true) }
    }

    func petted() {
        touch()
        let now = Date()
        clickStreak = now.timeIntervalSince(lastClick) < 1.5 ? clickStreak + 1 : 1
        lastClick = now

        let wasSleeping = action == .sleep
        mind.petted()
        log.petted()
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

    /// Drops a snack from the top of the screen (under the mouse) for the pet to eat.
    func giveTreat() {
        guard treat == nil else { return }
        touch()
        if mind.isStuffed {
            say(Dialogue.stuffed.randomElement() ?? "I'm stuffed!", force: true)
            return
        }
        endBall(celebrate: false)
        let f = screenFrame
        let x = clamp(NSEvent.mouseLocation.x, f.minX + 60, f.maxX - 60)
        treat = Treat(emoji: species.treatEmoji, x: x, y: f.maxY - 40)
        say(Dialogue.treatDropped.randomElement() ?? "Ooh, a treat!", force: true)
    }

    /// Drops a bouncy toy near the mouse; the pet chases it and kicks it around for a while.
    func playBall() {
        guard ball == nil, treat == nil else { return }
        touch()
        if mind.energy < 0.1 {
            say(Dialogue.tooTired.randomElement() ?? "Too tired…", force: true)
            return
        }
        let f = screenFrame
        let x = clamp(NSEvent.mouseLocation.x, f.minX + 60, f.maxX - 60)
        ball = Ball(emoji: species.toyEmoji, x: x, y: f.minY + 260)
        say(Dialogue.ballDropped.randomElement() ?? "Ball!", force: true)
    }

    // MARK: Focus sessions

    var focusMinutesLeft: Int? {
        focusEnds.map { max(1, Int(ceil($0.timeIntervalSinceNow / 60))) }
    }

    /// The pet keeps quiet and calm for `minutes`, then celebrates with you.
    func startFocus(minutes: Int) {
        touch()
        focusEnds = Date().addingTimeInterval(TimeInterval(minutes * 60))
        focusPlanned = minutes
        activeSeconds = 0
        endBall(celebrate: false)
        say(Dialogue.focusStart.randomElement() ?? "Focus time!", force: true)
        if canAct { apply(Decision(action: .idle, duration: 4)) }
    }

    func stopFocus() {
        guard focusEnds != nil else { return }
        focusEnds = nil
        say(Dialogue.focusStopped.randomElement() ?? "Okay, break time!", force: true)
    }

    /// Says how today has gone so far (menu: Daily Check-in).
    func checkIn() {
        touch()
        say(log.current.summary(prefix: "Today"), force: true, seconds: 7)
        if canAct { apply(Decision(action: .happy, duration: 1.6)) }
    }

    private func finishFocus() {
        focusEnds = nil
        activeSeconds = 0
        mind.focusedTogether()
        log.focused(minutes: focusPlanned)
        view.spawnHearts(5)
        say(Dialogue.focusDone.randomElement() ?? "Focus done! 🎉", force: true)
        if canAct { apply(Decision(action: .dance, duration: 5)) }
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
        if canAct, let d = options.randomElement() { apply(d) }
    }

    /// Rescue: put the pet back on screen and let it drop in from the top.
    func bringBack() {
        touch()
        held = false
        jump = nil
        thrown = false
        vx = 0
        hidePhase = .none
        let f = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        surface = .air
        vy = 0
        cx = f.midX
        cy = f.maxY - 100
        view.angle = 0
        targetAngle = 0
        view.spin = 0
        window.setFrameOrigin(NSPoint(x: cx - half, y: cy - half))
        window.orderFrontRegardless()
        say("Phew, I'm back!", force: true)
    }

    // MARK: Geometry

    /// The area the pet lives in: the screen minus the menu bar and the Dock.
    /// When the Dock's strip is reserved but the Dock isn't there, the pet gets that strip too.
    private var screenFrame: NSRect {
        let s = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let v = s.visibleFrame
        guard dockHidden else { return v }
        return NSRect(x: s.frame.minX, y: s.frame.minY, width: s.frame.width, height: v.maxY - s.frame.minY)
    }

    private func checkDock() {
        let s = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let v = s.visibleFrame
        let reserved = v.minY - s.frame.minY > 8 || v.minX - s.frame.minX > 8 || s.frame.maxX - v.maxX > 8
        dockHidden = reserved && !WindowScanner.dockIsShowing()
    }
    private var hour: Int { Calendar.current.component(.hour, from: Date()) }
    private var canAct: Bool { surface != .air && jump == nil && !held }

    private func dock(_ f: NSRect) -> Platform {
        Platform(id: 0, minX: f.minX + reach, maxX: f.maxX - reach, top: f.minY)
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
        let r = reach
        switch surface {
        case .floor:
            cx = clamp(cx, platform.minX, platform.maxX)
            cy = platform.top + r
        case .ceiling:
            cx = clamp(cx, f.minX + reach, f.maxX - reach)
            cy = f.maxY - r
        case .leftWall:
            cx = f.minX + r
            cy = clamp(cy, f.minY + reach, f.maxY - reach)
        case .rightWall:
            cx = f.maxX - r
            cy = clamp(cy, f.minY + reach, f.maxY - reach)
        case .air:
            break
        }
    }

    private func isOnScreen() -> Bool {
        let p = CGPoint(x: cx, y: cy)
        return NSScreen.screens.contains { $0.frame.insetBy(dx: -20, dy: -20).contains(p) }
    }

    // MARK: Platforms (windows)

    private func refreshPlatforms(_ now: Date, _ f: NSRect) {
        // Standing on a window needs quick updates to follow it; otherwise twice a second is plenty.
        let every = (surface == .floor && platform.id != 0) || jump != nil ? 0.25 : 0.5
        guard now.timeIntervalSince(lastScan) > every else { return }
        lastScan = now
        if now < freezeUntil { return }            // Spaces are sliding: keep what we knew
        checkDock()

        let scanned = settings.walkOnWindows ? WindowScanner.platforms(in: f) : []

        if surface == .floor, platform.id != 0, jump == nil {
            if let p = scanned.first(where: { $0.id == platform.id }) {
                missingScans = 0
                let jumped = abs(p.top - platform.top) > 80 || abs(p.minX - platform.minX) > 80
                if jumped, now.timeIntervalSince(lastFreeze) > 2 {
                    // A sudden big move (Space swipe, window snapping): wait for it to settle.
                    lastFreeze = now
                    freezeUntil = now.addingTimeInterval(0.8)
                    return
                }
                platform = p                       // follow the window
            } else {
                missingScans += 1
                if missingScans < 3 { return }     // may be a flicker: only fall if it stays gone
                missingScans = 0
                surface = .air; vy = 0             // window closed or on another Space
            }
        }
        windowPlatforms = scanned
    }

    private func reachable(_ p: Platform, feet: CGFloat) -> Bool {
        guard p.id != platform.id, p.top > feet + 30, p.top - feet < 600 else { return false }
        let dx = cx < p.minX ? p.minX - cx : (cx > p.maxX ? cx - p.maxX : 0)
        return dx < 450
    }

    // MARK: Tick

    private func tick(_ dt: CGFloat) {
        let now = Date()
        var f = screenFrame
        view.advance(dt)
        refreshPlatforms(now, f)
        f = screenFrame                            // the Dock may have just appeared or gone
        if platform.id == 0 {
            let floor = dock(f)
            // The floor dropped away (the Dock was hidden): fall to the new one instead of teleporting.
            if surface == .floor, jump == nil, !held, floor.top < platform.top - 10 { surface = .air; vy = 0 }
            platform = floor
        }
        slowTick(now)

        if let t = treat {
            t.update(dt, floorY: f.minY - 2)
            if now.timeIntervalSince(t.born) > 40 { t.remove(); treat = nil }
        }
        if let b = ball {
            b.update(dt, floorY: f.minY - 2, minX: f.minX + 30, maxX: f.maxX - 30)
            if now.timeIntervalSince(b.born) > 45 { endBall(celebrate: false) }
        }

        // Safety net: if the pet ever ends up outside every screen, bring it back.
        if !held, !isOnScreen() { bringBack() }

        trackCursor(dt, now)
        trackTyping(dt, now)

        if held {
            // Remember how fast the pet is being dragged, so letting go mid-swing throws it.
            let px = window.frame.midX, py = window.frame.midY
            dragVelocity.x = dragVelocity.x * 0.55 + (px - cx) / dt * 0.45
            dragVelocity.y = dragVelocity.y * 0.55 + (py - cy) / dt * 0.45
            cx = px
            cy = py
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
            if surface == .floor { gripTime = 0 }
            else {
                gripTime += TimeInterval(dt)
                if slipTimer > 0 {
                    // Losing grip: wobble, then fall.
                    slipTimer -= dt
                    view.mood = .held
                    view.spin = sin(view.time * 38) * 0.14
                    targetAngle = angle(for: surface)
                    if slipTimer <= 0 { view.spin = 0; letGo() }
                    finish(dt, f)
                    return
                }
                // Grips are strong for the first ~30s, then slowly get tired.
                // Roughly: a slip every minute or two of hanging around, rarer on walls than the ceiling.
                let tired = max(0, gripTime - 30)
                let rate = (surface == .ceiling ? 0.006 : 0.003) + min(0.02, tired * 0.0004)
                if gripTime > 30, Double.random(in: 0..<1) < rate * Double(dt) { startSlip() }
            }

            if let t = treat, handleTreat(t, dt, f) {
                finish(dt, f)
                return
            }
            if let b = ball, handleBall(b, dt, f, now) {
                finish(dt, f)
                return
            }

            remaining -= TimeInterval(dt)
            maybeGreet(now)
            maybeVisit(now)
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
        let vx = m.x - cx, vyy = m.y - (cy - 20 * scale)
        let dist = hypot(vx, vyy)
        let ux = dist > 1 ? vx / dist : 0, uy = dist > 1 ? vyy / dist : 0
        let a = view.angle
        let strength = min(1, dist / 150) * 2.6
        view.gaze = CGPoint(x: (ux * cos(a) + uy * sin(a)) * strength,
                            y: (-ux * sin(a) + uy * cos(a)) * strength)
        view.facing = facing

        // Hide and peek: slide past the screen edge until only half the face shows.
        let hidden = action == .hide && hidePhase == .hidden
        hideShift += ((hidden ? hideSide * (reach + 2 * scale) : 0) - hideShift) * min(1, dt * 9)
        if abs(hideShift) < 0.3, !hidden { hideShift = 0 }
        let origin = NSPoint(x: cx - half + hideShift, y: cy - half)
        if origin != window.frame.origin { window.setFrameOrigin(origin) }     // moving a window isn't free
        view.needsDisplay = true

        if bubble.visible {
            let k = scale
            let head = (species.headRoom + view.outfit.headRoom) * k
            switch surface {
            case .ceiling:
                bubble.update(centerX: cx, aboveY: cy + 46 * k, belowY: cy - 4 * k - head - 2, preferBelow: true, limit: f)
            case .leftWall, .rightWall:
                bubble.update(centerX: cx, aboveY: cy + 46 * k, belowY: cy - 46 * k, preferBelow: false, limit: f)
            default:
                bubble.update(centerX: cx, aboveY: cy + 4 * k + head + 2, belowY: cy - 60 * k, preferBelow: false, limit: f)
            }
        }
    }

    // MARK: Awareness (once a second)

    private func slowTick(_ now: Date) {
        let elapsed = now.timeIntervalSince(lastSlow)
        guard elapsed >= 1 else { return }
        lastSlow = now

        // Needs drift: resting restores energy, running about burns it.
        let exertion: Double
        switch action {
        case .zoomies, .dance, .chase: exertion = 3
        case .walk: exertion = 1.2
        default: exertion = ball != nil ? 3 : 0.7
        }
        let step = min(elapsed, 5)
        if isMain {
            mind.tick(step, asleep: action == .sleep, exertion: exertion, personality: species.personality)
            if media == .music, action != .sleep { mind.enjoyedMusic(step) }
            if let end = focusEnds, now >= end { finishFocus() }
        }

        // What's playing?
        let m = settings.reactToMedia ? audio.current : .none
        if m != media { media = m; mediaChanged() }

        // Is anyone there?
        let idle = SystemInfo.userIdleSeconds()
        if idle > 180, !userAway {
            userAway = true
            if canAct { action = .sleep; remaining = 600 }
        } else if userAway, idle < 5 {
            userAway = false
            welcomeBack()
        }

        guard isMain else { return }              // everything below is the main pet's job
        log.tick(step, userActive: idle < 60)

        // Been working a long time?
        if idle < 60 { activeSeconds += step } else if idle > 300 { activeSeconds = 0 }
        if settings.breakReminders, activeSeconds >= 50 * 60, media != .call, focusEnds == nil {
            activeSeconds = 0
            lastReminder = now
            say("You've been at it for a while. Time to stretch! 🧘", force: true)
            if canAct { apply(Decision(action: .stretch, duration: 3)) }
        }
        checkReminders(step, idle: idle, now)
        checkCalendar(now)

        if settings.systemAware { checkHour(); checkBattery(now); checkLoad(now) }
        else { view.sweat = false; view.shiver = false }
    }

    private func mediaChanged() {
        switch media {
        case .music, .other:
            view.musicBpm = .random(in: 100...126)
            if !isMain {}
            else if media == .music { say("Ooh, music! 🎵") }
            else if Bool.random() { say("Something's playing… 🎧") }
            if canAct, !userAway { apply(Decision(action: .dance, duration: 7)) }
        case .video:
            view.musicBpm = 0
            if isMain { say("Movie time! 🍿") }
            if canAct, !userAway { apply(Decision(action: .idle, duration: 5)) }
        case .call:
            view.musicBpm = 0
            if isMain { say("Shh… I'll be quiet 🤫", force: true) }
            if canAct, !userAway { apply(Decision(action: .idle, duration: 5)) }
        case .none:
            if view.musicBpm > 0, isMain { say("Aww, the music stopped 🥲") }
            view.musicBpm = 0
        }
    }

    private func welcomeBack() {
        guard isMain else { return }
        log.tookBreak()
        say("Welcome back! 👋")
        view.spawnHearts(3)
        if canAct { apply(Decision(action: .happy, duration: 2)) }
    }

    private func checkHour() {
        let h = hour
        defer { lastHour = h }
        guard lastHour != -1, h != lastHour else { return }
        switch h {
        case 12: say("Lunch time! 🍱")
        case 17: say("Almost done for the day? 🌇")
        case 18: if settings.dailyCheckIn { say(log.current.summary(prefix: "Today"), seconds: 7) }
        case 22: say("Getting late… bedtime soon? 🌙")
        case 0: say("It's past midnight! Time to sleep? 😴")
        default: break
        }
    }

    private func checkBattery(_ now: Date) {
        guard now.timeIntervalSince(lastBattery) >= 30 else { return }
        lastBattery = now
        guard let b = SystemInfo.battery() else { return }
        if let was = wasCharging, !was, b.charging {
            say("Ahh, power! ⚡")
            view.spawnHearts(2)
        }
        wasCharging = b.charging
        if b.level <= 15, !b.charging, !batteryWarned {
            batteryWarned = true
            say("Battery's at \(b.level)%. Plug me in? 🔋", force: true)
        }
        if b.charging || b.level > 30 { batteryWarned = false }
        view.shiver = b.level <= 10 && !b.charging      // running on fumes
    }

    /// Busy Mac: sweat while the processor is flat out, and say so if it goes on.
    private func checkLoad(_ now: Date) {
        let gap = now.timeIntervalSince(lastCPUCheck)
        guard gap >= 5 else { return }
        lastCPUCheck = now
        guard let cur = SystemInfo.cpuTicks() else { return }
        defer { lastCPU = cur }
        guard let prev = lastCPU, cur.total > prev.total else { return }
        let load = (cur.busy - prev.busy) / (cur.total - prev.total)

        busySeconds = load > 0.8 ? busySeconds + gap : 0
        view.sweat = busySeconds >= 10
        if busySeconds >= 25, now > busyCooldown, canAct, action != .sleep {
            busyCooldown = now.addingTimeInterval(600)
            say(Dialogue.busyMac.randomElement() ?? "Phew!")
        }
        let state = ProcessInfo.processInfo.thermalState
        if state == .serious || state == .critical {
            view.sweat = true
            if now > hotCooldown {
                hotCooldown = now.addingTimeInterval(900)
                say(Dialogue.hotMac.randomElement() ?? "It's warm in here!")
            }
        }
    }

    // MARK: Gentle reminders and calendar

    /// Each reminder counts time you are actually at the Mac, and waits for calls and focus sessions to end.
    private func checkReminders(_ dt: TimeInterval, idle: TimeInterval, _ now: Date) {
        if idle > 300 { reminderElapsed.removeAll(); return }     // you stepped away: start over
        guard idle < 60 else { return }
        for kind in ReminderKind.allCases {
            guard let every = settings.interval(kind) else { reminderElapsed[kind] = nil; continue }
            reminderElapsed[kind, default: 0] += dt
            guard reminderElapsed[kind, default: 0] >= TimeInterval(every * 60),
                  now.timeIntervalSince(lastReminder) > 120,          // never two nudges back to back
                  media != .call, focusEnds == nil, !userAway else { continue }
            reminderElapsed[kind] = 0
            lastReminder = now
            say(Dialogue.reminder(kind).randomElement() ?? kind.label, force: true, seconds: 6)
            if canAct, action != .sleep {
                switch kind {
                case .water: apply(Decision(action: .happy, duration: 1.6))
                case .posture: apply(Decision(action: .stretch, duration: 2.6))
                case .eyes: apply(Decision(action: .lookAround, duration: 3))
                }
            }
        }
    }

    private func checkCalendar(_ now: Date) {
        guard settings.calendarAlerts, now.timeIntervalSince(lastCalendarCheck) >= 30 else { return }
        lastCalendarCheck = now
        guard let alert = calendar.due(now: now).first else { return }
        say(Dialogue.meeting(alert.title, minutes: alert.minutes), force: true, seconds: 7)
        if canAct { apply(Decision(action: .happy, duration: 2)) }
    }

    /// Turns calendar alerts on, asking macOS for access the first time. `done(false)` means access was refused.
    func enableCalendar(_ done: @escaping (Bool) -> Void) { calendar.requestAccess(done) }

    // MARK: Cursor interactions

    private func trackCursor(_ dt: CGFloat, _ now: Date) {
        let m = NSEvent.mouseLocation
        let delta = CGPoint(x: m.x - lastMouse.x, y: m.y - lastMouse.y)
        lastMouse = m

        // Shaking the mouse hard near the pet makes it dizzy.
        if hypot(delta.x, delta.y) / max(dt, 0.001) > 700 {
            if delta.x * lastMouseDelta.x + delta.y * lastMouseDelta.y < 0 { shake += 1 }
            lastMouseDelta = delta
        }
        shake = max(0, shake - dt * 1.5)

        let dist = hypot(m.x - cx, m.y - (cy - 20 * scale))
        let calm = canAct && !userAway
        if shake >= 5, dist < 350, calm, now > dizzyCooldown {
            shake = 0
            dizzyCooldown = now.addingTimeInterval(15)
            apply(Decision(action: .dizzy, duration: 2.8))
            say("Whoa… everything's spinning 😵‍💫")
        }

        // Hovering the cursor over the pet without clicking gets a happy reaction.
        if calm, dist < 48 * scale, action != .sleep, action != .dizzy {
            hoverTime += dt
            if hoverTime > 1.2, !hoverReacted {
                hoverReacted = true
                view.spawnHearts(2)
                say(Dialogue.hover.randomElement() ?? "Hi!")
                action = .happy
                remaining = 1.2
            }
        } else if dist > 60 * scale {
            hoverTime = 0
            hoverReacted = false
        }
    }

    // MARK: Typing along

    private func trackTyping(_ dt: CGFloat, _ now: Date) {
        let count = SystemInfo.keyPressCount()
        let keys = count >= keyCount ? Double(count - keyCount) : 0
        keyCount = count
        guard settings.reactToTyping else {
            typingRate = 0; typingStreak = 0; fastTyping = 0
            return
        }
        let t = Double(dt)
        typingRate += (keys / t - typingRate) * min(1, t * 1.5)
        if keys > 0 {
            lastKey = now
            view.tap = 1                           // bop along with each key
        }

        // A streak survives short thinking pauses and ends after a real break.
        let pause = now.timeIntervalSince(lastKey)
        if pause < 2.5 { typingStreak += t; if isMain { log.typed(t) } }
        else if pause > 8 { typingStreak = 0; nextTypingCheer = 60 }
        fastTyping = typingRate > 7 ? fastTyping + t : max(0, fastTyping - t)

        guard isMain, canAct, !userAway, action != .sleep, treat == nil, ball == nil else { return }
        if fastTyping > 4, now > fastCheerAfter {
            fastTyping = 0
            fastCheerAfter = now.addingTimeInterval(180)
            say(Dialogue.typingFast.randomElement() ?? "Speedy!")
            action = .happy
            remaining = 1.4
        } else if typingStreak >= nextTypingCheer {
            // Cheer at one minute, at five, then every ten.
            let long = nextTypingCheer >= 300
            nextTypingCheer = nextTypingCheer < 300 ? 300 : nextTypingCheer + 600
            view.spawnHearts(2)
            say((long ? Dialogue.typingLong : Dialogue.typingRoll).randomElement() ?? "Nice!")
        }
    }

    // MARK: Treats

    /// Returns true while the pet is busy with the treat.
    private func handleTreat(_ t: Treat, _ dt: CGFloat, _ f: NSRect) -> Bool {
        // Treats land on the Dock floor: come down from walls, the ceiling or windows first.
        if surface != .floor {
            letGo()
            return true
        }
        if platform.id != 0 {
            surface = .air
            vy = 0
            cx += (t.x >= cx ? 1 : -1) * 30
            return true
        }
        let dx = t.x - cx
        if t.landed, abs(dx) < 28 {
            t.remove()
            treat = nil
            mind.fed()
            log.gaveTreat()
            view.spawnHearts(4)
            say(Dialogue.yum.randomElement() ?? "Yum!", force: true)
            apply(Decision(action: .happy, duration: 2.2))
            return true
        }
        if abs(dx) > 12 {
            facing = dx > 0 ? 1 : -1
            view.mood = .chase
            cx += facing * chaseSpeed * 1.1 * dt
        } else {
            view.mood = .idle
        }
        snap(f)
        targetAngle = 0
        return true
    }

    // MARK: Playing ball

    /// Returns true while the pet is busy with the ball.
    private func handleBall(_ b: Ball, _ dt: CGFloat, _ f: NSRect, _ now: Date) -> Bool {
        // The ball bounces along the Dock floor: come down from walls, the ceiling or windows first.
        if surface != .floor {
            letGo()
            return true
        }
        if platform.id != 0 {
            surface = .air
            vy = 0
            cx += (b.x >= cx ? 1 : -1) * 30
            return true
        }
        if b.kicks >= 6 || now.timeIntervalSince(b.born) > 30 {
            endBall(celebrate: true)
            return true
        }
        let dx = b.x - cx
        if abs(dx) < 32, b.canKick {
            // Kick it away, but back towards the middle when it is near a screen edge.
            var dir: CGFloat = dx >= 0 ? 1 : -1
            if b.x < f.minX + 220 { dir = 1 } else if b.x > f.maxX - 220 { dir = -1 }
            b.kick(vx: dir * .random(in: 240...440), vy: .random(in: 420...640))
            facing = dir
            view.mood = .happy
            if now.timeIntervalSince(lastKickLine) > 2.5 {
                lastKickLine = now
                say(Dialogue.kick.randomElement() ?? "Boing!")
            }
        } else if abs(dx) > 14 {
            facing = dx > 0 ? 1 : -1
            view.mood = .chase
            cx += facing * chaseSpeed * 1.25 * dt
        } else {
            view.mood = .idle
        }
        snap(f)
        targetAngle = 0
        return true
    }

    private func endBall(celebrate: Bool) {
        guard let b = ball else { return }
        b.remove()
        ball = nil
        guard celebrate else { return }
        mind.played()
        log.played()
        view.spawnHearts(4)
        say(Dialogue.playedEnough.randomElement() ?? "That was fun!", force: true)
        action = .happy
        remaining = 2.2
    }

    // MARK: Falling & landing

    private func fall(_ dt: CGFloat, _ f: NSRect) {
        let prevFeet = cy - reach
        vy -= 1800 * dt
        cy += vy * dt
        if thrown {
            // Tumble through the air and bounce off the sides and the top of the screen.
            cx += vx * dt
            view.spin -= vx * dt * 0.012
            if cx < f.minX + reach { cx = f.minX + reach; vx = abs(vx) * 0.6 }
            if cx > f.maxX - reach { cx = f.maxX - reach; vx = -abs(vx) * 0.6 }
            if cy > f.maxY - reach { cy = f.maxY - reach; vy = -abs(vy) * 0.5 }
        }
        let newFeet = cy - reach
        cx = clamp(cx, f.minX + reach, f.maxX - reach)
        view.mood = .held
        targetAngle = 0

        let hits = allPlatforms(f).filter { p in
            let inside = p.id == 0 || (cx >= p.minX && cx <= p.maxX)
            return inside && prevFeet >= p.top - 1 && newFeet <= p.top
        }
        if let best = hits.max(by: { $0.top < $1.top }) { land(on: best, f) }
    }

    private func land(on p: Platform, _ f: NSRect) {
        if thrown {
            if abs(vy) > 420, bounces < 3 {
                // Still going fast: bounce.
                bounces += 1
                vy = abs(vy) * 0.45
                vx *= 0.7
                cy = p.top + reach + 1
                return
            }
            thrown = false
            vx = 0
            view.spin = 0
            platform = p
            surface = .floor
            vy = 0
            cx = clamp(cx, p.minX, p.maxX)
            cy = p.top + reach
            action = .dizzy
            remaining = 2.4
            targetAngle = 0
            say(Dialogue.crashLanded.randomElement() ?? "Whoa…", force: true)
            return
        }
        platform = p
        surface = .floor
        vy = 0
        cx = clamp(cx, p.minX, p.maxX)
        cy = p.top + reach
        if slipped {
            slipped = false
            say(Dialogue.ouch.randomElement() ?? "Ow!", force: true)
        } else if p.id != 0, Double.random(in: 0..<1) < 0.5 {
            say(Dialogue.landedWindow.randomElement() ?? "Nice!")
        }
        action = .idle
        remaining = 1.5
        targetAngle = 0
    }

    private func startLeap() -> Bool {
        let feet = cy - reach
        guard let p = windowPlatforms.filter({ reachable($0, feet: feet) }).randomElement() else { return false }
        let end = CGPoint(x: clamp(cx, p.minX, p.maxX), y: p.top + reach)
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

    private func startSlip() {
        slipTimer = 0.8
        slipped = true
        say(Dialogue.slipping.randomElement() ?? "Uh oh…", force: true)
    }

    private func letGo() {
        if surface == .leftWall { cx += 10 } else if surface == .rightWall { cx -= 10 }
        surface = .air
        vy = 0
        gripTime = 0
    }

    // MARK: Dragging

    private func dragBegan() {
        held = true
        jump = nil
        thrown = false
        vx = 0
        dragVelocity = .zero
        hidePhase = .none
        slipTimer = 0
        slipped = false
        gripTime = 0
        view.spin = 0
        touch()
        if Double.random(in: 0..<1) < 0.35 { say(Dialogue.dragged.randomElement() ?? "Wheee!", force: true) }
    }

    private func dragEnded() {
        held = false
        let f = screenFrame
        cx = window.frame.midX
        cy = window.frame.midY
        vy = 0
        gripTime = 0

        // Let go mid-swing and the pet goes flying.
        if hypot(dragVelocity.x, dragVelocity.y) > 650 {
            thrown = true
            bounces = 0
            vx = clamp(dragVelocity.x, -2400, 2400)
            vy = clamp(dragVelocity.y, -2400, 2600)
            cx = clamp(cx, f.minX + reach, f.maxX - reach)
            cy = min(cy, f.maxY - reach)
            surface = .air
            say(Dialogue.thrown.randomElement() ?? "Wheee!", force: true)
            return
        }

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
            cx = clamp(cx, f.minX + reach, f.maxX - reach)
            cy = min(cy, f.maxY - reach)
            surface = .air
        }
    }

    // MARK: Behavior

    private func touch() { lastInteraction = Date() }

    private func apply(_ d: Decision, forceSay: Bool = false) {
        action = d.action
        remaining = d.duration
        forceClimb = false
        hidePhase = .none
        if let line = d.line { say(line) }
        switch d.action {
        case .walk(let axis):
            facing = map(axis, surface)
        case .chase where !settings.followCursor:
            action = .idle
        case .leap:
            if !startLeap() { action = .idle; remaining = 1.5 }
        case .climbEdge:
            if surface == .floor, platform.id == 0, settings.climbEdges {
                let toLeft = (cx - platform.minX) < (platform.maxX - cx)
                let axis: CGFloat = toLeft ? -1 : 1
                facing = map(axis, surface)
                action = .walk(axis: axis)
                forceClimb = true
            } else {
                action = .idle
                remaining = 1.5
            }
        case .hide:
            if surface == .floor, platform.id == 0, NSScreen.screens.count == 1 {
                hideSide = (cx - platform.minX) < (platform.maxX - cx) ? -1 : 1
                facing = hideSide
                hidePhase = .going
            } else {
                action = .idle
                remaining = 1.5
            }
        case .greet:
            say(greetingLine(), force: forceSay)
        case .stretch:
            if Double.random(in: 0..<1) < 0.5 { say("*yaaawn*") }
        case .dance:
            if media == .none, Double.random(in: 0..<1) < 0.5 { say("♪ La la la ♪") }
        case .zoomies:
            if Double.random(in: 0..<1) < 0.5 { say("Zoomies!!") }
        default:
            break
        }
        view.spin = 0
    }

    private func greetingLine() -> String {
        Dialogue.greeting(species: species, hour: hour, bondLevel: mind.level, days: mind.daysTogether)
    }

    private func scheduleGreeting(_ now: Date) {
        if let r = settings.chattiness.interval {
            // A companion chimes in about half as often as the main pet.
            nextGreeting = now.addingTimeInterval(.random(in: r) * (isMain ? 1 : 2.2))
        } else {
            nextGreeting = now.addingTimeInterval(60)
        }
    }

    private func maybeGreet(_ now: Date) {
        guard now >= nextGreeting else { return }
        scheduleGreeting(now)
        if settings.chattiness != .off, action != .sleep, !bubble.visible, media != .call, media != .video, !userAway, !focusing {
            apply(Decision(action: .greet, duration: 2.2))
        }
    }

    func say(_ text: String, force: Bool = false, seconds: TimeInterval = 3.6) {
        guard force || settings.chattiness != .off else { return }
        if (media == .call || focusing) && !force { return }   // quiet during calls and focus sessions
        bubble.say(text, for: seconds)
    }

    private func behave(_ dt: CGFloat, _ f: NSRect) {
        switch action {
        case .idle, .leap, .climbEdge:
            view.mood = .idle
            lookAtCursor()
        case .sleep:
            view.mood = .sleep
        case .happy, .greet:
            view.mood = .happy
        case .walk:
            view.mood = .walk
            advance(species.walkSpeed * dt, autonomous: true, f)
        case .chase:
            chase(dt, f)
        case .stretch:
            view.mood = .stretch
        case .dance:
            view.mood = .dance
        case .spin:
            view.mood = .happy
            view.spin += 2 * .pi * dt / 0.9
        case .dizzy:
            view.mood = .dizzy
            view.spin = sin(view.time * 10) * 0.1
        case .mope:
            view.mood = .sad
        case .hide:
            hideAndPeek(dt, f)
        case .visit:
            visitBuddy(dt, f)
        case .lookAround:
            view.mood = .idle
            facing = sin(view.time * 2.5) > 0 ? 1 : -1
        case .zoomies:
            view.mood = .chase
            if Double.random(in: 0..<1) < 0.03 { turnAround() }
            advance(species.walkSpeed * 3.5 * dt, autonomous: true, f)
        }
        snap(f)
    }

    // MARK: Hide and peek

    private func hideAndPeek(_ dt: CGFloat, _ f: NSRect) {
        switch hidePhase {
        case .going:
            view.mood = .walk
            advance(species.walkSpeed * 1.4 * dt, autonomous: true, f)   // floorEnd() ducks behind the edge
        case .hidden:
            view.mood = .idle
            facing = -hideSide
            let m = NSEvent.mouseLocation
            // Pop out when you come looking, or when it gets bored of waiting.
            if hypot(m.x - cx, m.y - cy) < 190 || remaining < 1.7 {
                hidePhase = .none
                action = .happy
                remaining = 1.6
                view.spawnHearts(2)
                say(Dialogue.peekaboo.randomElement() ?? "Peekaboo!")
            }
        case .none:
            view.mood = .idle
        }
    }

    // MARK: Two pets

    /// Now and then, run over to the other pet to say hi.
    private func maybeVisit(_ now: Date) {
        guard now >= nextVisit else { return }
        nextVisit = now.addingTimeInterval(.random(in: 45...120))
        guard let b = buddy, canAct, b.canAct, action != .sleep, b.action != .sleep, !userAway,
              media != .call, !focusing, treat == nil, ball == nil, b.treat == nil, b.ball == nil,
              surface == .floor, b.surface == .floor, platform.id == b.platform.id else { return }
        apply(Decision(action: .visit, duration: 9))
    }

    private func visitBuddy(_ dt: CGFloat, _ f: NSRect) {
        guard let b = buddy, b.surface == .floor, b.platform.id == platform.id, b.canAct else {
            action = .idle
            remaining = 1
            return
        }
        let d = b.cx - cx
        if abs(d) > 64 * scale {
            facing = d > 0 ? 1 : -1
            view.mood = .chase
            advance(chaseSpeed * 0.85 * dt, autonomous: false, f)
            return
        }
        // Met up: both are delighted.
        facing = d > 0 ? 1 : -1
        action = .happy
        remaining = 2
        view.spawnHearts(3)
        say(Dialogue.buddyHello(b.species.name).randomElement() ?? "Hi!")
        b.greeted(from: cx)
        mind.reunitedWithBuddy()
    }

    /// The other pet just ran over to say hi.
    private func greeted(from x: CGFloat) {
        guard canAct, action != .sleep else { return }
        facing = x > cx ? 1 : -1
        action = .happy
        remaining = 2
        view.spawnHearts(3)
        nextVisit = max(nextVisit, Date().addingTimeInterval(40))
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
            let left = cx <= f.minX + reach && s < 0
            let right = cx >= f.maxX - reach && s > 0
            if left || right {
                if Double.random(in: 0..<1) < 0.7 {
                    surface = left ? .leftWall : .rightWall
                    facing = map(-1, surface)              // head down the wall
                    snap(f)
                } else { turnAround() }
            }

        case .leftWall, .rightWall:
            if cy >= f.maxY - reach && s > 0 {
                if Double.random(in: 0..<1) < 0.7 {
                    surface = .ceiling
                    facing = map(was == .leftWall ? 1 : -1, .ceiling)
                    snap(f)
                } else { turnAround() }
            } else if cy <= f.minY + reach && s < 0 {
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
        if hidePhase == .going {
            hidePhase = .hidden                             // reached the edge: duck behind it
            remaining = .random(in: 6...10)
            return
        }
        if platform.id == 0 {
            if settings.climbEdges && (forceClimb || Double.random(in: 0..<1) < 0.5) {
                forceClimb = false
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
        case .ceiling: frac = (cx - (f.minX + reach)) / max(1, f.width - 2 * reach)
        case .leftWall, .rightWall: frac = (cy - (f.minY + reach)) / max(1, f.height - 2 * reach)
        case .air: frac = 0.5
        }
        let m = NSEvent.mouseLocation
        let feet = cy - reach
        return PetContext(surface: surface,
                          axisFraction: frac,
                          cursorDistance: hypot(m.x - cx, m.y - cy),
                          secondsSinceInteraction: Date().timeIntervalSince(lastInteraction),
                          hour: hour,
                          platformAbove: surface == .floor && windowPlatforms.contains { reachable($0, feet: feet) },
                          canClimb: surface == .floor && platform.id == 0 && settings.climbEdges,
                          canHide: surface == .floor && platform.id == 0 && NSScreen.screens.count == 1,
                          media: media,
                          userAway: userAway,
                          focusing: focusing,
                          species: species,
                          energy: mind.energy,
                          fullness: mind.fullness,
                          joy: mind.joy,
                          bondLevel: mind.level)
    }
}
