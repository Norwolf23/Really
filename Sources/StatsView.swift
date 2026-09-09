import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let now = Date()
        let today = store.events.filter { Calendar.current.isDateInToday($0.at) }
        let days = Logic.dailyCounts(events: store.events, days: 7, now: now)
        let counts = Logic.appCounts(events: store.events)
        NavigationStack {
            List {
                Section("Today") {
                    row("Asked", today.count)
                    row("Said no", today.filter { $0.decision == .no }.count)
                    row("Went through", today.filter { $0.decision == .proceed }.count)
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
                if !counts.isEmpty {
                    Section {
                        ForEach(counts) { app in
                            VStack(alignment: .leading, spacing: 6) {
                                AppLabel(id: app.id)
                                HStack(spacing: 16) {
                                    counter("Tried to open", app.tried)
                                    counter("Actually opened", app.opened)
                                    counter("Stopped", app.stopped)
                                    Spacer()
                                    if let share = app.stoppedShare {
                                        Text(share, format: .percent.precision(.fractionLength(0)))
                                            .font(.title3.bold().monospacedDigit())
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Per app, all time")
                    } footer: {
                        Text("The percentage is how often the question ended with the app closed.")
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }

    private func counter(_ label: String, _ number: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(number)").font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
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
