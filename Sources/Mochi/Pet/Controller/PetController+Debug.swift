import AppKit

/// Things the Debug page can ask the pet to do.
enum DebugAction {
    case reminder(ReminderKind)
    case stretch
    case calendar
    case checkIn
    case skip(minutes: Int)         // move every reminder clock forward
    case meet(SocialKind)
}

/// Live state for the Debug settings page, refreshed once a second by the main pet.
final class PetDebug: ObservableObject {
    static let shared = PetDebug()

    /// "Next in 12:34", "Off"… keyed by reminder (`ReminderKind.rawValue`, or "stretch").
    @Published var reminders: [String: String] = [:]
    @Published var reminderState = "Starting…"
    @Published var presence = ""
    @Published var sound = ""
    @Published var soundApps: [String] = []
    @Published var pets = ""

    var fire: ((DebugAction) -> Void)?
}

extension PetController {
    func debug(_ a: DebugAction) {
        touch()
        switch a {
        case .reminder(let kind):
            fireReminder(kind)
        case .stretch:
            fireStretch()
        case .calendar:
            say(Dialogue.meeting("Design review", minutes: 5), force: true, seconds: 7)
            if canAct { apply(Decision(action: .happy, duration: 2)) }
        case .checkIn:
            checkIn()
        case .skip(let minutes):
            let jump = TimeInterval(minutes * 60)
            for kind in ReminderKind.allCases where settings.interval(kind) != nil {
                reminderElapsed[kind, default: 0] += jump
            }
            activeSeconds += jump
            lastReminder = .distantPast
        case .meet(let kind):
            guard buddy != nil else { return }
            forcedSocial = kind
            social = .none
            nextVisit = Date()
        }
        publishDebug(idle: SystemInfo.userIdleSeconds(), Date())
    }

    func publishDebug(idle: TimeInterval, _ now: Date) {
        guard isMain else { return }
        let d = PetDebug.shared

        func countdown(_ elapsed: TimeInterval, _ minutes: Int) -> String {
            let left = Int(TimeInterval(minutes * 60) - elapsed)
            if left <= 0 { return "Due now" }
            return String(format: "Next in %d:%02d", left / 60, left % 60)
        }
        var r: [String: String] = [:]
        for kind in ReminderKind.allCases {
            if let every = settings.interval(kind) {
                r[kind.rawValue] = countdown(reminderElapsed[kind] ?? 0, every)
            } else {
                r[kind.rawValue] = "Off"
            }
        }
        r["stretch"] = settings.breakReminders ? countdown(activeSeconds, settings.breakMinutes) : "Off"
        d.reminders = r

        if let why = remindersBlocked { d.reminderState = "Held back: \(why)" }
        else if idle >= 300 { d.reminderState = "Paused: no input for \(Int(idle / 60)) min" }
        else { d.reminderState = "Counting" }

        d.presence = userAway ? "Away (no input for \(Int(idle / 60)) min)" : "Here, last input \(Int(idle))s ago"

        let heard = audio.current
        var sound = AudioWatcher.name(heard)
        if heard != media {
            sound += settings.reactToMedia ? " (ignored: other sound is switched off in Behavior)" : " (ignored: reactions are off)"
        }
        d.sound = sound
        d.soundApps = audio.sources

        if let b = buddy {
            let mine = social == .none ? "free" : "\(socialKind.label.lowercased()) (\(social))"
            let wait = max(0, Int(min(nextVisit, b.nextVisit).timeIntervalSince(now)))
            d.pets = "\(species.name): \(mine) · \(b.species.name): \(b.social == .none ? "free" : "\(b.social)") · next try in \(wait)s"
        } else {
            d.pets = "Second pet is off (turn it on in Pet)"
        }
    }
}
