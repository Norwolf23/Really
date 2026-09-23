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
        XCTAssertFalse(old.fullBlockEnabled)
        XCTAssertNil(old.fullBlockOffAt)
        XCTAssertEqual(old.fullBlockDailyMinutes, 15)
        XCTAssertTrue(old.fullBlockGrants.isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: Data("{}".utf8)), Settings())
    }

    func testFullBlockRoundTripsOnSettings() throws {
        var s = Settings()
        let grant = FullBlockGrant(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            reason: "reply",
            at: Date(timeIntervalSince1970: 10),
            until: Date(timeIntervalSince1970: 20),
            minutes: 15)
        s.fullBlockEnabled = true
        s.fullBlockOffAt = Date(timeIntervalSince1970: 1_800_086_400)
        s.fullBlockDailyMinutes = 30
        s.fullBlockGrants["abc"] = [grant]
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        let back = try decoder.decode(Settings.self, from: encoder.encode(s))
        XCTAssertEqual(back.fullBlockEnabled, s.fullBlockEnabled)
        XCTAssertEqual(back.fullBlockDailyMinutes, s.fullBlockDailyMinutes)
        XCTAssertEqual(back.fullBlockOffAt?.timeIntervalSince1970 ?? 0, s.fullBlockOffAt?.timeIntervalSince1970 ?? 0, accuracy: 1)
        XCTAssertEqual(back.fullBlockGrants, s.fullBlockGrants)
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
        XCTAssertEqual(defaults.annoyedAt, 10)
        XCTAssertEqual(defaults.brutalAt, 15)
        XCTAssertTrue(defaults.gentleFirst)
        XCTAssertTrue(defaults.selection.applicationTokens.isEmpty)
        var s = defaults
        s.hasOnboarded = true; s.meanness = .brutal; s.escalates = false; s.cooldownMinutes = 30; s.gentleFirst = false
        let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }

    func testCustomPackSeedsFromBuiltInAndRoundTrips() throws {
        let pack = CustomPack(base: "instagram")
        XCTAssertEqual(pack.questions.map(\.id).first, "pack-instagram.normal.0")
        XCTAssertEqual(pack.questions.count, 9)
        let back = try JSONDecoder().decode(CustomPack.self, from: JSONEncoder().encode(pack))
        XCTAssertEqual(back, pack)
        XCTAssertEqual(CustomPack.bases, ["instagram", "tiktok", "snapchat", "youtube", "generic"])
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
