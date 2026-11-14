import AppKit

/// The pets you can choose from. Add a new case + a drawing branch in PetView to add another.
enum Species: String, CaseIterable, Identifiable {
    case mochi, penguin, ghost

    var id: String { rawValue }

    var name: String {
        switch self {
        case .mochi: return "Mochi"
        case .penguin: return "Pip"
        case .ghost: return "Boo"
        }
    }

    var tagline: String {
        switch self {
        case .mochi: return "Squishy & sleepy"
        case .penguin: return "Waddly & dapper"
        case .ghost: return "Floaty & friendly"
        }
    }

    var emoji: String {
        switch self {
        case .mochi: return "🍡"
        case .penguin: return "🐧"
        case .ghost: return "👻"
        }
    }

    /// Favourite snack, used by "Give a treat".
    var treatEmoji: String {
        switch self {
        case .mochi: return "🍡"
        case .penguin: return "🐟"
        case .ghost: return "🍬"
        }
    }

    var walkSpeed: CGFloat {
        switch self {
        case .mochi: return 55
        case .penguin: return 48
        case .ghost: return 62
        }
    }

    /// How high the walk-bounce is.
    var hopFactor: CGFloat {
        switch self {
        case .mochi: return 1
        case .penguin: return 0.4
        case .ghost: return 0.3
        }
    }

    /// Pixels the head decoration sticks out above the body (used to place the speech bubble).
    var headRoom: CGFloat {
        switch self {
        case .mochi: return 14
        case .penguin: return 10
        case .ghost: return 10
        }
    }

    var fur: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 1.00, green: 0.97, blue: 0.94, alpha: 1)
        case .penguin: return NSColor(calibratedRed: 0.24, green: 0.31, blue: 0.48, alpha: 1)
        case .ghost: return NSColor(calibratedRed: 0.96, green: 0.96, blue: 1.00, alpha: 1)
        }
    }

    var outline: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 0.36, green: 0.26, blue: 0.27, alpha: 1)
        case .penguin: return NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.25, alpha: 1)
        case .ghost: return NSColor(calibratedRed: 0.46, green: 0.46, blue: 0.74, alpha: 1)
        }
    }

    var accent: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 1.00, green: 0.60, blue: 0.65, alpha: 1)
        case .penguin: return NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.68, alpha: 1)
        case .ghost: return NSColor(calibratedRed: 1.00, green: 0.66, blue: 0.80, alpha: 1)
        }
    }

    var ink: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 0.22, green: 0.16, blue: 0.18, alpha: 1)
        case .penguin: return NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.14, alpha: 1)
        case .ghost: return NSColor(calibratedRed: 0.20, green: 0.18, blue: 0.30, alpha: 1)
        }
    }

    var foot: NSColor {
        switch self {
        case .penguin: return NSColor(calibratedRed: 1.00, green: 0.66, blue: 0.24, alpha: 1)
        default: return fur
        }
    }

    var footOutline: NSColor {
        switch self {
        case .penguin: return NSColor(calibratedRed: 0.72, green: 0.40, blue: 0.10, alpha: 1)
        default: return outline
        }
    }

    /// Things this pet likes to say.
    var lines: [String] {
        switch self {
        case .mochi: return ["Squish!", "Mochi mochi~", "Boop!", "I'm a rice cake, not a snack!", "Squish me gently."]
        case .penguin: return ["Waddle waddle!", "Is it cold in here? 🧊", "Fish? 🐟", "I'm a very important penguin.", "Slide time!"]
        case .ghost: return ["Boo! 👻", "Did I scare you? …Did I?", "Whooo's there?", "Just floating around.", "Spooky vibes only."]
        }
    }
}
