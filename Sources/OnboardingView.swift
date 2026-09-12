import FamilyControls
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openURL) private var openURL

    @State private var step = 0
    @State private var meanness = Tier.normal
    @State private var suggested: [Catalog.Entry] = [] // in the order they were tapped
    @State private var picking = false
    @State private var denied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                switch step {
                case 0:
                    page(title: "Are you aware of every time you mindlessly scroll?",
                         body: "Most of the time it just happens.\nYour thumb gets there before you do.",
                         button: "Not really")
                case 1:
                    page(title: "This blocks nothing.",
                         body: "It just asks, so you notice what you're doing.\nThen you choose. Go in, or don't.",
                         button: "Okay")
                case 2:
                    page(title: "You downloaded an app to stop using apps.", body: "Really?", button: "Yes, really.")
                case 3:
                    chooseMeanness
                case 4:
                    chooseApps
                default:
                    done
                }
            }
            .id(step)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .onAppear { meanness = store.settings.meanness }
        .familyActivityPicker(isPresented: $picking, selection: $store.settings.selection)
        .onChange(of: picking) { _, open in
            // The picker closed: iOS has the real list now. Shield it and move on.
            guard !open, !store.settings.selection.applicationTokens.isEmpty else { return }
            Shield.apply(store.settings.selection)
            step = 5
        }
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

    private var chooseMeanness: some View {
        let samples = Packs.questions(for: "instagram")
        return VStack(spacing: 20) {
            heading("How mean?")
            Text("It gets meaner the more you come back today.").foregroundStyle(.gray)
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

    /// Suggestion tiles first, then Apple's picker. The tiles can't shield anything themselves: iOS only shields
    /// what's ticked in its own list, and that list can't be pre-ticked. They tell the person what to tick.
    private var chooseApps: some View {
        VStack(spacing: 16) {
            heading("Which apps?")
            Text("Pick the ones that open themselves.").foregroundStyle(.gray)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(Catalog.entries) { entry in
                    let on = suggested.contains(entry)
                    Button {
                        if on { suggested.removeAll { $0 == entry } } else { suggested.append(entry) }
                    } label: {
                        Text(entry.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(on ? Color.white : Color(white: 0.09), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(on ? .black : .white)
                    }
                }
            }
            Text(suggested.isEmpty ? "Nothing picked yet." : "\(suggested.count) picked. Tick the same ones in the next screen.")
                .font(.footnote).foregroundStyle(.gray)
            if denied {
                Text("Allow Really? under Settings → Screen Time → Apps with Screen Time Access, then try again.")
                    .font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
            Spacer()
            primary("Continue") { openPicker() }
                .disabled(suggested.isEmpty)
            Button("Select more…") { openPicker() }
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    private var done: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("That's it.")
                .font(.system(size: 36, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Text("Go open one of them.\nWe'll be there.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
            Spacer()
            if let first = suggested.first, let url = URL(string: first.scheme) {
                primary("Open \(first.name)") {
                    finish()
                    openURL(url)
                }
                Button("Later") { finish() }.foregroundStyle(.gray)
            } else {
                primary("Okay") { finish() }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    // MARK: pieces

    private func openPicker() {
        Task { @MainActor in
            if await Shield.authorize() { picking = true } else { denied = true }
        }
    }

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
