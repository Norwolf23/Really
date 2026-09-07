import SwiftUI

struct LogView: View {
    @EnvironmentObject var store: Store
    @State private var appFilter: String?

    var body: some View {
        let names = Dictionary(store.events.map { ($0.appID, $0.appName) }, uniquingKeysWith: { _, latest in latest })
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
                            Text("\(event.appName) · \(event.decision == .no ? "Said no" : "Went through")")
                        }
                    }
                }
            }
        }
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView("Nothing yet", systemImage: "clock", description: Text("Shield answers show up here."))
            }
        }
        .navigationTitle("Log")
        .toolbar {
            Menu {
                Button("All apps") { appFilter = nil }
                ForEach(names.keys.sorted(), id: \.self) { id in
                    Button(names[id] ?? id) { appFilter = id }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }
}
