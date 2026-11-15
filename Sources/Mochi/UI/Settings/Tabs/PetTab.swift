import SwiftUI

struct PetTab: View {
    @ObservedObject var settings: PetSettings
    var onSayHi: () -> Void
    var onTreat: () -> Void
    var onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(Species.allCases) { sp in
                    PetCard(species: sp, selected: settings.species == sp)
                        .onTapGesture { settings.species = sp }
                }
            }
            StatusCard(mind: .shared, species: settings.species)
            WardrobeRow(settings: settings, mind: .shared)
            HStack(spacing: 8) {
                Button(action: onTreat) { Label("Give a treat", systemImage: "gift") }
                Button(action: onPlay) { Label("Play ball", systemImage: "soccerball") }
                Spacer()
                Button(action: onSayHi) { Label("Say hi", systemImage: "hand.wave") }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }
}

/// Outfit and second-pet choices, side by side under the status card.
struct WardrobeRow: View {
    @ObservedObject var settings: PetSettings
    @ObservedObject var mind: PetMind

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Picker("Outfit", selection: $settings.outfit) {
                    ForEach(Outfit.unlocked(at: mind.level)) { Text($0.label).tag($0) }
                }
                .frame(width: 190)
                if let next = Outfit.next(after: mind.level) {
                    let names = Outfit.allCases.filter { $0.unlockLevel == next.unlockLevel }.map(\.label)
                    Text("Bond level \(next.unlockLevel) unlocks: \(names.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Toggle("Second pet", isOn: $settings.secondPet)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                if settings.secondPet {
                    Picker("Friend", selection: $settings.companionSpecies) {
                        ForEach(Species.allCases) { Text("\($0.emoji) \($0.name)").tag($0) }
                    }
                    .frame(width: 160)
                }
            }
        }
    }
}
