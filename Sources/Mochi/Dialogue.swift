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

    /// Lines that only a pet who knows you well would say.
    static func bonded(level: Int, days: Int) -> [String] {
        var l = ["I like hanging out with you 💕", "You're my favourite human!"]
        if days > 1 { l.append("\(days) days together! 🎉") }
        if level >= 5 { l += ["Best friends forever! 💖", "I'd climb any screen edge for you."] }
        return l
    }

    static func greeting(species: Species, hour: Int, bondLevel: Int = 1, days: Int = 1) -> String {
        if bondLevel >= 3, Int.random(in: 0..<5) == 0 {
            return bonded(level: bondLevel, days: days).randomElement() ?? "Hi!"
        }
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
    static let yum = ["Yum! 😋", "Nom nom nom!", "Delicious!", "Thank you! 💖"]
    static let hover = ["Oh, hello there!", "You're so close!", "Boop?", "Hi hi hi!"]
    static let treatDropped = ["Ooh, a treat!", "Food?!", "Is that for me?!"]

    // Needs
    static func hungry(_ s: Species) -> [String] {
        ["I'm hungry… \(s.treatEmoji)?", "My tummy is rumbling…", "Snack time? \(s.treatEmoji)", "I could really go for a \(s.treatEmoji)"]
    }
    static let lonely = ["Play with me? 🥺", "Pet me? Just once?", "I'm a little lonely…", "Hey… remember me?"]
    static let sleepy = ["So sleepy… 😴", "Need… a nap…", "Can't keep my eyes open…"]
    static let stuffed = ["I'm stuffed! Maybe later 😌", "No more, I'll pop!", "So full…"]
    static let missedYou = ["I missed you! 💕", "You're back! I waited for you!", "There you are! 🥹"]

    // Playing ball
    static let ballDropped = ["Ooh, let's play!", "Ball!!", "Mine mine mine!"]
    static let kick = ["Boing!", "Hah!", "Got it!", "Take that!", "Whee!"]
    static let playedEnough = ["That was fun! 💖", "Again sometime?", "Phew, good game!"]
    static let tooTired = ["Too tired to play… 😴", "Later? I need a nap first."]

    // Focus sessions
    static let focusStart = ["Focus time! I'll keep quiet 🤫", "You've got this! I'll be right here.", "Let's do this! 💪"]
    static let focusDone = ["Focus done! Great work 🎉 Time for a break.", "You did it! 🎉 Stretch a little?", "All done! Proud of you 💖"]
    static let focusStopped = ["Okay, break time!", "Stopping here. Nice effort!"]
}
