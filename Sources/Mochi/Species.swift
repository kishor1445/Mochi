import AppKit

/// The pets you can choose from. Add a new case + a drawing branch in PetView to add another.
enum Species: String, CaseIterable, Identifiable {
    case mochi, cat, bunny

    var id: String { rawValue }

    var name: String {
        switch self {
        case .mochi: return "Mochi"
        case .cat: return "Miso"
        case .bunny: return "Clover"
        }
    }

    var tagline: String {
        switch self {
        case .mochi: return "Squishy & sleepy"
        case .cat: return "Curious & sneaky"
        case .bunny: return "Bouncy & sweet"
        }
    }

    var emoji: String {
        switch self {
        case .mochi: return "🍡"
        case .cat: return "🐱"
        case .bunny: return "🐰"
        }
    }

    var walkSpeed: CGFloat {
        switch self {
        case .mochi: return 55
        case .cat: return 75
        case .bunny: return 62
        }
    }

    /// How high the walk-bounce is (bunnies hop).
    var hopFactor: CGFloat {
        switch self {
        case .mochi: return 1
        case .cat: return 0.6
        case .bunny: return 1.6
        }
    }

    /// Pixels the ears / sprout stick out above the body (used to place the speech bubble).
    var headRoom: CGFloat {
        switch self {
        case .mochi: return 12
        case .cat: return 16
        case .bunny: return 36
        }
    }

    var fur: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 1.00, green: 0.97, blue: 0.94, alpha: 1)
        case .cat: return NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.42, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.99, alpha: 1)
        }
    }

    var outline: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 0.36, green: 0.26, blue: 0.27, alpha: 1)
        case .cat: return NSColor(calibratedRed: 0.45, green: 0.27, blue: 0.15, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 0.42, green: 0.36, blue: 0.46, alpha: 1)
        }
    }

    var accent: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 1.00, green: 0.60, blue: 0.65, alpha: 1)
        case .cat: return NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.66, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.80, alpha: 1)
        }
    }

    var ink: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 0.22, green: 0.16, blue: 0.18, alpha: 1)
        case .cat: return NSColor(calibratedRed: 0.22, green: 0.12, blue: 0.08, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 0.20, green: 0.15, blue: 0.25, alpha: 1)
        }
    }

    /// Things this pet likes to say.
    var lines: [String] {
        switch self {
        case .mochi: return ["Squish!", "Mochi mochi~", "Boop!", "I'm a rice cake, not a snack!", "Squish me gently."]
        case .cat: return ["Meow!", "Purr… 😺", "Feed me? 🐟", "I knocked something over. Oops.", "Nap time soon."]
        case .bunny: return ["*hop hop*", "Carrots? 🥕", "Binky! 🐰", "My ears heard that.", "Boing!"]
        }
    }
}
