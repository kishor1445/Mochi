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

enum PetSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    /// Speech bubbles shrink with the pet, but less steeply so the text stays readable (10 / 11 / 13pt).
    var bubbleScale: CGFloat {
        switch self {
        case .small: return 0.77
        case .medium: return 0.85
        case .large: return 1
        }
    }

    /// Relative to the 120pt design size.
    var scale: CGFloat {
        switch self {
        case .small: return 0.55
        case .medium: return 0.72
        case .large: return 1
        }
    }
}

/// User preferences, saved automatically to UserDefaults.
final class PetSettings: ObservableObject {
    static let shared = PetSettings()
    private let d = UserDefaults.standard

    @Published var species: Species { didSet { d.set(species.rawValue, forKey: "species") } }
    @Published var petSize: PetSize { didSet { d.set(petSize.rawValue, forKey: "petSize") } }
    @Published var chattiness: Chattiness { didSet { d.set(chattiness.rawValue, forKey: "chattiness") } }
    @Published var walkOnWindows: Bool { didSet { d.set(walkOnWindows, forKey: "walkOnWindows") } }
    @Published var climbEdges: Bool { didSet { d.set(climbEdges, forKey: "climbEdges") } }
    @Published var followCursor: Bool { didSet { d.set(followCursor, forKey: "followCursor") } }
    @Published var reactToMedia: Bool { didSet { d.set(reactToMedia, forKey: "reactToMedia") } }
    @Published var reactToTyping: Bool { didSet { d.set(reactToTyping, forKey: "reactToTyping") } }
    @Published var breakReminders: Bool { didSet { d.set(breakReminders, forKey: "breakReminders") } }
    @Published var systemAware: Bool { didSet { d.set(systemAware, forKey: "systemAware") } }
    /// Mirrors the system's login item (not stored here: macOS owns it).
    @Published var launchAtLogin = LoginItem.enabled

    private init() {
        species = Species(rawValue: d.string(forKey: "species") ?? "") ?? .mochi
        petSize = PetSize(rawValue: d.string(forKey: "petSize") ?? "") ?? .medium
        chattiness = Chattiness(rawValue: d.string(forKey: "chattiness") ?? "") ?? .normal
        walkOnWindows = d.object(forKey: "walkOnWindows") as? Bool ?? true
        climbEdges = d.object(forKey: "climbEdges") as? Bool ?? true
        followCursor = d.object(forKey: "followCursor") as? Bool ?? true
        reactToMedia = d.object(forKey: "reactToMedia") as? Bool ?? true
        reactToTyping = d.object(forKey: "reactToTyping") as? Bool ?? true
        breakReminders = d.object(forKey: "breakReminders") as? Bool ?? true
        systemAware = d.object(forKey: "systemAware") as? Bool ?? true
    }
}
