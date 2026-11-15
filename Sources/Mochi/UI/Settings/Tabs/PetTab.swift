import SwiftUI
import AppKit

struct PetTab: View {
    @ObservedObject var settings: PetSettings
    @ObservedObject var mind = PetMind.shared
    var onSayHi: () -> Void
    var onTreat: () -> Void
    var onPlay: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            hero

            CardSection(title: "Choose your pet") {
                VStack(alignment: .leading, spacing: 10) {
                    group("Cute", .cute)
                    group("Tough", .tough)
                }
                .padding(12)
            }

            CardSection(title: "Wardrobe and friends") {
                SettingRow(symbol: "tshirt.fill", tint: .purple, title: "Outfit", subtitle: unlockHint) {
                    Picker("Outfit", selection: $settings.outfit) {
                        ForEach(Outfit.unlocked(at: mind.level)) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                RowDivider()
                ToggleRow(symbol: "person.2.fill", tint: .teal, title: "Second pet",
                          subtitle: "A friend that lives alongside \(settings.species.name)", isOn: $settings.secondPet)
                if settings.secondPet {
                    RowDivider()
                    SettingRow(symbol: "heart.fill", tint: .pink, title: "Friend") {
                        Picker("Friend", selection: $settings.companionSpecies) {
                            ForEach(Species.allCases) { Text($0.name).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
            }
        }
    }

    private var unlockHint: String? {
        guard let next = Outfit.next(after: mind.level) else { return nil }
        let names = Outfit.allCases.filter { $0.unlockLevel == next.unlockLevel }.map(\.label)
        return "Bond level \(next.unlockLevel) unlocks: \(names.joined(separator: ", "))"
    }

    private func group(_ title: String, _ style: Species.Style) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Species.allCases.filter { $0.style == style }) { sp in
                    PetCard(species: sp, selected: settings.species == sp)
                        .onTapGesture { settings.species = sp }
                }
            }
        }
    }

    /// The pet on a tinted stage, with how it feels, its needs and the things you can do for it.
    private var hero: some View {
        let sp = settings.species
        return Card {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: sp.fur).opacity(0.22))
                    PetPreview(species: sp).frame(width: 104, height: 104)
                }
                .frame(width: 128, height: 128)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(sp.name).font(.system(size: 20, weight: .bold))
                            Text(sp.tagline).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        FeelingPill(feeling: mind.feeling)
                    }
                    Text("\(mind.bondTitle) · Level \(mind.level) · Day \(mind.daysTogether)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 8) {
                        Meter(symbol: "bolt.fill", label: "Energy", value: mind.energy, tint: .orange)
                        Meter(symbol: "fork.knife", label: "Tummy", value: mind.fullness, tint: .green)
                        Meter(symbol: "heart.fill", label: "Joy", value: mind.joy, tint: .pink)
                        Meter(symbol: "person.2.fill", label: "Bond", value: mind.levelProgress, tint: .purple)
                    }
                }
            }
            .padding(14)
            Divider()
            HStack(spacing: 8) {
                Button(action: onTreat) { Label("Give a treat", systemImage: "gift") }
                Button(action: onPlay) { Label("Play ball", systemImage: "soccerball") }
                Spacer()
                Button(action: onSayHi) { Label("Say hi", systemImage: "hand.wave") }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}
