import AppIntents
import Foundation

struct GatedAppEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Gated App"
    static let defaultQuery = GatedAppQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct GatedAppQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [GatedAppEntity] {
        Store.shared.apps
            .filter { identifiers.contains($0.id) }
            .map { GatedAppEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [GatedAppEntity] {
        Store.shared.apps.map { GatedAppEntity(id: $0.id, name: $0.name) }
    }
}

/// Runs silently from the Shortcuts automation. Returns "ask" or "skip".
struct CheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "Check In"
    static let description = IntentDescription("Returns 'ask' when Really? should question this app right now, or 'skip' when you are inside its cooldown.")
    static let openAppWhenRun = false

    @Parameter(title: "App") var app: GatedAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Check in for \(\.$app)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = Store.shared
        store.markCheckIn(app.id)
        return .result(value: Logic.shouldAsk(store.app(app.id), now: .now) ? "ask" : "skip")
    }
}

/// Opens Really? on the question screen for the given app.
struct AskIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask"
    static let description = IntentDescription("Opens Really? with a question about this app.")
    static let openAppWhenRun = true

    @Parameter(title: "App") var app: GatedAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Ask about \(\.$app)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        Router.shared.askingAppID = app.id
        return .result()
    }
}
