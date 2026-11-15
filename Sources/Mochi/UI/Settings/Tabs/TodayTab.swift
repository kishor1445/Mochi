import SwiftUI

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
