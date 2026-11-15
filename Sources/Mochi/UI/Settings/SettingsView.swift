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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
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
            Section {
                Toggle("React to music, videos and calls", isOn: $settings.reactToMedia)
                Toggle("Bop along while I type", isOn: $settings.reactToTyping)
                Toggle("Comment on battery, time of day and a busy Mac", isOn: $settings.systemAware)
            } header: {
                Text("Paying attention")
            } footer: {
                Text("Typing is only counted, never read. Nothing leaves your Mac.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Reminders tab

struct RemindersTab: View {
    @ObservedObject var settings: PetSettings

    private func isOn(_ k: ReminderKind) -> Binding<Bool> {
        Binding(get: { settings.interval(k) != nil },
                set: { settings.reminderMinutes[k.rawValue] = $0 ? k.defaultMinutes : 0 })
    }

    private func minutes(_ k: ReminderKind) -> Binding<Int> {
        Binding(get: { settings.interval(k) ?? k.defaultMinutes },
                set: { settings.reminderMinutes[k.rawValue] = $0 })
    }

    var body: some View {
        Form {
            Section {
                ForEach(ReminderKind.allCases) { kind in
                    HStack {
                        Label(kind.label, systemImage: kind.symbol)
                        Spacer()
                        if settings.interval(kind) != nil {
                            Picker("Every", selection: minutes(kind)) {
                                ForEach(ReminderKind.intervals, id: \.self) { Text("every \($0) min").tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }
                        Toggle(kind.label, isOn: isOn(kind)).labelsHidden()
                    }
                }
                Toggle(isOn: $settings.breakReminders) {
                    Label("Stretch after 50 minutes of work", systemImage: "figure.cooldown")
                }
            } header: {
                Text("Gentle reminders")
            } footer: {
                Text("Reminders count time you are at your Mac, and wait while you are on a call or in a focus session.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section {
                Toggle(isOn: $settings.calendarAlerts) {
                    Label("Warn me 5 minutes before calendar events", systemImage: "calendar")
                }
                Toggle(isOn: $settings.dailyCheckIn) {
                    Label("Daily check-in at 6 pm and the next morning", systemImage: "chart.bar")
                }
            } header: {
                Text("Your day")
            } footer: {
                Text("Calendar alerts ask macOS for access the first time. Event titles are only shown in the bubble.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Today tab

struct StatTile: View {
    let symbol: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(tint).frame(height: 18)
            Text(value).font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct TodayTab: View {
    @ObservedObject var log: DailyLog

    var body: some View {
        let t = log.today
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                StatTile(symbol: "desktopcomputer", value: DayStats.minutes(t.activeSeconds), label: "At your Mac", tint: .blue)
                StatTile(symbol: "keyboard", value: DayStats.minutes(t.typingSeconds), label: "Typing", tint: .indigo)
                StatTile(symbol: "timer", value: t.focusSessions == 0 ? "0" : "\(t.focusSessions) · \(t.focusMinutes)m",
                         label: "Focus sessions", tint: .purple)
                StatTile(symbol: "cup.and.saucer", value: "\(t.breaks)", label: "Breaks", tint: .orange)
                StatTile(symbol: "heart", value: "\(t.pets + t.treats)", label: "Pets and treats", tint: .pink)
                StatTile(symbol: "soccerball", value: "\(t.plays)", label: "Games played · best rally \(UserDefaults.standard.integer(forKey: "bestRally"))", tint: .green)
            }
            if let y = log.yesterday, !y.isEmpty {
                Text(y.summary(prefix: "Yesterday"))
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
            }
            Text("Only counts and durations are kept, on this Mac. Nothing about what you type or do.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(20)
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
    static let size = NSSize(width: 520, height: 500)

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
            RemindersTab(settings: settings)
                .tabItem { Label("Reminders", systemImage: "bell") }
            TodayTab(log: .shared)
                .tabItem { Label("Today", systemImage: "chart.bar") }
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
