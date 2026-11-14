import AppKit

/// The pets you can choose from. Add a new case + a drawing branch in PetView to add another.
enum Species: String, CaseIterable, Identifiable {
    case mochi, cat, bunny, penguin, ghost, dino, robot, dragon

    var id: String { rawValue }

    var name: String {
        switch self {
        case .mochi: return "Mochi"
        case .cat: return "Miso"
        case .bunny: return "Clover"
        case .penguin: return "Pip"
        case .ghost: return "Boo"
        case .dino: return "Rex"
        case .robot: return "Bolt"
        case .dragon: return "Ember"
        }
    }

    var tagline: String {
        switch self {
        case .mochi: return "Squishy & sleepy"
        case .cat: return "Curious & sneaky"
        case .bunny: return "Bouncy & sweet"
        case .penguin: return "Waddly & dapper"
        case .ghost: return "Floaty & friendly"
        case .dino: return "Stompy & brave"
        case .robot: return "Beepy & clever"
        case .dragon: return "Fiery & bold"
        }
    }

    var emoji: String {
        switch self {
        case .mochi: return "🍡"
        case .cat: return "🐱"
        case .bunny: return "🐰"
        case .penguin: return "🐧"
        case .ghost: return "👻"
        case .dino: return "🦖"
        case .robot: return "🤖"
        case .dragon: return "🐲"
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
        case .dino: return "🍖"
        case .robot: return "🔋"
        case .dragon: return "🌶"
        }
    }

    /// Favourite toy, used by "Play ball".
    var toyEmoji: String {
        switch self {
        case .mochi: return "⚽️"
        case .cat: return "🧶"
        case .bunny: return "🥎"
        case .penguin: return "🏐"
        case .ghost: return "🎃"
        case .dino: return "🏈"
        case .robot: return "🏀"
        case .dragon: return "🔥"
        }
    }

    /// What makes this pet itself; `MindBrain` leans its choices by these.
    var personality: Personality {
        switch self {
        case .mochi: return Personality(playful: 0.8, sleepy: 1.5, curious: 0.8, cuddly: 1.3, appetite: 1.0)
        case .cat: return Personality(playful: 1.1, sleepy: 1.2, curious: 1.6, cuddly: 0.7, appetite: 1.1)
        case .bunny: return Personality(playful: 1.5, sleepy: 0.8, curious: 1.0, cuddly: 1.2, appetite: 1.3)
        case .penguin: return Personality(playful: 1.0, sleepy: 0.9, curious: 1.1, cuddly: 1.0, appetite: 1.4)
        case .ghost: return Personality(playful: 1.2, sleepy: 0.6, curious: 1.4, cuddly: 0.9, appetite: 0.6)
        case .dino: return Personality(playful: 1.4, sleepy: 0.9, curious: 1.2, cuddly: 0.9, appetite: 1.6)
        case .robot: return Personality(playful: 1.1, sleepy: 0.4, curious: 1.7, cuddly: 0.8, appetite: 0.7)
        case .dragon: return Personality(playful: 1.6, sleepy: 1.0, curious: 1.3, cuddly: 1.0, appetite: 1.2)
        }
    }

    var walkSpeed: CGFloat {
        switch self {
        case .mochi: return 55
        case .cat: return 75
        case .bunny: return 62
        case .penguin: return 48
        case .ghost: return 62
        case .dino: return 66
        case .robot: return 58
        case .dragon: return 70
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
        case .dino: return 1.2
        case .robot: return 0.3
        case .dragon: return 0.9
        }
    }

    /// Pixels the ears / sprout / headphones stick out above the body (used to place the speech bubble).
    var headRoom: CGFloat {
        switch self {
        case .mochi: return 22
        case .cat: return 18
        case .bunny: return 38
        case .penguin: return 14
        case .ghost: return 10
        case .dino: return 14
        case .robot: return 20
        case .dragon: return 18
        }
    }

