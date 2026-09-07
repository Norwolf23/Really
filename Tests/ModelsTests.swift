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
        for (bundleID, entry) in Catalog.entries {
            XCTAssertNotNil(Bundle.main.url(forResource: "pack-" + entry.pack, withExtension: "json"), bundleID)
            XCTAssertGreaterThan(entry.sessionMinutes, 0, bundleID)
        }
        XCTAssertEqual(Catalog.pack(for: "com.burbn.instagram"), "instagram")
        XCTAssertEqual(Catalog.sessionMinutes(for: "com.burbn.instagram"), 12)
    }

    func testUnknownBundleIDFallsBackToGeneric() {
        XCTAssertEqual(Catalog.pack(for: "com.example.nope"), "generic")
        XCTAssertEqual(Catalog.sessionMinutes(for: "com.example.nope"), 10)
    }

    func testCheckInRoundTrips() throws {
        let event = CheckIn(appID: "com.burbn.instagram", appName: "Instagram", at: Date(timeIntervalSince1970: 1_800_000_000), decision: .no)
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
        XCTAssertEqual(ShieldState(), ShieldState(cooldowns: [:], lastQuestion: [:], lastShown: nil))
        var state = ShieldState()
        state.cooldowns["com.burbn.instagram"] = Date(timeIntervalSince1970: 1_800_000_000)
        state.lastQuestion["com.burbn.instagram"] = "pack-instagram.normal.0"
        state.lastShown = Shown(id: "com.burbn.instagram", name: "Instagram", at: Date(timeIntervalSince1970: 1_800_000_000))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        XCTAssertEqual(try decoder.decode(ShieldState.self, from: encoder.encode(state)), state)
    }
}
