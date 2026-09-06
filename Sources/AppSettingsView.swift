import SwiftUI

struct AppSettingsView: View {
    let appID: String

    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var newQuestion = ""
    @State private var newTier = Tier.normal

    var body: some View {
        if let current = store.app(appID) {
            let app = Binding<GatedApp>(
                get: { store.app(appID) ?? current },
                set: { store.update($0) }
            )
            Form {
                Section {
                    NavigationLink("Automation setup") { SetupView(app: current) }
                    Toggle("Enabled", isOn: app.enabled)
                }

                Section("Questions") {
                    Picker("Source", selection: app.source) {
                        Text("Starter pack").tag(QuestionSource.starterPack)
                        Text("My own").tag(QuestionSource.custom)
                    }
                    Picker("Show", selection: app.mode) {
                        Text("One fixed question").tag(QuestionMode.single)
                        Text("Rotate").tag(QuestionMode.rotate)
                    }
                    if current.mode == .single {
                        Picker("Question", selection: app.singleQuestionID) {
                            ForEach(pool(current)) { question in
                                Text(question.text).tag(Optional(question.id))
                            }
                        }
                    }
                }

                if current.source == .custom {
                    Section("My questions") {
                        ForEach(app.customQuestions) { $question in
                            HStack {
                                TextField("Question", text: $question.text)
                                Picker("", selection: $question.tier) {
                                    ForEach(Tier.allCases, id: \.self) { Text($0.label) }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                        }
                        .onDelete { offsets in
                            app.wrappedValue.customQuestions.remove(atOffsets: offsets)
                        }
                        TextField("New question", text: $newQuestion)
                        Picker("Tier", selection: $newTier) {
                            ForEach(Tier.allCases, id: \.self) { Text($0.label) }
                        }
                        Button("Add question") {
                            let text = newQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                            app.wrappedValue.customQuestions.append(Question(id: UUID().uuidString, text: text, tier: newTier))
                            newQuestion = ""
                        }
                        .disabled(newQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Friction") {
                    Stepper("Pause: \(current.pauseSeconds)s", value: app.pauseSeconds, in: 0...60)
                    Stepper("Cooldown: \(current.cooldownMinutes) min", value: app.cooldownMinutes, in: 1...240, step: 5)
                    Stepper("Annoyed from open #\(current.annoyedAt)", value: app.annoyedAt, in: 1...50)
                    Stepper("Brutal from open #\(current.brutalAt)", value: app.brutalAt, in: 1...50)
                    Stepper("Average session: \(current.sessionMinutes) min", value: app.sessionMinutes, in: 1...120)
                }

                Section {
                    Button("Remove \(current.name)", role: .destructive) {
                        store.remove(appID)
                        dismiss()
                    }
                }
            }
            .navigationTitle(current.name)
            .onChange(of: current.source) { _, _ in
                app.wrappedValue.singleQuestionID = nil
            }
        }
    }

    private func pool(_ app: GatedApp) -> [Question] {
        app.source == .starterPack ? Packs.questions(for: app.id) : app.customQuestions
    }
}
