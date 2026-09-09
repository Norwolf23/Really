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
                    Picker("Ask again after", selection: $store.settings.cooldownMinutes) {
                        Text("As soon as iOS allows (about 16 min)").tag(15)
                        Text("1 hour").tag(60)
                        Text("3 hours").tag(180)
                        Text("6 hours").tag(360)
                        Text("12 hours").tag(720)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Ask again after")
                } footer: {
                    Text("Once you go through, the question stays away this long, then the shield is back.")
                }
                Section {
                    Stepper("Mean from open #\(store.settings.annoyedAt)", value: $store.settings.annoyedAt, in: 1...50)
                    Stepper("Brutal from open #\(store.settings.brutalAt)", value: $store.settings.brutalAt, in: 1...50)
                } header: {
                    Text("Escalation")
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
