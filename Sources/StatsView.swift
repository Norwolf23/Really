import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let counts = Logic.appCounts(events: store.events)
        let tried = counts.reduce(0) { $0 + $1.tried }
        let opened = counts.reduce(0) { $0 + $1.opened }
        let today = Logic.opensToday(events: store.events, now: .now)
        NavigationStack {
            List {
                Section {
                    if today.isEmpty {
                        Text("No opens yet today").foregroundStyle(.secondary)
                    }
                    ForEach(today) { app in
                        HStack {
                            AppLabel(id: app.id)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("\(app.tried)").font(.title2.bold().monospacedDigit())
                                Text("next: \(Logic.stage(openNumber: app.tried + 1, settings: store.settings, now: .now))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Opens today")
                } footer: {
                    Text("Times Really asked. Opens while the question was paused after a go-through aren't counted.")
                }
                Section {
                    Overview(tried: tried, opened: opened)
                } footer: {
                    Text("Every time the question showed, and how often it ended with the app closed.")
                }
                Section("Last 7 days") {
                    WeekChart(days: Logic.dailyCounts(events: store.events, days: 7, now: .now))
                }
                if !counts.isEmpty {
                    Section("Per app") {
                        ForEach(counts) {
                            AppRow(app: $0, perDay: Logic.averageOpensPerDay(events: store.events, appID: $0.id, days: 7, now: .now))
                        }
                    }
                }
                if tried > 0 {
                    Section {
                        HourChart(hours: Logic.hourCounts(events: store.events))
                    } header: {
                        Text("By hour of day")
                    } footer: {
                        if let hour = Logic.worstHour(events: store.events) {
                            Text("Most likely to cave: \(String(format: "%02d:00–%02d:00", hour, (hour + 1) % 24))")
                        }
                    }
                }
                Section("Log") {
                    NavigationLink("All check-ins") { LogView() }
                }
            }
            .navigationTitle("Stats")
        }
    }
}

private let outcomeColors: KeyValuePairs<String, Color> = ["Stopped": .white, "Opened": .gray]

private struct Overview: View {
    let tried: Int
    let opened: Int

    var body: some View {
        let stopped = tried - opened
        let share = tried == 0 ? 0 : Double(stopped) / Double(tried)
        HStack(spacing: 24) {
            Gauge(value: share) {
                Text("Stopped")
            } currentValueLabel: {
                Text(tried == 0 ? "–" : "\(Int((share * 100).rounded()))%")
                    .font(.title3.bold().monospacedDigit())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.white)
            .scaleEffect(1.4)
            .frame(width: 90, height: 90)
            VStack(alignment: .leading, spacing: 10) {
                Counter(label: "Tried to open", number: tried)
                Counter(label: "Actually opened", number: opened)
                Counter(label: "Stopped", number: stopped)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

private struct Counter: View {
    let label: String
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(number)").font(.title3.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct WeekChart: View {
    let days: [Logic.DayCount]

    var body: some View {
        Chart(days) { day in
            BarMark(x: .value("Day", day.day, unit: .day), y: .value("Count", day.nos))
                .foregroundStyle(by: .value("Outcome", "Stopped"))
            BarMark(x: .value("Day", day.day, unit: .day), y: .value("Count", day.proceeds))
                .foregroundStyle(by: .value("Outcome", "Opened"))
        }
        .chartForegroundStyleScale(outcomeColors)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
        .frame(height: 180)
        .padding(.vertical, 8)
    }
}

private struct AppRow: View {
    let app: Logic.AppCount
    let perDay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AppLabel(id: app.id)
                Spacer()
                if let share = app.stoppedShare {
                    Text(share, format: .percent.precision(.fractionLength(0)))
                        .font(.headline.monospacedDigit())
                }
            }
            Chart {
                BarMark(x: .value("Count", app.stopped))
                    .foregroundStyle(by: .value("Outcome", "Stopped"))
                BarMark(x: .value("Count", app.opened))
                    .foregroundStyle(by: .value("Outcome", "Opened"))
            }
            .chartForegroundStyleScale(outcomeColors)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 14)
            Text("\(app.tried) tried · \(app.opened) opened · \(app.stopped) stopped · \(perDay, format: .number.precision(.fractionLength(1)))/day this week")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct HourChart: View {
    let hours: [Logic.HourCount]

    var body: some View {
        Chart(hours) { h in
            BarMark(x: .value("Hour", h.hour), y: .value("Count", h.stopped))
                .foregroundStyle(by: .value("Outcome", "Stopped"))
            BarMark(x: .value("Hour", h.hour), y: .value("Count", h.opened))
                .foregroundStyle(by: .value("Outcome", "Opened"))
        }
        .chartForegroundStyleScale(outcomeColors)
        .chartXScale(domain: 0...24)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                AxisValueLabel {
                    if let h = value.as(Int.self) { Text(String(format: "%02d", h % 24)) }
                }
            }
        }
        .frame(height: 140)
        .padding(.vertical, 8)
    }
}
