import Foundation

/// What the pet says about whatever is playing: songs, podcasts, videos, films and shows.
extension Dialogue {
    // Music
    static let musicStart = ["Ooh, music! 🎵", "Ooh, I like this one 🎶", "Headphones on! 🎧", "Let's groove 🎵"]
    static func songStart(_ title: String) -> [String] { ["Ooh, \(title)! 🎵", "\(title)! Good pick 🎶", "Ahh, \(title) 🎧"] }
    static let newSong = ["Ooh, next song! 🎶", "This one's good too 🎵", "Ooh, I know this one!"]
    static let musicStopped = ["Aww, the music stopped 🥲", "Hey, I was dancing to that!", "More music later? 🎶"]

    // Podcasts and audiobooks
    static let podcastStart = ["Ooh, a podcast. I'm listening 🎧", "Story time? I'm all ears 👂", "Let's learn something 🤓"]
    static let podcastListening = ["Mm-hmm 🤔", "Interesting point!", "Wait, really?", "Huh, I didn't know that.",
                                   "Ooh, good point.", "I'd agree with that 🤓", "Hmm… 🤔"]

    // Videos (YouTube and the like)
    static let videoStart = ["Ooh, what are we watching? 👀", "Video time! 📺", "Scoot over, I want to see 👀"]
    static func videoNamed(_ channel: String) -> [String] { ["Ooh, \(channel)! 📺", "\(channel)? Good choice 👀"] }
    static let videoGiggle = ["Hahaha 😂", "Hehe, that was funny 😆", "Did you see that?! 😂", "Pfft 😄", "Wow 👀"]

    // Private windows: never anything about what it is
    static let privateStart = ["I'm not looking! 🙈", "Private time? I'll look away 🙈", "Your secret's safe with me 🤐",
                               "I didn't see anything 👀❌"]

    // Films and shows
    static let movieStart = ["Movie time! 🍿", "Shh, it's starting 🎬", "Lights down, film on 🎬", "Ooh, let's watch! 🍿"]
    static let movieEnd = ["That was a good one 🎬", "Credits! What did you think? 🍿", "Movie's over. Stretch time?"]
}

extension Dialogue {
    /// Said now and then when the pet switches to an act (see MediaAct).
    static func actStart(_ act: MediaAct) -> [String] {
        switch act {
        case .dj: return ["DJ in the house! 🎧", "Drop the beat! 💿", "Wiki-wiki! 🎚"]
        case .airGuitar: return ["Guitar solo! 🎸", "Rock on! 🤘", "Shred time 🎸"]
        case .karaoke: return ["Sing with me! 🎤", "This is my song! 🎤", "La la laaa ♪"]
        case .rave: return ["Glow sticks up! ✨", "Party mode! 🪩", "Wave 'em! ✨"]
        case .bongos: return ["Bongo time! 🥁", "Feel the rhythm! 🥁", "Ba-dum-tss!"]
        case .earbud: return ["Earbud in, I'm listening 🎧", "Go on, I'm all ears 👂"]
        case .notes: return ["Taking notes 📝", "Ooh, writing that down ✏️", "Note to self… 📝"]
        case .coffee: return ["Coffee and a podcast ☕", "Cosy listening ☕", "Sip… mm, good point ☕"]
        case .radio: return ["Turning it up 📻", "Like the old radio days 📻"]
        case .thinker: return ["Hmm, let me think 🤔", "That's deep… 🤔", "Big thoughts 💭"]
        case .phone: return ["Watching on my phone 📱", "One more video… 📱"]
        case .snacks: return ["Snack break! 🍟", "Crunch crunch 😋", "Chips and videos 🍟"]
        case .like: return ["Smash that like! 👍", "That deserves a like 👍"]
        case .subscribe: return ["Subscribed! 🔔", "Ding! New videos 🔔", "Hit the bell! 🔔"]
        case .comments: return ["Leaving a comment 💬", "First! 💬", "Typing my thoughts ⌨️"]
        case .cinema: return ["3D glasses on! 🎬", "Popcorn ready 🍿"]
        case .blanket: return ["So cosy 🛋", "Blanket burrito mode 🌯"]
        case .soda: return ["Soda and nachos 🥤", "Cinema snacks! 🧀"]
        case .scary: return ["Is this a scary bit? 😨", "I'm not scared… 😰"]
        case .tearjerker: return ["Don't cry… you cry 🥲", "Pass the tissues 😭"]
        case .spy: return ["Agent undercover. Saw nothing 🕶", "Incognito mode: engaged 🕵️"]
        case .masquerade: return ["Mask on. Your secret's safe 🎭", "Who, me? I didn't see a thing 🎭"]
        case .peekaboo: return ["I'm not looking! 🙈", "Eyes closed, promise 🙈"]
        case .sleepMask: return ["See nothing, hear nothing 😴", "Earmuffs on! 🙉"]
        case .turnAway: return ["I'll just face this way… 😗🎶", "Not looking, just whistling ♪"]
        }
    }

    /// Moments the AI writes fresh lines for (see `Dialogue.moments`).
    static var mediaMoments: [Moment] {
        [
            Moment(key: "musicStart", about: "music just started playing and you get right into it", lines: musicStart),
            Moment(key: "newSong", about: "the next song just started", lines: newSong),
            Moment(key: "musicStopped", about: "the music you were dancing to just stopped", lines: musicStopped),
            Moment(key: "podcastStart", about: "your human started a podcast or audiobook and you settle in to listen", lines: podcastStart),
            Moment(key: "podcastListening", about: "a tiny reaction while listening to a podcast with your human (a few words)", lines: podcastListening),
            Moment(key: "videoStart", about: "your human started watching a video and you sit down to watch too", lines: videoStart),
            Moment(key: "videoGiggle", about: "something funny or surprising just happened in the video you are watching (a few words)", lines: videoGiggle),
            Moment(key: "movieStart", about: "a film or show is starting and you settle in to watch quietly", lines: movieStart),
            Moment(key: "movieEnd", about: "the film or show you were watching together just ended", lines: movieEnd),
            Moment(key: "privateStart", about: "your human started something in a private browser window and you cover your eyes to give them privacy", lines: privateStart)
        ] + MediaAct.allCases.map { act in
            Moment(key: "act." + act.rawValue, about: "you start a new thing to do while \(act.doing)", lines: actStart(act))
        }
    }
}
