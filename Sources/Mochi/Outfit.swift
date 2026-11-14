import Foundation

/// Things the pet can wear. Each one unlocks at a bond level, so looking after your pet pays off.
enum Outfit: String, CaseIterable, Identifiable {
    case none, flower, cap, glasses, shades, partyHat, headband, crown, halo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Nothing"
        case .flower: return "Flower"
        case .glasses: return "Glasses"
        case .cap: return "Cap"
        case .shades: return "Shades"
        case .headband: return "Ninja headband"
        case .partyHat: return "Party hat"
        case .crown: return "Crown"
        case .halo: return "Halo"
        }
    }

    /// Bond level needed to wear it.
    var unlockLevel: Int {
        switch self {
        case .none: return 1
        case .flower, .cap: return 2
        case .glasses, .shades: return 3
        case .partyHat, .headband: return 4
        case .crown: return 5
        case .halo: return 6
        }
    }

    /// Extra height above the head, so the speech bubble clears it.
    var headRoom: CGFloat {
        switch self {
        case .partyHat: return 18
        case .crown: return 9
        case .cap: return 6
        case .halo: return 16
        default: return 0
        }
    }

    static func unlocked(at level: Int) -> [Outfit] { allCases.filter { $0.unlockLevel <= level } }
    static func next(after level: Int) -> Outfit? { allCases.first { $0.unlockLevel > level } }
}