    var fur: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 1.00, green: 0.97, blue: 0.94, alpha: 1)
        case .cat: return NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.42, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.99, alpha: 1)
        case .penguin: return NSColor(calibratedRed: 0.24, green: 0.31, blue: 0.48, alpha: 1)
        case .ghost: return NSColor(calibratedRed: 0.96, green: 0.96, blue: 1.00, alpha: 1)
        case .dino: return NSColor(calibratedRed: 0.58, green: 0.82, blue: 0.48, alpha: 1)
        case .robot: return NSColor(calibratedRed: 0.82, green: 0.87, blue: 0.94, alpha: 1)
        case .dragon: return NSColor(calibratedRed: 0.97, green: 0.52, blue: 0.42, alpha: 1)
        }
    }

    /// Soft tint along the bottom of the body.
    var shade: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.82, alpha: 0.75)
        case .cat: return NSColor(calibratedRed: 0.96, green: 0.58, blue: 0.30, alpha: 0.55)
        case .bunny: return NSColor(calibratedRed: 0.88, green: 0.82, blue: 0.96, alpha: 0.8)
        case .penguin: return NSColor(calibratedRed: 0.14, green: 0.19, blue: 0.36, alpha: 0.45)
        case .ghost: return NSColor(calibratedRed: 0.84, green: 0.84, blue: 1.00, alpha: 0.85)
        case .dino: return NSColor(calibratedRed: 0.36, green: 0.62, blue: 0.34, alpha: 0.5)
        case .robot: return NSColor(calibratedRed: 0.56, green: 0.64, blue: 0.8, alpha: 0.55)
        case .dragon: return NSColor(calibratedRed: 0.84, green: 0.28, blue: 0.3, alpha: 0.45)
        }
    }

    var outline: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 0.36, green: 0.26, blue: 0.27, alpha: 1)
        case .cat: return NSColor(calibratedRed: 0.45, green: 0.27, blue: 0.15, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 0.42, green: 0.36, blue: 0.46, alpha: 1)
        case .penguin: return NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.25, alpha: 1)
        case .ghost: return NSColor(calibratedRed: 0.46, green: 0.46, blue: 0.74, alpha: 1)
        case .dino: return NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.24, alpha: 1)
        case .robot: return NSColor(calibratedRed: 0.28, green: 0.34, blue: 0.48, alpha: 1)
        case .dragon: return NSColor(calibratedRed: 0.5, green: 0.17, blue: 0.18, alpha: 1)
        }
    }

    var accent: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 1.00, green: 0.60, blue: 0.65, alpha: 1)
        case .cat: return NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.66, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.80, alpha: 1)
        case .penguin: return NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.68, alpha: 1)
        case .ghost: return NSColor(calibratedRed: 1.00, green: 0.66, blue: 0.80, alpha: 1)
        case .dino: return NSColor(calibratedRed: 1.0, green: 0.7, blue: 0.62, alpha: 1)
        case .robot: return NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.7, alpha: 1)
        case .dragon: return NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.72, alpha: 1)
        }
    }

    var ink: NSColor {
        switch self {
        case .mochi: return NSColor(calibratedRed: 0.22, green: 0.16, blue: 0.18, alpha: 1)
        case .cat: return NSColor(calibratedRed: 0.22, green: 0.12, blue: 0.08, alpha: 1)
        case .bunny: return NSColor(calibratedRed: 0.20, green: 0.15, blue: 0.25, alpha: 1)
        case .penguin: return NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.14, alpha: 1)
        case .ghost: return NSColor(calibratedRed: 0.20, green: 0.18, blue: 0.30, alpha: 1)
        case .dino: return NSColor(calibratedRed: 0.12, green: 0.2, blue: 0.14, alpha: 1)
        case .robot: return NSColor(calibratedRed: 0.5, green: 0.96, blue: 1.0, alpha: 1)
        case .dragon: return NSColor(calibratedRed: 0.26, green: 0.08, blue: 0.1, alpha: 1)
        }
    }

    var foot: NSColor {
        switch self {
        case .penguin: return NSColor(calibratedRed: 1.00, green: 0.66, blue: 0.24, alpha: 1)
        case .robot: return NSColor(calibratedRed: 0.62, green: 0.70, blue: 0.82, alpha: 1)
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
        case .dino: return ["RAWR! 🦖", "Stomp stomp stomp!", "I'm the king of the Dock!", "Tiny arms, big heart.", "Is that a meteor?! …no. Phew."]
        case .robot: return ["Beep boop! 🤖", "Systems: adorable.", "Calculating… you're awesome.", "Recharging my hug module.", "01001000 01101001!"]
        case .dragon: return ["Fwoosh! 🔥", "I'm a real dragon, I promise.", "Guarding my treasure (it's you).", "Smoke break… literally.", "Who wants toasted marshmallows?"]
        }
    }
}
