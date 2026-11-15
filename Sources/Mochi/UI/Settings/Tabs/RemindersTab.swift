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
