import SwiftUI

@main
struct ReallyApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Really?")
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class Router: ObservableObject {
    static let shared = Router()
    @Published var askingAppID: String?
}
