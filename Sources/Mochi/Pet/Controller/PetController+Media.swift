import AppKit

/// Reacting to what is playing on the Mac. `AudioWatcher` says what kind of thing it is (music, a podcast,
/// a video, a film or a show, a call) and `NowPlaying` what exactly; this decides how the pet takes it:
///
/// - music: headphones on, vibing along while it goes about its day, a proper dance now and then
/// - podcast: one earbud in, nodding along, the odd "mm-hmm"
/// - video: sits down to watch in the screen's glow, giggles now and then
/// - film or show: 3D glasses and popcorn, quiet and still until it ends
/// - call: quiet (see `canSpeak`)
extension PetController {
    /// What's playing, as far as the settings let the pet care. Runs every second, and straight away
    /// whenever the audio watcher notices a change.
    func refreshMedia() {
        var m = settings.reactToMedia ? audio.current : .none
        // "Other" just means some app has the speakers open, which is often silence: opt-in only.
        if m == .other, !settings.reactToOtherAudio { m = .none }
        if m == .call, !settings.quietOnCalls { m = .none }
        if m != media {
            let before = media
            media = m
            mediaChanged(from: before)
        } else if settings.reactToMedia {
            noticeNewTrack()
        }
        updateBeat()
    }

    func mediaChanged(from before: MediaActivity = .none) {
        let np = audio.playingNow
        playingTitle = np?.title
        nextMediaMoment = Date().addingTimeInterval(.random(in: 40...90))
        switch media {
        case .music, .other:
            if !isMain {}
            else if media == .music {
                let fallback = np?.title.flatMap { $0.count <= 32 ? Dialogue.songStart($0).randomElement() : nil }
                react("Music just started playing\(describe(np))", fallback: fallback ?? Dialogue.musicStart.randomElement()!, note: true)
            }
            else if Bool.random() { say("Something's playing… 🎧") }
            // No stopping to dance: the headphones go on and it carries on with whatever it was doing,
            // grooving to the beat (see PetView.vibing). Standing about, it gives a happy little bounce first.
            if canAct, !userAway, action == .idle || action == .lookAround { apply(Decision(action: .happy, duration: 1.6)) }
        case .podcast:
            if isMain { react("Your human started listening to \(np?.app?.contains("audible") == true || np?.app?.contains("books") == true ? "an audiobook" : "a podcast")\(describe(np))",
                              fallback: Dialogue.podcastStart.randomElement()!, note: true) }
            if canAct, !userAway { apply(Decision(action: .idle, duration: 4)) }
        case .video:
            if isMain {
                let fallback = np?.artist.flatMap { $0.count <= 24 ? Dialogue.videoNamed($0).randomElement() : nil }
                react("Your human started watching a video\(describe(np))", fallback: fallback ?? Dialogue.videoStart.randomElement()!, note: true)
            }
            if canAct, !userAway { apply(Decision(action: .idle, duration: 5)) }
        case .movie:
            // The one thing it says before going quiet for the film (force: films silence the pet).
            if isMain { react("Your human started watching a film or show\(describe(np)); you put on 3D glasses and grab popcorn",
                              fallback: Dialogue.movieStart.randomElement()!, force: true, note: true) }
            if canAct, !userAway { apply(Decision(action: .idle, duration: 6)) }
        case .call:
            if isMain { say("Shh… I'll be quiet 🤫", force: true) }
            if canAct, !userAway { apply(Decision(action: .idle, duration: 5)) }
        case .none:
            if isMain, before == .movie { react("The film or show you were watching together just ended", fallback: Dialogue.movieEnd.randomElement()!) }
        }
        updateBeat()
    }

    /// " (“Song” by Artist in Spotify)": what the model is told about the item, when known.
    func describe(_ np: NowPlaying.State?) -> String {
        guard let np else { return soundSource }
        var parts: [String] = []
        if let t = np.title { parts.append("\u{201C}\(t.prefix(80))\u{201D}") }
        if let a = np.artist { parts.append("by \(a.prefix(40))") }
        if let n = np.name { parts.append("in \(n)") }
        return parts.isEmpty ? "" : ": " + parts.joined(separator: " ")
    }

    /// A new song (or episode) while the same kind of thing keeps playing: now and then it notices.
    func noticeNewTrack() {
        guard isMain, media == .music || media == .podcast, let np = audio.playingNow, let title = np.title,
              title != playingTitle else { return }
        let first = playingTitle == nil
        playingTitle = title
        guard !first, media == .music, Double.random(in: 0..<1) < 0.3 else { return }
        react("The next song just started\(describe(np))", fallback: Dialogue.newSong.randomElement()!)
    }

    /// Little reactions while a podcast or a video plays: a nod and a word, a giggle. Once a second.
    func mediaTick(_ now: Date) {
        guard now >= nextMediaMoment else { return }
        nextMediaMoment = now.addingTimeInterval(.random(in: 45...120))
        guard isMain || Bool.random(), canAct, !userAway, action == .idle || action == .lookAround || { if case .walk = action { return true }; return false }() else { return }
        switch media {
        case .podcast:
            if Bool.random() { say(Dialogue.podcastListening.randomElement()!) }
            apply(Decision(action: .lookAround, duration: 2.5))
        case .video:
            apply(Decision(action: .happy, duration: 1.2))
            if Double.random(in: 0..<1) < 0.6 { say(Dialogue.videoGiggle.randomElement()!) }
        default:
            break
        }
    }

    /// Whether the pet should be vibing: headphones on and grooving to the beat.
    /// Music counts even during a call (say, a Discord voice channel with Spotify playing): the vibe is
    /// only visual, and the pet still keeps quiet for the call.
    var hearsMusic: Bool {
        media == .music || media == .other || (settings.reactToMedia && audio.musicOn && !media.isWatching && media != .podcast)
    }

    /// Puts the right things on for what's playing: headphones for music; an earbud, the screen's glow
    /// or 3D glasses and popcorn for the rest.
    func updateBeat() {
        let gear: MediaGear
        switch media {
        case .podcast: gear = .podcast
        case .video: gear = .video
        case .movie: gear = .movie
        default: gear = .none
        }
        if view.watching != gear { view.watching = gear }

        let on = hearsMusic
        guard on != (view.musicBpm > 0) else { return }
        if on {
            view.musicBpm = .random(in: 100...126)
        } else {
            view.musicBpm = 0
            // A dance that started to the music ends with it, instead of playing out its last few seconds.
            if action == .dance, social == .none { remaining = min(remaining, 0.4) }
            if isMain, media == .none { react("The music you were vibing to just stopped", fallback: Dialogue.musicStopped.randomElement()!) }
        }
    }
}
