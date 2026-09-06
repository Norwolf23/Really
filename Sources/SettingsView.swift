import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Meanness", selection: $store.settings.meanness) {
                        Text("Mild").tag(Tier.normal)
                        Text("Mean").tag(Tier.annoyed)
                        Text("Brutal").tag(Tier.brutal)
                    }
                    Toggle("Gets meaner through the day", isOn: $store.settings.escalates)
                } header: {
                    Text("Tone")
                } footer: {
                    Text("Uses each app's Annoyed and Brutal thresholds.")
                }
                Section("Intro") {
                    Button("Replay intro") { store.settings.hasOnboarded = false }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
