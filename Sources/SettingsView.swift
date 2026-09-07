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
                    Text("Counts each app's opens today against the thresholds below.")
                }
                Section {
                    Stepper("Cooldown: \(store.settings.cooldownMinutes) min", value: $store.settings.cooldownMinutes, in: 15...240, step: 15)
                    Stepper("Annoyed from open #\(store.settings.annoyedAt)", value: $store.settings.annoyedAt, in: 1...50)
                    Stepper("Brutal from open #\(store.settings.brutalAt)", value: $store.settings.brutalAt, in: 1...50)
                } header: {
                    Text("Friction")
                } footer: {
                    Text("After Yes, really the app stays open for the cooldown, then the shield comes back.")
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
