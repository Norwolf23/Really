import SwiftUI

struct SetupView: View {
    let app: GatedApp
    @Environment(\.openURL) private var openURL

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
                step(1, "Tap Automation at the bottom, then the + button.")
                step(2, "Choose App. Pick \(app.name), tick Is Opened, choose Run Immediately, and turn off Notify When Run. Tap Next.")
                step(3, "Tap New Blank Automation. Search for Really? and add Check In. Set its App to \(app.name).")
                step(4, "Add an If action. Set the condition to: Result is ask.")
                step(5, "Inside the If, add Really?'s Ask action and set its App to \(app.name). Leave Otherwise empty.")
                step(6, "Tap Done. Open \(app.name) once. This screen turns green when it worked.")
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
