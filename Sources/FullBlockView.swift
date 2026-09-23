import FamilyControls
import ManagedSettings
import SwiftUI

/// Full block lives here, not on each app. Darker than the rest of Settings, on purpose.
struct FullBlockView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var pro: ProStore
    @State private var reason = ""
    @State private var picked: String? = nil

    private var active: Bool {
        Logic.fullBlockIsActive(enabled: store.settings.fullBlockEnabled, offAt: store.settings.fullBlockOffAt, now: .now)
    }

    /// They flipped it off, and today has not ended.
    private var holding: Bool { active && !store.settings.fullBlockEnabled }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                armPanel
                limitPanel
                appsPanel
                logPanel
            }
            .padding(20)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Full block")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACCESS CONTROL")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(Palette.dim)
            Text("FULL BLOCK")
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Text(statusLine)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(statusColor)
        }
    }

    private var statusLine: String {
        if holding, let off = store.settings.fullBlockOffAt {
            return "HOLD  ·  STILL BLOCKED UNTIL \(off.formatted(date: .omitted, time: .shortened))"
        }
        return active ? "ARMED  ·  APPS STAY CLOSED" : "STANDBY"
    }

    private var statusColor: Color {
        if holding { return Palette.hold }
        return active ? Palette.armed : Palette.dim
    }

    private var armPanel: some View {
        panel {
            Toggle(isOn: armed) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(active ? "Blocked" : "Open")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Turning this off waits until tomorrow. Today stays blocked.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }
            .tint(Palette.armed)
        }
    }

    private var armed: Binding<Bool> {
        Binding(
            get: { store.settings.fullBlockEnabled },
            set: { on in
                if on && !store.settings.isPro {
                    pro.offer = .fullBlock
                    return
                }
                if on {
                    store.settings.fullBlockEnabled = true
                    store.settings.fullBlockOffAt = nil
                } else if active {
                    store.settings.fullBlockEnabled = false
                    store.settings.fullBlockOffAt = Logic.fullBlockOffDate(now: .now)
                } else {
                    store.settings.fullBlockEnabled = false
                    store.settings.fullBlockOffAt = nil
                }
                Shield.apply(store)
            }
        )
    }

    private var limitPanel: some View {
        let minutes = store.settings.fullBlockDailyMinutes
        return panel {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAILY LIMIT")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(Palette.dim)
                    Text("\(minutes) min")
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
                stepButton("−") { nudge(-5) }
                stepButton("+") { nudge(5) }
            }
            Text("Each reason opens one app for 5 minutes, until this runs out.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Palette.dim)
        }
    }

    private var appsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APPS")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Palette.dim)
            if rows.isEmpty {
                panel {
                    Text("No apps yet. Pick them in Screen Time.")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            } else {
                ForEach(rows, id: \.id) { row in
                    appRow(row)
                }
            }
        }
    }

    private var rows: [AppRow] {
        store.settings.selection.applicationTokens
            .sorted { TokenID.string($0) < TokenID.string($1) }
            .map { AppRow(id: TokenID.string($0), token: $0) }
    }

    private func appRow(_ row: AppRow) -> some View {
        let grants = store.settings.fullBlockGrants[row.id] ?? []
        let left = Logic.fullBlockRemaining(dailyMinutes: store.settings.fullBlockDailyMinutes, grants: grants, now: .now)
        let open = grants.last { $0.until > .now }
        let chosen = picked == row.id
        return panel {
            Button {
                picked = chosen ? nil : row.id
                reason = ""
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let token = row.token {
                            Label(token).labelStyle(.titleAndIcon).foregroundStyle(.white)
                        } else {
                            Text("Test")
                                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        Text(row.token == nil ? "SIM  ·  \(left) MIN LEFT" : "\(left) MIN LEFT")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(Palette.dim)
                    }
                    Spacer()
                    Text(chosen ? "−" : "+")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }
            .buttonStyle(.plain)
            if let open {
                Text("OPEN UNTIL \(open.until.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.armed)
            }
            if chosen && active && open == nil && Logic.fullBlockGrantMinutes(active: active, dailyMinutes: store.settings.fullBlockDailyMinutes, grants: grants, now: .now) != nil {
                TextField("Why do you want in?", text: $reason, axis: .vertical)
                    .font(.system(size: 15, design: .monospaced))
                    .padding(10)
                    .background(Palette.bg, in: RoundedRectangle(cornerRadius: 8))
                Button("Let me in for 5 minutes") {
                    if Shield.letIn(store: store, id: row.id, reason: reason) { reason = "" }
                }
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else if chosen && active && open == nil {
                Text("NO TIME LEFT TODAY")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.hold)
            }
        }
    }

    private var logLines: [LogLine] {
        store.settings.fullBlockGrants.flatMap { id, grants in
            grants.map { LogLine(id: $0.id, at: $0.at, reason: $0.reason, appID: id) }
        }
        .sorted { $0.at > $1.at }
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LOG")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Palette.dim)
            panel {
                if logLines.isEmpty {
                    Text("No reasons yet.")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                } else {
                    ForEach(logLines) { line in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                if let token = TokenID.token(line.appID) {
                                    Label(token).labelStyle(.titleAndIcon).foregroundStyle(.white)
                                }
                                Spacer()
                                Text(line.at.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Palette.dim)
                            }
                            Text(line.reason)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
            }
        }
    }

    private func nudge(_ delta: Int) {
        let next = min(120, max(5, store.settings.fullBlockDailyMinutes + delta))
        store.settings.fullBlockDailyMinutes = next
    }

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 18, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line, lineWidth: 1))
    }

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
    }

    private struct AppRow: Identifiable {
        let id: String
        let token: ApplicationToken?
    }

    private struct LogLine: Identifiable {
        let id: UUID
        let at: Date
        let reason: String
        let appID: String
    }

    private enum Palette {
        static let bg = Color(red: 0.03, green: 0.035, blue: 0.04)
        static let panel = Color(red: 0.07, green: 0.075, blue: 0.082)
        static let line = Color.white.opacity(0.12)
        static let dim = Color.white.opacity(0.45)
        static let armed = Color(red: 0.45, green: 0.92, blue: 0.62)
        static let hold = Color(red: 0.95, green: 0.72, blue: 0.38)
    }
}
