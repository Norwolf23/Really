import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openURL) private var openURL

    @State private var step = 0
    @State private var chosen: Set<String> = []
    @State private var meanness = Tier.normal

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                switch step {
                case 0:
                    page(title: "Really?", body: "You open apps you don't mean to. This asks first.", button: "Go on")
                case 1:
                    page(title: "How it works",
                         body: "An automation runs when one of your apps opens.\nReally? asks you a question.\nContinue after a pause, or say No.",
                         button: "Fine")
                case 2:
                    page(title: "You downloaded an app to stop using apps.", body: "Really?", button: "Yes, really.")
                case 3:
                    chooseApps
                case 4:
                    chooseMeanness
                default:
                    setup
                }
            }
            .id(step)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: pages

    private func page(title: String, body: String, button: String) -> some View {
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
            primary(button) { step += 1 }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    private var chooseApps: some View {
        VStack(spacing: 20) {
            heading("Which apps?")
            List {
                ForEach(Catalog.entries) { entry in
                    Button {
                        if chosen.contains(entry.id) { chosen.remove(entry.id) } else { chosen.insert(entry.id) }
                    } label: {
                        HStack {
                            Text(entry.name).foregroundStyle(.white)
                            Spacer()
                            if chosen.contains(entry.id) { Image(systemName: "checkmark").foregroundStyle(.white) }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            primary("Continue") {
                for entry in Catalog.entries where chosen.contains(entry.id) && store.app(entry.id) == nil {
                    store.update(Catalog.gatedApp(entry))
                }
                step += 1
            }
            .disabled(chosen.isEmpty)
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

    private var setup: some View {
        let name = store.apps.first?.name ?? "the app"
        return VStack(spacing: 20) {
            heading("Set up \(name)")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(SetupView.steps(appName: name).enumerated()), id: \.offset) { index, text in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)").bold().foregroundStyle(.gray).frame(width: 18)
                            Text(text).foregroundStyle(.white)
                        }
                    }
                }
            }
            primary("Open Shortcuts") {
                finish()
                if let url = URL(string: "shortcuts://") { openURL(url) }
            }
            Button("I'll do it later") { finish() }
                .foregroundStyle(.gray)
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
