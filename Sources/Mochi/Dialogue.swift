import Foundation

/// Everything the pet can say. Later an AI brain can replace these canned lines.
enum Dialogue {
    static func timeGreeting(hour: Int) -> String {
        switch hour {
        case 5..<12: return "Good morning! ☀️"
        case 12..<17: return "Good afternoon! 🌤"
        case 17..<22: return "Good evening! 🌆"
        default: return "Still up? 🌙"
        }
    }

    static let general = [
        "Hi!", "Hello there!", "Hey, you! 👋", "Oh, hi!", "Miss me?",
        "You're doing great! ✨", "Drink some water 💧", "Stretch your legs a bit!",
        "Rest your eyes for a sec 👀", "Need a break? ☕️"
    ]

    static func greeting(species: Species, hour: Int) -> String {
        let r = Int.random(in: 0..<10)
        if r < 3 { return timeGreeting(hour: hour) }
        if r < 7 { return species.lines.randomElement() ?? "Hi!" }
        return general.randomElement() ?? "Hi!"
    }

    static let petted = ["Hehe!", "That tickles!", "Again, again!", "More pets please 💕", "Love it!"]
    static let startled = ["Zzz… huh?!", "Wha—? I was sleeping!", "Five more minutes…"]
    static let dragged = ["Wheee!", "Put me down! …or don't.", "Whoa whoa whoa!", "I believe I can fly!"]
    static let landedWindow = ["Nice view up here!", "King of this window 👑", "Found a cozy spot!"]
    static let clung = ["Got a grip!", "Spider-pet! 🕷", "Look, I'm climbing!"]
    static let slipping = ["Uh oh…", "My grip!", "Hold on—", "I'm slipping!"]
    static let ouch = ["Ow! I'm okay.", "Ta-da! …on purpose.", "That was my plan all along.", "Nailed the landing!"]
    static let leaping = ["Hup!", "Boing!", "Up we go!"]
}
