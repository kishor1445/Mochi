import Foundation

/// What the pet gets up to while something plays. Each kind of media has five acts; one is picked when
/// it starts and another every few minutes (and now and then on a new song), so it doesn't get old.
/// Drawn in Pet/View/Acts, one file per kind.
enum MediaAct: String, CaseIterable, Identifiable {
    // Music
    case dj, airGuitar, karaoke, rave, bongos
    // Podcasts and audiobooks
    case earbud, notes, coffee, radio, thinker
    // Videos (YouTube and the like)
    case phone, snacks, like, subscribe, comments
    // Films and shows
    case cinema, blanket, soda, scary, tearjerker
    // Something playing in a private window: it politely doesn't look
    case spy, masquerade, peekaboo, sleepMask, turnAway

    var id: String { rawValue }

    /// The kind of media it goes with.
    var kind: MediaActivity {
        switch self {
        case .dj, .airGuitar, .karaoke, .rave, .bongos: return .music
        case .earbud, .notes, .coffee, .radio, .thinker: return .podcast
        case .phone, .snacks, .like, .subscribe, .comments: return .video
        case .cinema, .blanket, .soda, .scary, .tearjerker: return .movie
        case .spy, .masquerade, .peekaboo, .sleepMask, .turnAway: return .video
        }
    }

    /// One of the "I'm not looking!" acts for a private window (picked by browser, not by kind).
    var isPrivacy: Bool { MediaAct.privacy.contains(self) }

    static let privacy: [MediaAct] = [.spy, .masquerade, .peekaboo, .sleepMask, .turnAway]

    /// Each browser's own act, after its private-mode icon: Chrome's incognito spy, Firefox's mask…
    static func signature(for browser: MediaClassifier.Browser?) -> MediaAct {
        switch browser {
        case .chrome: return .spy
        case .firefox: return .masquerade
        case .safari: return .peekaboo
        case .edge: return .sleepMask
        default: return .turnAway
        }
    }

    /// Another privacy act, never the one it's doing now.
    static func pickPrivate(after current: MediaAct?) -> MediaAct {
        privacy.filter { $0 != current }.randomElement() ?? .turnAway
    }

    var label: String {
        switch self {
        case .dj: return "DJ"
        case .airGuitar: return "Air guitar"
        case .karaoke: return "Karaoke"
        case .rave: return "Glow-stick rave"
        case .bongos: return "Bongos"
        case .earbud: return "Earbud nodder"
        case .notes: return "Note-taker"
        case .coffee: return "Coffee break"
        case .radio: return "Retro radio"
        case .thinker: return "Deep thinker"
        case .phone: return "Phone binge"
        case .snacks: return "Snack attack"
        case .like: return "Smash that like"
        case .subscribe: return "Subscribe bell"
        case .comments: return "Comment typer"
        case .cinema: return "3D cinema"
        case .blanket: return "Blanket burrito"
        case .soda: return "Soda and nachos"
        case .scary: return "Scary scene"
        case .tearjerker: return "Tearjerker"
        case .spy: return "Spy disguise"
        case .masquerade: return "Masquerade mask"
        case .peekaboo: return "Paws over eyes"
        case .sleepMask: return "Sleep mask and earmuffs"
        case .turnAway: return "Turned around"
        }
    }

    /// For the AI: what the pet is up to, finishing "…while ___".
    var doing: String {
        switch self {
        case .dj: return "DJing to the music on a little turntable"
        case .airGuitar: return "playing air guitar to the music"
        case .karaoke: return "singing karaoke to the song"
        case .rave: return "waving glow sticks to the music"
        case .bongos: return "drumming bongos to the music"
        case .earbud: return "listening to a podcast with one earbud in"
        case .notes: return "taking notes on a podcast"
        case .coffee: return "sipping coffee with a podcast on"
        case .radio: return "listening to a podcast on a little retro radio"
        case .thinker: return "thinking hard about what the podcast said"
        case .phone: return "watching a video on a phone"
        case .snacks: return "eating chips and watching a video"
        case .like: return "holding up a thumbs-up sign for a video"
        case .subscribe: return "pressing subscribe on a video channel"
        case .comments: return "typing a comment under a video"
        case .cinema: return "watching a film in 3D glasses with popcorn"
        case .blanket: return "wrapped in a blanket watching a show"
        case .soda: return "watching a film with soda and nachos"
        case .scary: return "hiding behind a cushion during a scary film"
        case .tearjerker: return "crying at a sad film with tissues"
        case .spy: return "in a spy disguise, not looking at your human's private browsing"
        case .masquerade: return "behind a mask, not looking at your human's private browsing"
        case .peekaboo: return "covering your eyes so you don't see your human's private browsing"
        case .sleepMask: return "in a sleep mask and earmuffs, so your human's private browsing stays private"
        case .turnAway: return "turned around, giving your human some privacy"
        }
    }

    /// Props that stand on the ground (a turntable, a radio, a laptop): only out while the pet stands still.
    /// The rest are held, so they come along on a walk too.
    var staysPut: Bool {
        switch self {
        case .dj, .bongos, .notes, .radio, .snacks, .subscribe, .comments, .blanket, .soda, .scary, .tearjerker:
            return true
        default:
            return false
        }
    }

    /// Wears headphones while doing it (the rest of the music acts show off something else instead).
    var wearsHeadphones: Bool { self == .dj }

    static func acts(for kind: MediaActivity) -> [MediaAct] { allCases.filter { $0.kind == kind && !$0.isPrivacy } }

    /// A random act for `kind`, never the one it is doing now.
    static func pick(for kind: MediaActivity, after current: MediaAct? = nil) -> MediaAct? {
        let options = acts(for: kind).filter { $0 != current }
        return options.randomElement() ?? acts(for: kind).first
    }
}
