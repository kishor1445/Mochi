import SwiftUI

/// Test page: fire each reminder on demand, see what the pet thinks is going on, and stage two-pet meetings.
struct DebugTab: View {
    @ObservedObject var settings: PetSettings
    @ObservedObject var debug = PetDebug.shared

    private func fire(_ a: DebugAction) { debug.fire?(a) }

    private func tint(_ k: ReminderKind) -> Color {
        switch k {
        case .water: return .blue
        case .posture: return .green
        case .eyes: return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardSection(title: "Reminders",
                        footer: "Test shows the reminder straight away, even if it is switched off. Skip ahead moves every clock forward, so you can watch a real one come due.") {
                ForEach(ReminderKind.allCases) { kind in
                    SettingRow(symbol: kind.symbol, tint: tint(kind), title: kind.label,
                               subtitle: debug.reminders[kind.rawValue] ?? "…") {
                        Button("Test") { fire(.reminder(kind)) }
                    }
                    RowDivider()
                }
                SettingRow(symbol: "figure.cooldown", tint: .orange, title: "Stretch break",
                           subtitle: debug.reminders["stretch"] ?? "…") {
                    Button("Test") { fire(.stretch) }
                }
                RowDivider()
                SettingRow(symbol: "calendar", tint: .red, title: "Calendar alert", subtitle: "A made-up event, 5 minutes away") {
                    Button("Test") { fire(.calendar) }
                }
                RowDivider()
                SettingRow(symbol: "chart.bar.fill", tint: .indigo, title: "Daily check-in", subtitle: "Today so far") {
                    Button("Test") { fire(.checkIn) }
                }
                RowDivider()
                SettingRow(symbol: "forward.fill", tint: .gray, title: "Skip ahead", subtitle: debug.reminderState) {
                    Button("5 min") { fire(.skip(minutes: 5)) }
                    Button("15 min") { fire(.skip(minutes: 15)) }
                }
            }

            CardSection(title: "What the pet notices") {
                SettingRow(symbol: "person.fill", tint: .blue, title: "You", subtitle: debug.presence) { EmptyView() }
                RowDivider()
                SettingRow(symbol: "speaker.wave.2.fill", tint: .pink, title: "Sound: \(debug.sound)",
                           subtitle: debug.soundApps.isEmpty ? "No app is using the speakers" : debug.soundApps.joined(separator: "\n")) {
                    EmptyView()
                }
            }

            CardSection(title: "Two pets", footer: debug.pets) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(SocialKind.allCases) { kind in
                        Button { fire(.meet(kind)) } label: { Text(kind.label).frame(maxWidth: .infinity) }
                    }
                }
                .padding(12)
                .disabled(!settings.secondPet)
            }
        }
    }
}
