import SwiftUI

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
