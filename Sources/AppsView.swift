import FamilyControls
import SwiftUI

struct AppsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var pro: ProStore
    @State private var picking = false
    @State private var denied = false
    @State private var trimming = false

    var body: some View {
        let tokens = Array(store.settings.selection.applicationTokens)
        let blocked = Logic.fullBlockIsActive(enabled: store.settings.fullBlockEnabled, offAt: store.settings.fullBlockOffAt, now: .now)
        NavigationStack {
            List {
                ForEach(tokens, id: \.self) { token in
                    let id = TokenID.string(token)
                    NavigationLink { MessagesView(id: id, token: token) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(token).labelStyle(.titleAndIcon)
                            if blocked {
                                Text("Full block").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .overlay {
                if tokens.isEmpty {
                    ContentUnavailableView("No apps yet", systemImage: "app.badge", description: Text("Pick the apps you open more than you mean to."))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !store.settings.isPro && tokens.count > Logic.freeAppLimit {
                    Text("One app is free. Pro covers the rest.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Really?")
            .toolbar {
                Button(tokens.isEmpty ? "Pick apps" : "Change") {
                    Task { @MainActor in if await Shield.authorize() { picking = true } else { denied = true } }
                }
            }
            .familyActivityPicker(isPresented: $picking, selection: $store.settings.selection)
            .onChange(of: store.settings.selection) { old, selection in
                guard !trimming else { return }
                let active = Logic.fullBlockIsActive(enabled: store.settings.fullBlockEnabled, offAt: store.settings.fullBlockOffAt, now: .now)
                if !store.settings.isPro && !active && selection.applicationTokens.count > Logic.freeAppLimit {
                    trimming = true
                    var trimmed = selection
                    if !old.applicationTokens.isEmpty && old.applicationTokens.count <= Logic.freeAppLimit {
                        trimmed.applicationTokens = old.applicationTokens
                    } else {
                        let kept = Logic.keptAppIDs(selection.applicationTokens.map(TokenID.string), pro: false, fullBlockActive: false)
                        trimmed.applicationTokens = selection.applicationTokens.filter { kept.contains(TokenID.string($0)) }
                    }
                    store.settings.selection = trimmed
                    trimming = false
                    pro.offer = .secondApp
                }
                Shield.apply(store)
            }
            .alert("Screen Time access needed", isPresented: $denied) {
                Button("OK") {}
            } message: {
                Text("Allow Really? under Settings → Screen Time → Apps with Screen Time Access.")
            }
        }
    }
}
