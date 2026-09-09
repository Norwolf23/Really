import XCTest
@testable import Really

final class ModelsTests: XCTestCase {
    func testDecisionEncodesAsContinueAndNo() throws {
        XCTAssertEqual(Decision.proceed.rawValue, "continue")
        XCTAssertEqual(Decision.no.rawValue, "no")
    }

    func testTierOrdering() {
        XCTAssertTrue(Tier.normal < Tier.annoyed)
        XCTAssertTrue(Tier.annoyed < Tier.brutal)
        XCTAssertEqual(Tier.annoyed.label, "Annoyed")
    }

    func testCatalogHasEightAppsWithPacks() {
        XCTAssertEqual(Catalog.entries.count, 8)
        for entry in Catalog.entries {
            XCTAssertNotNil(Bundle.main.url(forResource: "pack-" + entry.pack, withExtension: "json"), entry.bundleID)
            XCTAssertTrue(entry.scheme.hasSuffix("://"), entry.name)
        }
        XCTAssertEqual(Catalog.pack(for: "com.burbn.instagram"), "instagram")
        XCTAssertEqual(Catalog.entries.first?.name, "Instagram")
    }

    func testUnknownBundleIDFallsBackToGeneric() {
        XCTAssertEqual(Catalog.pack(for: "com.example.nope"), "generic")
    }

    func testSettingsDecodesWithMissingKeys() throws {
        let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"hasOnboarded":true,"meanness":"brutal"}"#.utf8))
        XCTAssertTrue(old.hasOnboarded)
        XCTAssertEqual(old.meanness, .brutal)
        XCTAssertEqual(old.cooldownMinutes, 15)
        XCTAssertTrue(old.selection.includeEntireCategory)
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: Data("{}".utf8)), Settings())
    }

    func testTokenIDRoundTripsGarbageToNil() {
        XCTAssertNil(TokenID.token("not base64!"))
        XCTAssertNil(TokenID.token(Data("{}".utf8).base64EncodedString()))
    }

    func testCheckInRoundTrips() throws {
        let event = CheckIn(appID: "com.burbn.instagram", at: Date(timeIntervalSince1970: 1_800_000_000), decision: .no)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        let back = try decoder.decode(CheckIn.self, from: encoder.encode(event))
        XCTAssertEqual(back, event)
    }

    func testSettingsDefaultsAndRoundTrip() throws {
        let defaults = Settings()
        XCTAssertFalse(defaults.hasOnboarded)
        XCTAssertEqual(defaults.meanness, .normal)
        XCTAssertTrue(defaults.escalates)
        XCTAssertEqual(defaults.cooldownMinutes, 15)
        XCTAssertEqual(defaults.annoyedAt, 3)
        XCTAssertEqual(defaults.brutalAt, 6)
        XCTAssertTrue(defaults.selection.applicationTokens.isEmpty)
        var s = defaults
        s.hasOnboarded = true; s.meanness = .brutal; s.escalates = false; s.cooldownMinutes = 30
        let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }

    func testShieldStateDefaultsAndRoundTrip() throws {
        XCTAssertEqual(ShieldState(), ShieldState(cooldowns: [:], lastAction: nil))
        var state = ShieldState()
        state.cooldowns["com.burbn.instagram"] = Date(timeIntervalSince1970: 1_800_000_000)
        state.lastAction = "Nope 9:41"
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        XCTAssertEqual(try decoder.decode(ShieldState.self, from: encoder.encode(state)), state)
    }
}
