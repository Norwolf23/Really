import FamilyControls
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: Store

    @State private var step = 0
    @State private var meanness = Tier.normal
    @State private var picking = false
    @State private var denied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                switch step {
                case 0:
                    page(title: "Really?", body: "You open apps you don't mean to. This asks first.", button: "Go on")
                case 1:
                    page(title: "How it works",
                         body: "You pick the apps.\niOS puts Really? in front of them.\nAnswer, or don't.",
                         button: "Fine")
                case 2:
                    page(title: "You downloaded an app to stop using apps.", body: "Really?", button: "Yes, really.")
                case 3:
                    chooseApps
                case 4:
                    chooseMeanness
                default:
                    page(title: "Done.", body: "Go open one of them. See what happens.", button: "Fine") { finish() }
                }
            }
            .id(step)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .onAppear { meanness = store.settings.meanness }
        .familyActivityPicker(isPresented: $picking, selection: $store.settings.selection)
    }

    // MARK: pages

    private func page(title: String, body: String, button: String, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 28) {
            Spacer()
            Text(title)
                .font(.system(size: 36, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Text(body)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
            Spacer()
            primary(button) { action?() ?? (step += 1) }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    private var chooseApps: some View {
        let count = store.settings.selection.applicationTokens.count
        return VStack(spacing: 20) {
            heading("Which apps?")
            Text("iOS will ask for Screen Time access. Really? only uses it to stand in front of the apps you pick.")
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Spacer()
            if count > 0 {
                Text("\(count) picked").foregroundStyle(.white)
            }
            if denied {
                Text("Allow Really? under Settings → Screen Time → Apps with Screen Time Access, then try again.")
                    .font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
            primary(count > 0 ? "Change apps" : "Pick apps") {
                Task { if await Shield.authorize() { picking = true } else { denied = true } }
            }
            Button("Continue") {
                Shield.apply(store.settings.selection)
                step += 1
            }
            .foregroundStyle(count > 0 ? .white : .gray)
            .disabled(count == 0)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    private var chooseMeanness: some View {
        let samples = Packs.questions(for: "generic")
        return VStack(spacing: 20) {
            heading("How mean?")
            ForEach(Tier.allCases, id: \.self) { tier in
                Button { meanness = tier } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(OnboardingView.name(for: tier)).font(.headline).foregroundStyle(.white)
                        Text(samples.first { $0.tier == tier }?.text ?? "")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(meanness == tier ? .white : .white.opacity(0.15), lineWidth: 1))
                }
            }
            Spacer()
            primary("Continue") {
                store.settings.meanness = meanness
                step += 1
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    // MARK: pieces

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 32, weight: .semibold, design: .serif))
            .foregroundStyle(.white)
            .padding(.top, 36)
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
    }

    private func finish() {
        store.settings.hasOnboarded = true
    }

    static func name(for tier: Tier) -> String {
        switch tier {
        case .normal: "Mild"
        case .annoyed: "Mean"
        case .brutal: "Brutal"
        }
    }
}
