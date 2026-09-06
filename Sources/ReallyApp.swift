import SwiftUI

@main
struct ReallyApp: App {
    @StateObject private var store = Store.shared
    @StateObject private var router = Router.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(router)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var router: Router

    var body: some View {
        TabView {
            AppsView()
                .tabItem { Label("Apps", systemImage: "app.badge") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
        }
        .fullScreenCover(item: asking) { target in
            AskView(appID: target.id)
        }
    }

    private var asking: Binding<AskTarget?> {
        Binding(
            get: { router.askingAppID.map { AskTarget(id: $0) } },
            set: { router.askingAppID = $0?.id }
        )
    }
}

struct AskTarget: Identifiable {
    let id: String
}

// Placeholder until Task 12. Delete when its real view lands.
struct StatsView: View {
    var body: some View { Text("Stats") }
}

@MainActor
final class Router: ObservableObject {
    static let shared = Router()
    @Published var askingAppID: String?
}
