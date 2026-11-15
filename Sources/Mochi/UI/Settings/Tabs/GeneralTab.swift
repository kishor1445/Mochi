import SwiftUI

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
