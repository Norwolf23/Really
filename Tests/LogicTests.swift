import XCTest
@testable import Really

final class LogicTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSince1970: 1_800_000_000) // fixed instant

    func app(_ id: String = "instagram") -> GatedApp {
        GatedApp(id: id, name: id, urlScheme: "\(id)://", sessionMinutes: 10)
    }

    func event(_ appID: String, minutesAgo: Double, _ decision: Decision = .no) -> CheckIn {
        CheckIn(appID: appID, at: now.addingTimeInterval(-minutesAgo * 60), decision: decision)
    }

    // MARK: cooldown

    func testNoCooldownWhenUnset() {
        XCTAssertFalse(Logic.isInCooldown(app(), now: now))
    }

    func testInCooldownBeforeExpiry() {
        var a = app(); a.cooldownUntil = now.addingTimeInterval(60)
        XCTAssertTrue(Logic.isInCooldown(a, now: now))
    }

    func testCooldownOverAtExactExpiry() {
        var a = app(); a.cooldownUntil = now
        XCTAssertFalse(Logic.isInCooldown(a, now: now))
    }

    func testShouldAskFalseForNilDisabledOrCooldown() {
        XCTAssertFalse(Logic.shouldAsk(nil, now: now))
        var disabled = app(); disabled.enabled = false
        XCTAssertFalse(Logic.shouldAsk(disabled, now: now))
        var cooling = app(); cooling.cooldownUntil = now.addingTimeInterval(1)
        XCTAssertFalse(Logic.shouldAsk(cooling, now: now))
        XCTAssertTrue(Logic.shouldAsk(app(), now: now))
    }

    // MARK: open number

    func testOpenNumberIsOneWithNoEvents() {
        XCTAssertEqual(Logic.openNumberToday(events: [], appID: "instagram", now: now, calendar: cal), 1)
    }

    func testOpenNumberCountsOnlyThisAppToday() {
        let events = [
            event("instagram", minutesAgo: 5),
            event("instagram", minutesAgo: 10, .proceed),
            event("tiktok", minutesAgo: 5),
            event("instagram", minutesAgo: 48 * 60),
        ]
        XCTAssertEqual(Logic.openNumberToday(events: events, appID: "instagram", now: now, calendar: cal), 3)
    }

    // MARK: tier

    func testTierThresholds() {
        XCTAssertEqual(Logic.tier(openNumber: 1, annoyedAt: 3, brutalAt: 6), .normal)
        XCTAssertEqual(Logic.tier(openNumber: 2, annoyedAt: 3, brutalAt: 6), .normal)
        XCTAssertEqual(Logic.tier(openNumber: 3, annoyedAt: 3, brutalAt: 6), .annoyed)
        XCTAssertEqual(Logic.tier(openNumber: 5, annoyedAt: 3, brutalAt: 6), .annoyed)
        XCTAssertEqual(Logic.tier(openNumber: 6, annoyedAt: 3, brutalAt: 6), .brutal)
        XCTAssertEqual(Logic.tier(openNumber: 40, annoyedAt: 3, brutalAt: 6), .brutal)
    }

    func testTierBrutalWinsWhenThresholdsOverlap() {
        XCTAssertEqual(Logic.tier(openNumber: 2, annoyedAt: 5, brutalAt: 2), .brutal)
    }
}
