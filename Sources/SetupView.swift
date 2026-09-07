import SwiftUI

struct SetupView: View {
    let app: GatedApp
    @Environment(\.openURL) private var openURL

    static func steps(appName: String) -> [String] {
        [
            "Tap Automation at the bottom, then the + button.",
            "Choose App. Pick \(appName), tick Is Opened, choose Run Immediately, and turn off Notify When Run. Tap Next.",
            "Tap New Blank Automation. Search for Really? and add Check In. Set its App to \(appName).",
            "Add an If action. Set the condition to: Result is ask.",
            "Inside the If, add Really?'s Ask action and set its App to \(appName). Leave Otherwise empty.",
            "Tap Done. Open \(appName) once. This screen turns green when it worked.",
        ]
    }

    var body: some View {
        List {
            Section {
                if let last = app.lastCheckIn {
                    Label("Last check-in \(last.formatted(.relative(presentation: .named)))", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                } else {
                    Label("The automation hasn't fired yet.", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                }
            }
            Section("In the Shortcuts app") {
                ForEach(Array(SetupView.steps(appName: app.name).enumerated()), id: \.offset) { index, text in
                    step(index + 1, text)
                }
            }
            Section {
                Button("Open Shortcuts") {
                    if let url = URL(string: "shortcuts://") { openURL(url) }
                }
            }
        }
        .navigationTitle("Set up \(app.name)")
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").bold().foregroundStyle(.secondary).frame(width: 18)
            Text(text)
        }
    }
}
