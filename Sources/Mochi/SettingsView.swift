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

struct PetCard: View {
    let species: Species
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            PetPreview(species: species)
                .frame(width: PetView.side, height: PetView.side)
            Text(species.name).font(.headline)
            Text(species.tagline).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SettingsView: View {
    @ObservedObject var settings: PetSettings
    var onSayHi: () -> Void
    var onBringBack: () -> Void
    var onTreat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Choose your pet").font(.title3.weight(.semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(Species.allCases) { sp in
                    PetCard(species: sp, selected: settings.species == sp)
                        .onTapGesture { settings.species = sp }
                }
            }

            Divider()

            HStack {
                Text("Speech bubbles")
                Spacer()
                Picker("", selection: $settings.chattiness) {
                    ForEach(Chattiness.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 270)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Walk and leap onto windows", isOn: $settings.walkOnWindows)
                Toggle("Climb screen edges and hang from the top", isOn: $settings.climbEdges)
                Toggle("Chase my cursor sometimes", isOn: $settings.followCursor)
                Toggle("React to music, videos and calls", isOn: $settings.reactToMedia)
                Toggle("Remind me to take a break", isOn: $settings.breakReminders)
                Toggle("Comment on battery and time of day", isOn: $settings.systemAware)
            }

            HStack {
                Text("Tip: drag your pet to a screen edge and let go. It will cling there.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            HStack {
                Button("Bring back to screen", action: onBringBack)
                Spacer()
                Button("Give a treat \(settings.species.treatEmoji)", action: onTreat)
                Button("Say hi!", action: onSayHi)
            }
        }
        .padding(22)
        .frame(width: 500)
    }
}

/// Owns the settings window.
final class SettingsWindowController {
    private var window: NSWindow?
    private let onSayHi: () -> Void
    private let onBringBack: () -> Void
    private let onTreat: () -> Void

    init(onSayHi: @escaping () -> Void, onBringBack: @escaping () -> Void, onTreat: @escaping () -> Void) {
        self.onSayHi = onSayHi
        self.onBringBack = onBringBack
        self.onTreat = onTreat
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: .shared, onSayHi: onSayHi, onBringBack: onBringBack, onTreat: onTreat))
            let w = NSWindow(contentViewController: hosting)
            w.title = "Pet Settings"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
