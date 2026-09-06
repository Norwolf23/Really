import XCTest
@testable import Really

final class ModelsTests: XCTestCase {
    func testGatedAppDefaults() {
        let app = GatedApp(id: "instagram", name: "Instagram", urlScheme: "instagram://", sessionMinutes: 12)
        XCTAssertTrue(app.enabled)
        XCTAssertEqual(app.source, .starterPack)
        XCTAssertEqual(app.mode, .rotate)
        XCTAssertEqual(app.pauseSeconds, 5)
        XCTAssertEqual(app.cooldownMinutes, 15)
        XCTAssertEqual(app.annoyedAt, 3)
        XCTAssertEqual(app.brutalAt, 6)
        XCTAssertNil(app.cooldownUntil)
        XCTAssertNil(app.lastCheckIn)
        XCTAssertTrue(app.customQuestions.isEmpty)
    }

    func testGatedAppRoundTripsThroughJSON() throws {
        var app = GatedApp(id: "x", name: "X", urlScheme: "twitter://", sessionMinutes: 10)
        app.customQuestions = [Question(id: "q1", text: "Why?", tier: .brutal)]
        app.cooldownUntil = Date(timeIntervalSince1970: 1_000_000)
        let data = try JSONEncoder().encode(app)
        let back = try JSONDecoder().decode(GatedApp.self, from: data)
        XCTAssertEqual(back, app)
    }

    func testDecisionEncodesAsContinueAndNo() throws {
        XCTAssertEqual(Decision.proceed.rawValue, "continue")
        XCTAssertEqual(Decision.no.rawValue, "no")
    }

    func testTierOrdering() {
        XCTAssertTrue(Tier.normal < Tier.annoyed)
        XCTAssertTrue(Tier.annoyed < Tier.brutal)
        XCTAssertEqual(Tier.annoyed.label, "Annoyed")
    }

    func testCatalogHasEightAppsWithSchemes() {
        XCTAssertEqual(Catalog.entries.count, 8)
        XCTAssertEqual(Set(Catalog.entries.map(\.id)).count, 8)
        for entry in Catalog.entries {
            XCTAssertTrue(entry.urlScheme.hasSuffix("://"), entry.id)
            XCTAssertGreaterThan(entry.sessionMinutes, 0, entry.id)
        }
        XCTAssertEqual(Catalog.entries.first?.id, "instagram")
    }

    func testCatalogBuildsGatedApp() {
        let app = Catalog.gatedApp(Catalog.entries[0])
        XCTAssertEqual(app.id, "instagram")
        XCTAssertEqual(app.urlScheme, "instagram://")
        XCTAssertEqual(app.sessionMinutes, 12)
    }

    func testCustomAppGetsUniquePrefixedID() {
        let a = Catalog.custom(name: "Foo", urlScheme: "foo://")
        let b = Catalog.custom(name: "Foo", urlScheme: "foo://")
        XCTAssertTrue(a.id.hasPrefix("custom-"))
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(a.sessionMinutes, 10)
    }

    func testCheckInDecodesWithoutReasonKey() throws {
        let json = #"{"id":"6B29FC40-CA47-1067-B31D-00DD010662DA","appID":"instagram","at":1800000000,"decision":"no"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let event = try decoder.decode(CheckIn.self, from: Data(json.utf8))
        XCTAssertNil(event.reason)
        XCTAssertEqual(event.decision, .no)
    }

    func testSettingsDefaultsAndRoundTrip() throws {
        let defaults = Settings()
        XCTAssertFalse(defaults.hasOnboarded)
        XCTAssertEqual(defaults.meanness, .normal)
        XCTAssertTrue(defaults.escalates)
        var s = defaults
        s.hasOnboarded = true; s.meanness = .brutal; s.escalates = false
        let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }
}
