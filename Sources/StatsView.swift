import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let now = Date()
        let events = store.events
        let counts = Logic.appCounts(events: events)
        let tried = counts.reduce(0) { $0 + $1.tried }
        let opened = counts.reduce(0) { $0 + $1.opened }
        let stopped = tried - opened
        let days = Logic.dailyCounts(events: events, days: 7, now: now)
        let hours = Logic.hourCounts(events: events)
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 24) {
                        Gauge(value: tried == 0 ? 0 : Double(stopped) / Double(tried)) {
                            Text("Stopped")
                        } currentValueLabel: {
                            Text(tried == 0 ? "–" : "\(Int((Double(stopped) / Double(tried) * 100).rounded()))%")
                                .font(.title3.bold().monospacedDigit())
                        }
                        .gaugeStyle(.accessoryCircularCapacity)
                        .tint(.white)
                        .scaleEffect(1.4)
                        .frame(width: 90, height: 90)
                        VStack(alignment: .leading, spacing: 10) {
                            counter("Tried to open", tried)
                            counter("Actually opened", opened)
                            counter("Stopped", stopped)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("Every time the question showed, and how often it ended with the app closed.")
                }

                Section("Last 7 days") {
                    Chart {
                        ForEach(days) { day in
                            BarMark(x: .value("Day", day.day, unit: .day), y: .value("Count", day.nos))
                                .foregroundStyle(by: .value("Outcome", "Stopped"))
                            BarMark(x: .value("Day", day.day, unit: .day), y: .value("Count", day.proceeds))
                                .foregroundStyle(by: .value("Outcome", "Opened"))
                        }
                    }
                    .chartForegroundStyleScale(["Stopped": Color.white, "Opened": Color.gray])
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .frame(height: 180)
                    .padding(.vertical, 8)
                }

                if !counts.isEmpty {
                    Section("Per app") {
                        ForEach(counts) { app in
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
                                .chartForegroundStyleScale(["Stopped": Color.white, "Opened": Color.gray])
                                .chartXAxis(.hidden)
                                .chartYAxis(.hidden)
                                .chartLegend(.hidden)
                                .frame(height: 14)
                                Text("\(app.tried) tried · \(app.opened) opened · \(app.stopped) stopped")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if tried > 0 {
                    Section {
                        Chart {
                            ForEach(hours) { h in
                                BarMark(x: .value("Hour", h.hour), y: .value("Count", h.stopped))
                                    .foregroundStyle(by: .value("Outcome", "Stopped"))
                                BarMark(x: .value("Hour", h.hour), y: .value("Count", h.opened))
                                    .foregroundStyle(by: .value("Outcome", "Opened"))
                            }
                        }
                        .chartForegroundStyleScale(["Stopped": Color.white, "Opened": Color.gray])
                        .chartXScale(domain: 0...24)
                        .chartXAxis {
                            AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                                AxisValueLabel { if let h = value.as(Int.self) { Text(String(format: "%02d", h % 24)) } }
                            }
                        }
                        .frame(height: 140)
                        .padding(.vertical, 8)
                    } header: {
                        Text("By hour of day")
                    } footer: {
                        if let hour = Logic.worstHour(events: events) {
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

    private func counter(_ label: String, _ number: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(number)").font(.title3.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
