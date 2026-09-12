import FamilyControls
import SwiftUI

struct AppsView: View {
    @EnvironmentObject var store: Store
    @State private var picking = false
    @State private var denied = false

    var body: some View {
        let tokens = Array(store.settings.selection.applicationTokens)
        NavigationStack {
            List {
                ForEach(tokens, id: \.self) { token in
                    NavigationLink { MessagesView(id: TokenID.string(token), token: token) } label: {
                        Label(token).labelStyle(.titleAndIcon)
                    }
                }
            }
            .overlay {
                if tokens.isEmpty {
                    ContentUnavailableView("No apps yet", systemImage: "app.badge", description: Text("Pick the apps you open more than you mean to."))
                }
            }
            .navigationTitle("Really?")
            .toolbar {
                Button(tokens.isEmpty ? "Pick apps" : "Change") {
                    Task { @MainActor in if await Shield.authorize() { picking = true } else { denied = true } }
                }
            }
            .familyActivityPicker(isPresented: $picking, selection: $store.settings.selection)
            .onChange(of: store.settings.selection) { _, selection in Shield.apply(selection) }
            .alert("Screen Time access needed", isPresented: $denied) {
                Button("OK") {}
            } message: {
                Text("Allow Really? under Settings → Screen Time → Apps with Screen Time Access.")
            }
        }
    }
}
