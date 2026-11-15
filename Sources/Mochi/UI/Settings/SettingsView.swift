import SwiftUI
import AppKit

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
