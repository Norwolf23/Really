import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let now = Date()
        let today = store.events.filter { Calendar.current.isDateInToday($0.at) }
        let days = Logic.dailyCounts(events: store.events, days: 7, now: now)
        NavigationStack {
            List {
                Section("Today") {
                    row("Asked", today.count)
                    row("Said no", today.filter { $0.decision == .no }.count)
                    row("Went through", today.filter { $0.decision == .proceed }.count)
                }
                Section("Streak") {
                    row("Days in a row with a no", Logic.streak(events: store.events, now: now))
                }
                Section("Time saved, roughly") {
                    row("Minutes", Logic.timeSavedMinutes(events: store.events, apps: store.apps))
                }
                Section("Last 7 days") {
                    Chart {
                        ForEach(days) { day in
                            BarMark(x: .value("Day", day.day, unit: .day), y: .value("Count", day.nos))
                                .foregroundStyle(by: .value("Decision", "No"))
                            BarMark(x: .value("Day", day.day, unit: .day), y: .value("Count", day.proceeds))
                                .foregroundStyle(by: .value("Decision", "Continue"))
                        }
                    }
                    .chartForegroundStyleScale(["No": Color.white, "Continue": Color.gray])
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .frame(height: 180)
                    .padding(.vertical, 8)
                }
                Section("Excuses, last 7 days") {
                    let counts = Logic.reasonCounts(events: store.events, since: now.addingTimeInterval(-7 * 86400))
                    if counts.isEmpty {
                        Text("None yet.").foregroundStyle(.secondary)
                    } else {
                        Text("Leading excuse: \(counts[0].reason)").font(.subheadline.bold())
                        ForEach(counts) { row($0.reason, $0.count) }
                    }
                }
                if let hour = Logic.worstHour(events: store.events) {
                    Section("Worst hour") {
                        Text("Most likely to cave: \(String(format: "%02d:00–%02d:00", hour, (hour + 1) % 24))")
                    }
                }
                Section("Log") {
                    NavigationLink("All check-ins") { LogView() }
                }
                Section("Per app") {
                    ForEach(store.apps) { app in
                        let mine = today.filter { $0.appID == app.id }
                        HStack {
                            Text(app.name)
                            Spacer()
                            Text("\(mine.filter { $0.decision == .no }.count) no · \(mine.filter { $0.decision == .proceed }.count) through")
                                .foregroundStyle(.secondary)
                            if Logic.isInCooldown(app, now: now) {
                                Image(systemName: "hourglass").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }

    private func row(_ label: String, _ number: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(number)").bold()
        }
    }
}
