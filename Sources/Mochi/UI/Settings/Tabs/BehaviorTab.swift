import SwiftUI

struct BehaviorTab: View {
    @ObservedObject var settings: PetSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardSection(title: "Moving around") {
                ToggleRow(symbol: "macwindow", tint: .green, title: "Walk and leap onto windows",
                          subtitle: "Stands on window tops and follows them around", isOn: $settings.walkOnWindows)
                RowDivider()
                ToggleRow(symbol: "arrow.up.to.line", tint: .teal, title: "Climb screen edges",
                          subtitle: "Walks up the sides and hangs from the top", isOn: $settings.climbEdges)
                RowDivider()
                ToggleRow(symbol: "cursorarrow.rays", tint: .blue, title: "Chase my cursor sometimes",
                          isOn: $settings.followCursor)
            }
            CardSection(title: "Paying attention",
                        footer: "Typing is only counted, never read. Nothing leaves your Mac.") {
                ToggleRow(symbol: "music.note", tint: .pink, title: "React to music, videos and calls",
                          subtitle: "Dances to music, settles for videos, goes quiet on calls", isOn: $settings.reactToMedia)
                RowDivider()
                ToggleRow(symbol: "speaker.wave.2.fill", tint: .purple, title: "React to other sound too",
                          subtitle: "Browsers, games and other apps. Off by default: many apps hold the speakers open while silent",
                          isOn: $settings.reactToOtherAudio)
                RowDivider()
                ToggleRow(symbol: "keyboard", tint: .indigo, title: "Bop along while I type",
                          isOn: $settings.reactToTyping)
                RowDivider()
                ToggleRow(symbol: "bolt.fill", tint: .orange, title: "Comment on my Mac",
                          subtitle: "Battery, time of day and a busy processor", isOn: $settings.systemAware)
            }
        }
    }
}
