import SwiftUI

struct LogView: View {
    @EnvironmentObject var store: Store
    @State private var appFilter: String?

    var body: some View {
        let events = store.events.filter { appFilter == nil || $0.appID == appFilter }
        let groups = Logic.groupedByDay(events: events)
        List {
            ForEach(groups) { group in
                Section(group.day.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach(group.events) { event in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(event.at.formatted(date: .omitted, time: .shortened))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(store.app(event.appID)?.name ?? event.appID) · \(event.decision == .no ? "Said no" : "Went through")")
                                if let reason = event.reason, !reason.isEmpty {
                                    Text(reason).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView("Nothing yet", systemImage: "clock", description: Text("Check-ins show up here."))
            }
        }
        .navigationTitle("Log")
        .toolbar {
            Menu {
                Button("All apps") { appFilter = nil }
                ForEach(store.apps) { app in
                    Button(app.name) { appFilter = app.id }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }
}
