import AppKit

/// The pets you can choose from. Add a new case + a drawing branch in PetView to add another.
enum Species: String, CaseIterable, Identifiable {
    case mochi, cat, bunny, penguin, ghost

    var id: String { rawValue }

    var name: String {
        switch self {
        case .mochi: return "Mochi"
        case .cat: return "Miso"
        case .bunny: return "Clover"
        case .penguin: return "Pip"
        case .ghost: return "Boo"
        }
    }

    var tagline: String {
        switch self {
        case .mochi: return "Squishy & sleepy"
        case .cat: return "Curious & sneaky"
        case .bunny: return "Bouncy & sweet"
        case .penguin: return "Waddly & dapper"
        case .ghost: return "Floaty & friendly"
        }
    }

    var emoji: String {
        switch self {
        case .mochi: return "🍡"
        case .cat: return "🐱"
        case .bunny: return "🐰"
        case .penguin: return "🐧"
        case .ghost: return "👻"
        }
    }

    /// Favourite snack, used by "Give a treat".
    var treatEmoji: String {
        switch self {
        case .mochi: return "🍡"
        case .cat: return "🥛"
        case .bunny: return "🥕"
        case .penguin: return "🐟"
        case .ghost: return "🍬"
        }
    }

    var walkSpeed: CGFloat {
        switch self {
        case .mochi: return 55
        case .cat: return 75
        case .bunny: return 62
        case .penguin: return 48
        case .ghost: return 62
        }
    }

    /// How high the walk-bounce is.
    var hopFactor: CGFloat {
        switch self {
        case .mochi: return 1
        case .cat: return 0.6
        case .bunny: return 1.6
        case .penguin: return 0.4
        case .ghost: return 0.3
        }
    }

    /// Pixels the ears / sprout / headphones stick out above the body (used to place the speech bubble).
    var headRoom: CGFloat {
        switch self {
        case .mochi: return 14
        case .cat: return 18
        case .bunny: return 38
        case .penguin: return 10
        case .ghost: return 10
        }
    }

    var fur: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 1.00, green: 0.97, blue: 0.94, alpha: 1)
        case .cat: return NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.42, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.99, alpha: 1)
        case .penguin: return NSColor(calibratedRed: 0.24, green: 0.31, blue: 0.48, alpha: 1)
        case .ghost: return NSColor(calibratedRed: 0.96, green: 0.96, blue: 1.00, alpha: 1)
        }
    }

    var outline: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 0.36, green: 0.26, blue: 0.27, alpha: 1)
        case .cat: return NSColor(calibratedRed: 0.45, green: 0.27, blue: 0.15, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 0.42, green: 0.36, blue: 0.46, alpha: 1)
        case .penguin: return NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.25, alpha: 1)
        case .ghost: return NSColor(calibratedRed: 0.46, green: 0.46, blue: 0.74, alpha: 1)
        }
    }

    var accent: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 1.00, green: 0.60, blue: 0.65, alpha: 1)
        case .cat: return NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.66, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.80, alpha: 1)
        case .penguin: return NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.68, alpha: 1)
        case .ghost: return NSColor(calibratedRed: 1.00, green: 0.66, blue: 0.80, alpha: 1)
        }
    }

    var ink: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 0.22, green: 0.16, blue: 0.18, alpha: 1)
        case .cat: return NSColor(calibratedRed: 0.22, green: 0.12, blue: 0.08, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 0.20, green: 0.15, blue: 0.25, alpha: 1)
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
        case .cat: return ["Meow!", "Purr… 😺", "Feed me? 🐟", "I knocked something over. Oops.", "Nap time soon."]
        case .bunny: return ["*hop hop*", "Carrots? 🥕", "Binky! 🐰", "My ears heard that.", "Boing!"]
        case .penguin: return ["Waddle waddle!", "Is it cold in here? 🧊", "Fish? 🐟", "I'm a very important penguin.", "Slide time!"]
        case .ghost: return ["Boo! 👻", "Did I scare you? …Did I?", "Whooo's there?", "Just floating around.", "Spooky vibes only."]
        }
    }
}
