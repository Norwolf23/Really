import SwiftUI

struct AskView: View {
    let appID: String

    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @Environment(\.openURL) private var openURL

    @State private var question: Question?
    @State private var remaining = 0
    @State private var total = 1
    @State private var breathing = false
    @State private var saidNo = false
    @State private var goodCallLine = GoodCallView.lines.randomElement() ?? ""

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if saidNo {
                GoodCallView(appID: appID, line: goodCallLine) { router.askingAppID = nil }
            } else if let app = store.app(appID) {
                askBody(app)
            } else {
                VStack(spacing: 16) {
                    Text("That app isn't set up in Really?.").foregroundStyle(.white)
                    Button("Close") { router.askingAppID = nil }.buttonStyle(.bordered)
                }
            }
        }
        .onAppear(perform: start)
        .onReceive(ticker) { _ in
            if !saidNo && remaining > 0 { remaining -= 1 }
        }
    }

    private func start() {
        guard let app = store.app(appID) else { return }
        let openNumber = Logic.openNumberToday(events: store.events, appID: appID, now: .now)
        let tier = Logic.tier(openNumber: openNumber, annoyedAt: app.annoyedAt, brutalAt: app.brutalAt)
        var rng = SystemRandomNumberGenerator()
        question = Logic.pickQuestion(for: app, pack: Packs.questions(for: appID), tier: tier, using: &rng)
        total = max(app.pauseSeconds, 1)
        remaining = app.pauseSeconds
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            breathing = true
        }
    }

    private func askBody(_ app: GatedApp) -> some View {
        VStack(spacing: 36) {
            Spacer()
            Text("REALLY?")
                .font(.system(.caption, design: .serif))
                .tracking(5)
                .foregroundStyle(.gray)
            Text(question?.text ?? "Are you sure about this?")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .minimumScaleFactor(0.7)
            ring
            Spacer()
            VStack(spacing: 14) {
                Button {
                    proceed(app)
                } label: {
                    Text(remaining > 0 ? "Continue in \(remaining)" : "Continue to \(app.name)")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .disabled(remaining > 0)

                Button {
                    store.record(.no, for: appID, questionID: question?.id)
                    saidNo = true
                } label: {
                    Text("No")
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    private var ring: some View {
        let progress = 1 - Double(max(remaining - 1, 0)) / Double(total)
        return ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
        .frame(width: 120, height: 120)
        .scaleEffect(breathing ? 1.06 : 0.94)
    }

    private func proceed(_ app: GatedApp) {
        store.record(.proceed, for: appID, questionID: question?.id)
        if let url = URL(string: app.urlScheme) { openURL(url) }
        router.askingAppID = nil
    }
}

struct GoodCallView: View {
    let appID: String
    let line: String
    let done: () -> Void

    @EnvironmentObject var store: Store

    static let lines = [
        "Look at you, having a spine.",
        "The feed will survive without you.",
        "Nothing happened in there. It never does.",
        "That was the whole test. You passed.",
        "Your thumb is confused. Let it be.",
        "Somewhere, an engagement graph dipped.",
    ]

    var body: some View {
        let todayNos = store.events.filter { $0.decision == .no && Calendar.current.isDateInToday($0.at) }.count
        let streak = Logic.streak(events: store.events, now: .now)
        VStack(spacing: 24) {
            Spacer()
            Text("Good call.")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text(line)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
            HStack(spacing: 48) {
                stat("\(todayNos)", todayNos == 1 ? "no today" : "nos today")
                stat("\(streak)", "day streak")
            }
            Spacer()
            Button("Done", action: done)
                .buttonStyle(.bordered)
                .tint(.gray)
                .padding(.bottom, 24)
        }
    }

    private func stat(_ number: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }
}
