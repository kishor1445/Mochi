import SwiftUI
import AppKit

/// Live animated preview of a pet, used on the picker cards.
struct PetPreview: NSViewRepresentable {
    let species: Species

    func makeNSView(context: Context) -> PetView {
        let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
        v.isPreview = true
        v.species = species
        return v
    }

    func updateNSView(_ v: PetView, context: Context) { v.species = species }
}
