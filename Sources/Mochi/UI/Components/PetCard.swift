import SwiftUI

struct PetCard: View {
    let species: Species
    let selected: Bool

    var body: some View {
        VStack(spacing: 2) {
            PetPreview(species: species)
                .frame(width: 64, height: 64)
            Text(species.name).font(.system(size: 12, weight: selected ? .semibold : .regular))
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(species.name), \(species.tagline)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
