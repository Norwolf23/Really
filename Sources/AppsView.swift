import SwiftUI

struct AppsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.apps) { app in
                    NavigationLink(value: app.id) { row(app) }
                }
                .onDelete { store.apps.remove(atOffsets: $0) }
            }
            .overlay {
                if store.apps.isEmpty {
                    ContentUnavailableView("No apps yet", systemImage: "app.badge", description: Text("Add an app you open more than you mean to."))
                }
            }
            .navigationTitle("Really?")
            .navigationDestination(for: String.self) { AppSettingsView(appID: $0) }
            .toolbar {
                Button { adding = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $adding) { AddAppView() }
        }
    }

    private func row(_ app: GatedApp) -> some View {
        let today = store.events.filter { $0.appID == app.id && Calendar.current.isDateInToday($0.at) }
        let nos = today.filter { $0.decision == .no }.count
        let throughs = today.filter { $0.decision == .proceed }.count
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.headline)
                if app.lastCheckIn == nil {
                    Label("Needs setup", systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.orange)
                } else {
                    Text("\(nos) no · \(throughs) through today")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Try") { router.askingAppID = app.id }
                .buttonStyle(.borderless)
                .font(.caption.bold())
        }
        .opacity(app.enabled ? 1 : 0.4)
    }
}

struct AddAppView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var customName = ""
    @State private var customScheme = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Popular") {
                    ForEach(Catalog.entries.filter { entry in !store.apps.contains { $0.id == entry.id } }) { entry in
                        Button(entry.name) {
                            store.update(Catalog.gatedApp(entry))
                            dismiss()
                        }
                    }
                }
                Section("Custom") {
                    TextField("Name", text: $customName)
                    TextField("URL scheme, e.g. myapp://", text: $customScheme)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Add") {
                        store.update(Catalog.custom(name: customName.trimmingCharacters(in: .whitespaces), urlScheme: customScheme.trimmingCharacters(in: .whitespaces)))
                        dismiss()
                    }
                    .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty || !customScheme.contains("://"))
                }
            }
            .navigationTitle("Add app")
            .toolbar { Button("Cancel") { dismiss() } }
        }
    }
}
