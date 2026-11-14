import Foundation
import Combine

enum Chattiness: String, CaseIterable, Identifiable {
    case off, quiet, normal, chatty

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Silent"
        case .quiet: return "Quiet"
        case .normal: return "Normal"
        case .chatty: return "Chatty"
        }
    }

    /// Seconds between random "hi"s (nil = never).
    var interval: ClosedRange<TimeInterval>? {
        switch self {
        case .off: return nil
        case .quiet: return 150...300
        case .normal: return 40...100
        case .chatty: return 12...35
        }
    }
}

/// User preferences, saved automatically to UserDefaults.
final class PetSettings: ObservableObject {
    static let shared = PetSettings()
    private let d = UserDefaults.standard

    @Published var species: Species { didSet { d.set(species.rawValue, forKey: "species") } }
    @Published var chattiness: Chattiness { didSet { d.set(chattiness.rawValue, forKey: "chattiness") } }
    @Published var walkOnWindows: Bool { didSet { d.set(walkOnWindows, forKey: "walkOnWindows") } }
    @Published var climbEdges: Bool { didSet { d.set(climbEdges, forKey: "climbEdges") } }
    @Published var followCursor: Bool { didSet { d.set(followCursor, forKey: "followCursor") } }

    private init() {
        species = Species(rawValue: d.string(forKey: "species") ?? "") ?? .mochi
        chattiness = Chattiness(rawValue: d.string(forKey: "chattiness") ?? "") ?? .normal
        walkOnWindows = d.object(forKey: "walkOnWindows") as? Bool ?? true
        climbEdges = d.object(forKey: "climbEdges") as? Bool ?? true
        followCursor = d.object(forKey: "followCursor") as? Bool ?? true
    }
}
