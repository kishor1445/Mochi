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

/// A thin capsule meter with an icon: one of the pet's needs.
struct Meter: View {
    let symbol: String
    let label: String
    let value: Double
    let tint: Color
    var showLabel = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabel {
                Label(label, systemImage: symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                if !showLabel {
                    Image(systemName: symbol).font(.system(size: 9)).foregroundStyle(tint).frame(width: 11)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.10))
                        Capsule().fill(tint).frame(width: max(5, geo.size.width * min(1, max(0, value))))
                    }
                }
                .frame(height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(Int((value * 100).rounded())) percent")
    }
}

/// The compact card at the top of the menu bar dropdown: who the pet is and how it's doing.
struct MenuHeader: View {
    @ObservedObject var mind: PetMind
    let species: Species

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(species.name).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(mind.feeling.label) \(mind.feeling.emoji)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Meter(symbol: "bolt.fill", label: "Energy", value: mind.energy, tint: .orange, showLabel: false)
                Meter(symbol: "fork.knife", label: "Tummy", value: mind.fullness, tint: .green, showLabel: false)
                Meter(symbol: "heart.fill", label: "Joy", value: mind.joy, tint: .pink, showLabel: false)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 9)
        .frame(width: 230)
    }
}

// MARK: Pet tab

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

struct PetTab: View {
    @ObservedObject var settings: PetSettings
    var onSayHi: () -> Void
    var onTreat: () -> Void
    var onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(Species.allCases) { sp in
                    PetCard(species: sp, selected: settings.species == sp)
                        .onTapGesture { settings.species = sp }
                }
            }
            StatusCard(mind: .shared, species: settings.species)
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

// MARK: Behavior tab

struct BehaviorTab: View {
    @ObservedObject var settings: PetSettings

    var body: some View {
        Form {
            Section("Moving around") {
                Toggle("Walk and leap onto windows", isOn: $settings.walkOnWindows)
                Toggle("Climb screen edges and hang from the top", isOn: $settings.climbEdges)
                Toggle("Chase my cursor sometimes", isOn: $settings.followCursor)
            }
            Section("Paying attention") {
                Toggle("React to music, videos and calls", isOn: $settings.reactToMedia)
                Toggle("Bop along while I type", isOn: $settings.reactToTyping)
                Toggle("Remind me to take a break", isOn: $settings.breakReminders)
                Toggle("Comment on battery and time of day", isOn: $settings.systemAware)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: General tab

struct GeneralTab: View {
    @ObservedObject var settings: PetSettings
    var onBringBack: () -> Void

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Size", selection: $settings.petSize) {
                    ForEach(PetSize.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Speech bubbles", selection: $settings.chattiness) {
                    ForEach(Chattiness.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle("Launch at login", isOn: Binding(get: { settings.launchAtLogin },
                                                        set: { settings.launchAtLogin = LoginItem.set($0) }))
                    .disabled(!LoginItem.available)
                LabeledContent("Lost your pet?") {
                    Button("Bring back to screen", action: onBringBack)
                }
            } header: {
                Text("System")
            } footer: {
                if !LoginItem.available {
                    Text("Launch at login needs the built Mochi.app.")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Window

struct SettingsView: View {
    static let size = NSSize(width: 500, height: 390)

    @ObservedObject var settings: PetSettings
    var onSayHi: () -> Void
    var onBringBack: () -> Void
    var onTreat: () -> Void
    var onPlay: () -> Void

    var body: some View {
        TabView {
            PetTab(settings: settings, onSayHi: onSayHi, onTreat: onTreat, onPlay: onPlay)
                .tabItem { Label("Pet", systemImage: "pawprint") }
            BehaviorTab(settings: settings)
                .tabItem { Label("Behavior", systemImage: "figure.walk") }
            GeneralTab(settings: settings, onBringBack: onBringBack)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .padding(.top, 10)
        .frame(width: Self.size.width, height: Self.size.height + 40)
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
            w.title = "Mochi Settings"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
