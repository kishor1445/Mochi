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

    // Films and shows
    static let movieStart = ["Movie time! 🍿", "3D glasses on! 🎬", "Shh, it's starting 🍿", "Popcorn ready 🍿"]
    static let movieEnd = ["That was a good one 🎬", "Credits! What did you think? 🍿", "Movie's over. Stretch time?"]
}

extension Dialogue {
    /// Moments the AI writes fresh lines for (see `Dialogue.moments`).
    static var mediaMoments: [Moment] {
        [
            Moment(key: "musicStart", about: "music just started playing and you put your headphones on", lines: musicStart),
            Moment(key: "newSong", about: "the next song just started", lines: newSong),
            Moment(key: "musicStopped", about: "the music you were dancing to just stopped", lines: musicStopped),
            Moment(key: "podcastStart", about: "your human started a podcast or audiobook and you settle in to listen", lines: podcastStart),
            Moment(key: "podcastListening", about: "a tiny reaction while listening to a podcast with your human (a few words)", lines: podcastListening),
            Moment(key: "videoStart", about: "your human started watching a video and you sit down to watch too", lines: videoStart),
            Moment(key: "videoGiggle", about: "something funny or surprising just happened in the video you are watching (a few words)", lines: videoGiggle),
            Moment(key: "movieStart", about: "a film or show is starting: you put on 3D glasses and grab popcorn", lines: movieStart),
            Moment(key: "movieEnd", about: "the film or show you were watching together just ended", lines: movieEnd)
        ]
    }
}
