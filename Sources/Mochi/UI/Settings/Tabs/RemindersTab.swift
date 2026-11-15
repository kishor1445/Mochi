import SwiftUI

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

    private func tint(_ k: ReminderKind) -> Color {
        switch k {
        case .water: return .blue
        case .posture: return .green
        case .eyes: return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardSection(title: "Gentle reminders",
                        footer: "Reminders count time you are at your Mac, and wait while you are on a call or in a focus session.") {
                ForEach(ReminderKind.allCases) { kind in
                    SettingRow(symbol: kind.symbol, tint: tint(kind), title: kind.label) {
                        if settings.interval(kind) != nil {
                            Picker("Every", selection: minutes(kind)) {
                                ForEach(ReminderKind.intervals, id: \.self) { Text("Every \($0) min").tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }
                        Toggle(kind.label, isOn: isOn(kind)).labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }
                    RowDivider()
                }
                ToggleRow(symbol: "figure.cooldown", tint: .orange, title: "Stretch after 50 minutes of work",
                          isOn: $settings.breakReminders)
            }
            CardSection(title: "Your day",
                        footer: "Calendar alerts ask macOS for access the first time. Event titles are only shown in the bubble.") {
                ToggleRow(symbol: "calendar", tint: .red, title: "Calendar alerts",
                          subtitle: "A heads-up 5 minutes before events and as they start", isOn: $settings.calendarAlerts)
                RowDivider()
                ToggleRow(symbol: "chart.bar.fill", tint: .indigo, title: "Daily check-in",
                          subtitle: "A recap at 6 pm and the next morning", isOn: $settings.dailyCheckIn)
            }
        }
    }
}
