import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let now = Date()
        let today = store.events.filter { Calendar.current.isDateInToday($0.at) }
        let days = Logic.dailyCounts(events: store.events, days: 7, now: now)
        let perApp = Dictionary(grouping: today, by: \.appID)
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
                if let hour = Logic.worstHour(events: store.events) {
                    Section("Worst hour") {
                        Text("Most likely to cave: \(String(format: "%02d:00–%02d:00", hour, (hour + 1) % 24))")
                    }
                }
                Section("Log") {
                    NavigationLink("All check-ins") { LogView() }
                }
                if !perApp.isEmpty {
                    Section("Per app, today") {
                        ForEach(perApp.keys.sorted(), id: \.self) { id in
                            let mine = perApp[id] ?? []
                            HStack {
                                AppLabel(id: id)
                                Spacer()
                                Text("\(mine.filter { $0.decision == .no }.count) no · \(mine.filter { $0.decision == .proceed }.count) through")
                                    .foregroundStyle(.secondary)
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
