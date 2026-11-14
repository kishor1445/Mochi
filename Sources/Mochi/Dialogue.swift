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

    // Typing along
    static let typingRoll = ["You're on a roll! ✨", "Look at you go!", "Tap tap tap… I like the rhythm 🎶"]
    static let typingLong = ["So productive today! 💪", "Still going! You're unstoppable.", "That's a lot of typing. Proud of you 💖"]
    static let typingFast = ["Whoa, fast fingers! ⌨️", "Speedy!! 💨", "Are your keys okay?! 🔥"]

    // Being thrown
    static let thrown = ["Wheeeee!", "I can flyyy!", "Yeet!!", "Not agaaain!"]
    static let crashLanded = ["Again! Again! 😵‍💫", "The room is spinning…", "Ten out of ten landing.", "Whoa… do that again!"]

    // Hide and peek
    static let peekaboo = ["Peekaboo! 👀", "Boo! Found you!", "You can't see me… oh.", "Hehe, I was hiding!"]

    // Two pets
    static func buddyHello(_ name: String) -> [String] {
        ["Hi \(name)!", "Tag, you're it!", "\(name)! Play with me!", "Boop!", "Best buddies! 💕"]
    }

    // Outfits
    static func newOutfit(_ o: Outfit) -> String { "Ooh, I can wear a \(o.label.lowercased()) now! ✨" }

    // Gentle reminders
    static func reminder(_ kind: ReminderKind) -> [String] {
        switch kind {
        case .water: return ["Time for a sip of water 💧", "Water break! 💧", "Stay hydrated, okay? 💧"]
        case .posture: return ["Shoulders down, back straight 🧍", "How's your posture? 🧍", "Sit up tall with me!"]
        case .eyes: return ["Look at something far away for 20 seconds 👀", "Rest your eyes a moment 👀", "Blink! And look out the window 🌳"]
        }
    }

    // Busy Mac
    static let busyMac = ["Phew, your Mac is working hard! 🥵", "So… much… computing…", "Is something heavy running? 💦"]
    static let hotMac = ["It's getting warm in here 🔥", "Your Mac is running hot. Give it a moment? 🌡"]

    // Calendar
    static func meeting(_ title: String, minutes: Int) -> String {
        minutes == 0 ? "📅 \(title) is starting now!" : "📅 \(title) in \(minutes) min!"
    }

    // Focus sessions
    static let focusStart = ["Focus time! I'll keep quiet 🤫", "You've got this! I'll be right here.", "Let's do this! 💪"]
    static let focusDone = ["Focus done! Great work 🎉 Time for a break.", "You did it! 🎉 Stretch a little?", "All done! Proud of you 💖"]
    static let focusStopped = ["Okay, break time!", "Stopping here. Nice effort!"]
}
