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

/// One labelled need bar on the status card.
struct NeedBar: View {
    let icon: String
    let label: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(icon) \(label)").font(.caption).foregroundStyle(.secondary)
            ProgressView(value: min(1, max(0, value))).tint(tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(Int((value * 100).rounded())) percent")
    }
}

/// How the pet is doing right now: feeling, needs and the bond with you.
struct StatusCard: View {
    @ObservedObject var mind: PetMind
    let species: Species

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(species.name) is \(mind.feeling.label.lowercased()) \(mind.feeling.emoji)")
                    .font(.headline)
                Spacer()
                Text("\(mind.bondTitle) · level \(mind.level) · day \(mind.daysTogether)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                NeedBar(icon: "⚡️", label: "Energy", value: mind.energy, tint: .orange)
                NeedBar(icon: species.treatEmoji, label: "Tummy", value: mind.fullness, tint: .green)
                NeedBar(icon: "💖", label: "Joy", value: mind.joy, tint: .pink)
                NeedBar(icon: "🤝", label: "Bond", value: mind.levelProgress, tint: .purple)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.05)))
    }
}

struct SettingsView: View {
    @ObservedObject var settings: PetSettings
    var onSayHi: () -> Void
    var onBringBack: () -> Void
    var onTreat: () -> Void
    var onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Choose your pet").font(.title3.weight(.semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(Species.allCases) { sp in
                    PetCard(species: sp, selected: settings.species == sp)
                        .onTapGesture { settings.species = sp }
                }
            }

            StatusCard(mind: .shared, species: settings.species)

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
                Toggle(LoginItem.available ? "Launch at login" : "Launch at login (needs the built Mochi.app)",
                       isOn: Binding(get: { settings.launchAtLogin }, set: { settings.launchAtLogin = LoginItem.set($0) }))
                    .disabled(!LoginItem.available)
            }

            HStack {
                Text("Tip: treats, play and pets keep your pet happy and grow your bond. Right-click it for a focus session.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            HStack {
                Button("Bring back to screen", action: onBringBack)
                Spacer()
                Button("Play ball \(settings.species.toyEmoji)", action: onPlay)
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
    private let onPlay: () -> Void

    init(onSayHi: @escaping () -> Void, onBringBack: @escaping () -> Void, onTreat: @escaping () -> Void,
         onPlay: @escaping () -> Void) {
        self.onSayHi = onSayHi
        self.onBringBack = onBringBack
        self.onTreat = onTreat
        self.onPlay = onPlay
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: .shared, onSayHi: onSayHi, onBringBack: onBringBack, onTreat: onTreat, onPlay: onPlay))
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
