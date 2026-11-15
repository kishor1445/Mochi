import SwiftUI

struct GeneralTab: View {
    @ObservedObject var settings: PetSettings
    var onBringBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardSection(title: "Appearance") {
                SettingRow(symbol: "arrow.up.left.and.arrow.down.right", tint: .blue, title: "Size") {
                    Picker("Size", selection: $settings.petSize) {
                        ForEach(PetSize.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                }
                RowDivider()
                SettingRow(symbol: "bubble.left.fill", tint: .green, title: "Speech bubbles") {
                    Picker("Speech bubbles", selection: $settings.chattiness) {
                        ForEach(Chattiness.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 260)
                }
            }
            CardSection(title: "System") {
                SettingRow(symbol: "power", tint: .gray, title: "Launch at login",
                           subtitle: LoginItem.available ? nil : "Needs the built Mochi.app") {
                    Toggle("Launch at login", isOn: Binding(get: { settings.launchAtLogin },
                                                            set: { settings.launchAtLogin = LoginItem.set($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                        .disabled(!LoginItem.available)
                }
                RowDivider()
                SettingRow(symbol: "arrow.uturn.backward", tint: .orange, title: "Lost your pet?",
                           subtitle: "Drops it back in from the top of the screen") {
                    Button("Bring back", action: onBringBack)
                }
            }
        }
    }
}
