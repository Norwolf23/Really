import SwiftUI

@main
struct ReallyApp: App {
    @StateObject private var store = Store.shared
    @StateObject private var pro = ProStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(pro)
                .preferredColorScheme(.dark)
                .task { await pro.start(store) }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    store.reload()
                    Task { await pro.refresh() }
                    Shield.reapplyIfIdle(store)
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var pro: ProStore
    @State private var showFullBlock = false

    var body: some View {
        TabView {
            AppsView()
                .tabItem { Label("Apps", systemImage: "app.badge") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .fullScreenCover(isPresented: onboarding) {
            OnboardingView()
        }
        .onOpenURL { url in
            guard url.scheme == "really", store.settings.hasOnboarded else { return }
            showFullBlock = true
        }
        .sheet(isPresented: Binding(get: { pro.offer != nil }, set: { if !$0 { pro.offer = nil } })) {
            PaywallView()
                .environmentObject(store)
                .environmentObject(pro)
        }
        .sheet(isPresented: $showFullBlock) {
            NavigationStack {
                FullBlockView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showFullBlock = false }
                        }
                    }
            }
            .environmentObject(store)
            .environmentObject(pro)
        }
    }

    private var onboarding: Binding<Bool> {
        Binding(
            get: { !store.settings.hasOnboarded },
            set: { if !$0 { store.settings.hasOnboarded = true } }
        )
    }
}
