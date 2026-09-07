import FamilyControls
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
                    Stepper("Ask again after: \(store.settings.cooldownMinutes) min", value: $store.settings.cooldownMinutes, in: 15...240, step: 15)
                    Stepper("Annoyed from open #\(store.settings.annoyedAt)", value: $store.settings.annoyedAt, in: 1...50)
                    Stepper("Brutal from open #\(store.settings.brutalAt)", value: $store.settings.brutalAt, in: 1...50)
                } header: {
                    Text("Friction")
                } footer: {
                    Text("Once you go through, the question stays away this long. 15 min is the shortest iOS allows.")
                }
                Section("Intro") {
                    Button("Replay intro") { store.settings.hasOnboarded = false }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    LabeledContent("Last button", value: store.state.lastAction ?? "never")
                    LabeledContent("Screen Time", value: AuthorizationCenter.shared.authorizationStatus == .approved ? "allowed" : "not allowed")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
