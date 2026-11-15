import SwiftUI

/// How the pet is doing right now: feeling, needs and the bond with you.
struct StatusCard: View {
    @ObservedObject var mind: PetMind
    let species: Species

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(species.name) is \(mind.feeling.label.lowercased()) \(mind.feeling.emoji)").font(.headline)
                    Text(species.tagline).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(mind.bondTitle).font(.subheadline.weight(.medium))
                    Text("Level \(mind.level) · Day \(mind.daysTogether)").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 14) {
                Meter(symbol: "bolt.fill", label: "Energy", value: mind.energy, tint: .orange)
                Meter(symbol: "fork.knife", label: "Tummy", value: mind.fullness, tint: .green)
                Meter(symbol: "heart.fill", label: "Joy", value: mind.joy, tint: .pink)
                Meter(symbol: "person.2.fill", label: "Bond", value: mind.levelProgress, tint: .purple)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
    }
}
