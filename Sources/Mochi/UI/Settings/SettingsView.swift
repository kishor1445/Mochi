import SwiftUI
import AppKit

enum SettingsPage: String, CaseIterable, Identifiable {
    case pet, behavior, reminders, today, ai, general, debug

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pet: return "Pet"
        case .behavior: return "Behavior"
        case .reminders: return "Reminders"
        case .today: return "Today"
        case .ai: return "AI"
        case .general: return "General"
        case .debug: return "Debug"
        }
    }

    var subtitle: String {
        switch self {
        case .pet: return "Who lives on your screen, and how they're doing"
        case .behavior: return "Where your pet goes and what it notices"
        case .reminders: return "Gentle nudges while you work"
        case .today: return "Your day in numbers"
        case .ai: return "Give your pet a language model to think and talk with"
        case .general: return "Size, speech and system options"
        case .debug: return "Test reminders and see what the pet notices"
        }
    }

    var symbol: String {
        switch self {
        case .pet: return "pawprint.fill"
        case .behavior: return "figure.walk"
        case .reminders: return "bell.fill"
        case .today: return "chart.bar.fill"
        case .ai: return "sparkles"
        case .general: return "gearshape.fill"
        case .debug: return "ladybug.fill"
        }
    }
}

/// Which page is showing. (An observable object rather than `@State`, which needs a macro plugin
/// the command-line toolchain doesn't ship.)
final class SettingsNav: ObservableObject {
    @Published var page: SettingsPage
    init(_ page: SettingsPage = .pet) { self.page = page }
}

/// The settings window: a sidebar of pages on the left, the chosen page on the right.
struct SettingsView: View {
    static let size = NSSize(width: 700, height: 580)

    @ObservedObject var settings: PetSettings
    @ObservedObject var mind = PetMind.shared
    var onSayHi: () -> Void
    var onBringBack: () -> Void
    var onTreat: () -> Void
    var onPlay: () -> Void
    @ObservedObject var nav: SettingsNav

    private var page: SettingsPage { nav.page }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                PetPreview(species: settings.species)
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 1) {
                    Text(settings.species.name).font(.system(size: 14, weight: .semibold))
                    Text(mind.bondTitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)

            ForEach(SettingsPage.allCases) { p in
                Button { nav.page = p } label: {
                    HStack(spacing: 9) {
                        Image(systemName: p.symbol)
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 20)
                            .foregroundStyle(page == p ? Color.white : Color.accentColor)
                        Text(p.title).font(.system(size: 13, weight: page == p ? .semibold : .regular))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(page == p ? Color.white : Color.primary)
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(page == p ? Color.accentColor : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(page == p ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
            Text("Mochi \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 10)
        .padding(.top, 46)                     // clears the window's close button
        .padding(.bottom, 12)
        .frame(width: 184)
        .frame(maxHeight: .infinity)
        .background(SidebarBackground())
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title).font(.system(size: 22, weight: .bold))
                Text(page.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 14)

            ScrollView {
                Group {
                    switch page {
                    case .pet: PetTab(settings: settings, onSayHi: onSayHi, onTreat: onTreat, onPlay: onPlay)
                    case .behavior: BehaviorTab(settings: settings)
                    case .reminders: RemindersTab(settings: settings)
                    case .today: TodayTab(log: .shared)
                    case .ai: AITab(settings: settings)
                    case .general: GeneralTab(settings: settings, onBringBack: onBringBack)
                    case .debug: DebugTab(settings: settings)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
