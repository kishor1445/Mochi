import AppKit

/// Once-a-second awareness: needs, media, idle, battery, load, reminders and calendar.
extension PetController {
    func slowTick(_ now: Date) {
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

    func mediaChanged() {
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

    func welcomeBack() {
        guard isMain else { return }
        log.tookBreak()
        say("Welcome back! 👋")
        view.spawnHearts(3)
        if canAct { apply(Decision(action: .happy, duration: 2)) }
    }

    func checkHour() {
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

    func checkBattery(_ now: Date) {
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
    func checkLoad(_ now: Date) {
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
    func checkReminders(_ dt: TimeInterval, idle: TimeInterval, _ now: Date) {
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

    func checkCalendar(_ now: Date) {
        guard settings.calendarAlerts, now.timeIntervalSince(lastCalendarCheck) >= 30 else { return }
        lastCalendarCheck = now
        guard let alert = calendar.due(now: now).first else { return }
        say(Dialogue.meeting(alert.title, minutes: alert.minutes), force: true, seconds: 7)
        if canAct { apply(Decision(action: .happy, duration: 2)) }
    }

    /// Turns calendar alerts on, asking macOS for access the first time. `done(false)` means access was refused.
    func enableCalendar(_ done: @escaping (Bool) -> Void) { calendar.requestAccess(done) }
}
