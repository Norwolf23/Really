import FamilyControls
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("PREFERENCES")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Palette.dim)
                    VStack(spacing: 10) {
                        node("Full block", value: fullBlockValue) { FullBlockView() }
                        node("Tone", value: OnboardingView.name(for: store.settings.meanness)) { ToneSettings() }
                        node("Timing", value: timingValue) { TimingSettings() }
                        node("Escalation", value: store.settings.gentleFirst ? "Gentle first" : "Straight to questions") { EscalationSettings() }
                        node("About", value: version) { AboutSettings() }
                    }
                }
                .padding(20)
            }
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func node<Destination: View>(_ title: String, value: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Text(value)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Palette.dim)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.dim)
            }
            .padding(14)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var fullBlockValue: String {
        if !store.settings.fullBlockEnabled, let off = store.settings.fullBlockOffAt, Date.now < off { return "Until tomorrow" }
        return Logic.fullBlockIsActive(enabled: store.settings.fullBlockEnabled, offAt: store.settings.fullBlockOffAt, now: .now) ? "On" : "Off"
    }

    private var timingValue: String {
        switch store.settings.cooldownMinutes {
        case 15: "16 min"
        case 60: "1 hour"
        case 180: "3 hours"
        case 360: "6 hours"
        case 720: "12 hours"
        default: "\(store.settings.cooldownMinutes) min"
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private enum Palette {
        static let bg = Color(red: 0.03, green: 0.035, blue: 0.04)
        static let panel = Color(red: 0.07, green: 0.075, blue: 0.082)
        static let line = Color.white.opacity(0.12)
        static let dim = Color.white.opacity(0.45)
    }
}

private struct ToneSettings: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Form {
            Section {
                Picker("Meanness", selection: $store.settings.meanness) {
                    Text("Mild").tag(Tier.normal)
                    Text("Mean").tag(Tier.annoyed)
                    Text("Brutal").tag(Tier.brutal)
                }
                Toggle("Gets meaner through the day", isOn: $store.settings.escalates)
            } footer: {
                Text("Counts each app's opens today against the thresholds in Escalation.")
            }
        }
        .prefs()
        .navigationTitle("Tone")
    }
}

private struct TimingSettings: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Form {
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
            } footer: {
                Text("Once you go through, the question stays away this long, then the shield is back.")
            }
        }
        .prefs()
        .navigationTitle("Timing")
    }
}

private struct EscalationSettings: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Form {
            Section {
                Toggle("Gentle reminders first", isOn: $store.settings.gentleFirst)
                Stepper("Mean from open #\(store.settings.annoyedAt)", value: $store.settings.annoyedAt, in: 1...50)
                Stepper("Brutal from open #\(store.settings.brutalAt)", value: $store.settings.brutalAt, in: 1...50)
            } footer: {
                Text("The first four or five opens of an app each day only get a reminder and one button. Questions start after that.")
            }
        }
        .prefs()
        .navigationTitle("Escalation")
    }
}

private struct AboutSettings: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Form {
            Section {
                Button("Replay intro") { store.settings.hasOnboarded = false }
            }
            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                LabeledContent("Last button", value: store.state.lastAction ?? "never")
                LabeledContent("Screen Time", value: AuthorizationCenter.shared.authorizationStatus == .approved ? "allowed" : "not allowed")
            }
        }
        .prefs()
        .navigationTitle("About")
    }
}

private extension View {
    func prefs() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.03, green: 0.035, blue: 0.04).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
