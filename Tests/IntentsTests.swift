import XCTest
@testable import Really

@MainActor
final class IntentsTests: XCTestCase {
    override func setUp() {
        Store.shared = Store(directory: FileManager.default.temporaryDirectory.appendingPathComponent("really-intents-\(UUID().uuidString)"))
        Router.shared.askingAppID = nil
    }

    func testCheckInReturnsAskAndMarksCheckIn() async throws {
        Store.shared.update(Catalog.gatedApp(Catalog.entries[0]))
        var intent = CheckInIntent()
        intent.app = GatedAppEntity(id: "instagram", name: "Instagram")
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "ask")
        XCTAssertNotNil(Store.shared.app("instagram")?.lastCheckIn)
    }

    func testCheckInReturnsSkipInsideCooldown() async throws {
        var app = Catalog.gatedApp(Catalog.entries[0])
        app.cooldownUntil = Date().addingTimeInterval(600)
        Store.shared.update(app)
        var intent = CheckInIntent()
        intent.app = GatedAppEntity(id: "instagram", name: "Instagram")
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "skip")
    }

    func testCheckInReturnsSkipForUnknownOrDisabledApp() async throws {
        var intent = CheckInIntent()
        intent.app = GatedAppEntity(id: "ghost", name: "Ghost")
        let unknown = try await intent.perform()
        XCTAssertEqual(unknown.value, "skip")

        var app = Catalog.gatedApp(Catalog.entries[0]); app.enabled = false
        Store.shared.update(app)
        intent.app = GatedAppEntity(id: "instagram", name: "Instagram")
        let disabled = try await intent.perform()
        XCTAssertEqual(disabled.value, "skip")
    }

    func testAskSetsRouter() async throws {
        var intent = AskIntent()
        intent.app = GatedAppEntity(id: "instagram", name: "Instagram")
        _ = try await intent.perform()
        XCTAssertEqual(Router.shared.askingAppID, "instagram")
    }

    func testQueryListsStoredApps() async throws {
        Store.shared.update(Catalog.gatedApp(Catalog.entries[0]))
        Store.shared.update(Catalog.gatedApp(Catalog.entries[1]))
        let all = try await GatedAppQuery().suggestedEntities()
        XCTAssertEqual(all.map(\.id), ["instagram", "tiktok"])
        let some = try await GatedAppQuery().entities(for: ["tiktok"])
        XCTAssertEqual(some.map(\.name), ["TikTok"])
    }
}
