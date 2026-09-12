import FamilyControls
import ManagedSettings
import SwiftUI

/// One app's shield lines: pick the built-in pack once, then delete lines, add your own, or restore.
struct MessagesView: View {
    @EnvironmentObject var store: Store
    let id: String
    let token: ApplicationToken
    @State private var adding = false
    @State private var restoring = false

    var body: some View {
        Group {
            if let pack = store.custom[id] {
                editor(pack)
            } else {
                chooser
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { Label(token).labelStyle(.titleAndIcon).font(.headline) } }
    }

    private var chooser: some View {
        List {
            Section {
                ForEach(CustomPack.bases, id: \.self) { base in
                    Button(base.capitalized) { store.custom[id] = CustomPack(base: base) }
                }
            } header: {
                Text("Which lines does this app use?")
            } footer: {
                Text("Really? can't read an app's name, so pick the set it should start from. Instagram, TikTok, Snapchat and YouTube each have their own; anything else is Generic.")
            }
        }
    }

    private func editor(_ pack: CustomPack) -> some View {
        List {
            ForEach(Tier.allCases, id: \.self) { tier in
                let lines = pack.questions.filter { $0.tier == tier }
                if !lines.isEmpty {
                    Section(OnboardingView.name(for: tier)) {
                        ForEach(lines) { q in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(q.text)
                                Text("\(q.yes) · \(q.no)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            let gone = Set(offsets.map { lines[$0].id })
                            store.custom[id]?.questions.removeAll { gone.contains($0.id) }
                        }
                    }
                }
            }
            Section {
                Button("Create my own") { adding = true }
                Button("Restore defaults", role: .destructive) { restoring = true }
            } footer: {
                Text("Swipe a line to delete it. Started from the \(pack.base.capitalized) set.")
            }
        }
        .sheet(isPresented: $adding) { NewLineSheet { store.custom[id]?.questions.append($0) } }
        .alert("Are you sure you want to restore to defaults?", isPresented: $restoring) {
            Button("Restore", role: .destructive) { store.custom[id] = nil }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete any custom messages you have created.")
        }
    }
}

private struct NewLineSheet: View {
    let add: (Question) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var tier = Tier.normal
    @State private var yes = Question(id: "", text: "", tier: .normal).yes
    @State private var no = Question(id: "", text: "", tier: .normal).no

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("Are you avoiding something again?", text: $text, axis: .vertical)
                }
                Section("When") {
                    Picker("Tier", selection: $tier) {
                        ForEach(Tier.allCases, id: \.self) { Text(OnboardingView.name(for: $0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    TextField("Closes the app", text: $yes)
                    TextField("Lets you in", text: $no)
                } header: {
                    Text("Replies")
                } footer: {
                    Text("First reply closes the app, second lets you in.")
                }
            }
            .navigationTitle("Create my own")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var q = Question(id: "custom.\(UUID().uuidString)", text: text.trimmingCharacters(in: .whitespacesAndNewlines), tier: tier)
                        if !yes.trimmingCharacters(in: .whitespaces).isEmpty { q.yes = yes }
                        if !no.trimmingCharacters(in: .whitespaces).isEmpty { q.no = no }
                        add(q)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
