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

    var id: String { rawValue }

    /// The kind of media it goes with.
    var kind: MediaActivity {
        switch self {
        case .dj, .airGuitar, .karaoke, .rave, .bongos: return .music
        case .earbud, .notes, .coffee, .radio, .thinker: return .podcast
        case .phone, .snacks, .like, .subscribe, .comments: return .video
        case .cinema, .blanket, .soda, .scary, .tearjerker: return .movie
        }
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

    static func acts(for kind: MediaActivity) -> [MediaAct] { allCases.filter { $0.kind == kind } }

    /// A random act for `kind`, never the one it is doing now.
    static func pick(for kind: MediaActivity, after current: MediaAct? = nil) -> MediaAct? {
        let options = acts(for: kind).filter { $0 != current }
        return options.randomElement() ?? acts(for: kind).first
    }
}
