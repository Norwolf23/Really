import XCTest
@testable import Really

final class LogicTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSince1970: 1_800_000_000) // fixed instant
    let ig = "com.burbn.instagram"
    let tt = "com.zhiliaoapp.musically"

    func event(_ appID: String, minutesAgo: Double, _ decision: Decision = .no) -> CheckIn {
        CheckIn(appID: appID, at: now.addingTimeInterval(-minutesAgo * 60), decision: decision)
    }

    // MARK: open number

    func testOpenNumberIsOneWithNoEvents() {
        XCTAssertEqual(Logic.openNumberToday(events: [], appID: ig, now: now, calendar: cal), 1)
    }

    func testOpenNumberCountsOnlyThisAppToday() {
        let events = [
            event(ig, minutesAgo: 5),
            event(ig, minutesAgo: 10, .proceed),
            event(tt, minutesAgo: 5),
            event(ig, minutesAgo: 48 * 60),
        ]
        XCTAssertEqual(Logic.openNumberToday(events: events, appID: ig, now: now, calendar: cal), 3)
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

    func testEffectiveTierIgnoresOpensWhenEscalationOff() {
        XCTAssertEqual(Logic.effectiveTier(base: .normal, openNumber: 40, annoyedAt: 3, brutalAt: 6, escalates: false), .normal)
        XCTAssertEqual(Logic.effectiveTier(base: .brutal, openNumber: 1, annoyedAt: 3, brutalAt: 6, escalates: false), .brutal)
    }

    func testEffectiveTierTakesHigherOfBaseAndEscalation() {
        XCTAssertEqual(Logic.effectiveTier(base: .normal, openNumber: 3, annoyedAt: 3, brutalAt: 6, escalates: true), .annoyed)
        XCTAssertEqual(Logic.effectiveTier(base: .annoyed, openNumber: 1, annoyedAt: 3, brutalAt: 6, escalates: true), .annoyed)
        XCTAssertEqual(Logic.effectiveTier(base: .brutal, openNumber: 1, annoyedAt: 3, brutalAt: 6, escalates: true), .brutal)
        XCTAssertEqual(Logic.effectiveTier(base: .normal, openNumber: 6, annoyedAt: 3, brutalAt: 6, escalates: true), .brutal)
    }

    // MARK: question selection

    let pack: [Question] = [
        Question(id: "n0", text: "n0", tier: .normal),
        Question(id: "n1", text: "n1", tier: .normal),
        Question(id: "a0", text: "a0", tier: .annoyed),
        Question(id: "b0", text: "b0", tier: .brutal),
    ]

    func testPickReturnsNilForEmptyPool() {
        var rng = SystemRandomNumberGenerator()
        XCTAssertNil(Logic.pickQuestion(pack: [], tier: .normal, using: &rng))
    }

    func testPickIsRandomWithinTier() {
        var rng = SystemRandomNumberGenerator()
        var seen: Set<String> = []
        for _ in 0..<60 {
            let q = Logic.pickQuestion(pack: pack, tier: .normal, using: &rng)
            XCTAssertEqual(q?.tier, .normal)
            seen.insert(q?.id ?? "")
        }
        XCTAssertEqual(seen, ["n0", "n1"])
    }

    func testPickFallsBackToLowerTierThenAnything() {
        var rng = SystemRandomNumberGenerator()
        let onlyNormal = pack.filter { $0.tier == .normal }
        XCTAssertEqual(Logic.pickQuestion(pack: onlyNormal, tier: .brutal, using: &rng)?.tier, .normal)
        let onlyBrutal = pack.filter { $0.tier == .brutal }
        XCTAssertEqual(Logic.pickQuestion(pack: onlyBrutal, tier: .normal, using: &rng)?.id, "b0")
    }

    func testHourCounts() {
        let counts = Logic.hourCounts(events: [at(hour: 9), at(hour: 9, .no), at(hour: 23)], calendar: cal)
        XCTAssertEqual(counts.count, 24)
        XCTAssertEqual(counts[9].opened, 1)
        XCTAssertEqual(counts[9].stopped, 1)
        XCTAssertEqual(counts[23].opened, 1)
        XCTAssertEqual(counts[0].opened + counts[0].stopped, 0)
    }

    // MARK: shield rounds

    func testShieldStep() {
        XCTAssertEqual(Logic.shieldStep(primary: true), .close)     // Yea, I am
        XCTAssertEqual(Logic.shieldStep(primary: false), .through)  // Nope, I've got a reason to be here
    }

    // MARK: cooldowns

    func testAnyCooldownActive() {
        XCTAssertFalse(Logic.anyCooldownActive([:], now: now))
        XCTAssertFalse(Logic.anyCooldownActive([ig: now], now: now))
        XCTAssertFalse(Logic.anyCooldownActive([ig: now.addingTimeInterval(-1)], now: now))
        XCTAssertTrue(Logic.anyCooldownActive([ig: now.addingTimeInterval(-1), tt: now.addingTimeInterval(1)], now: now))
    }

    func testSplitCooldowns() {
        let cooldowns = [ig: now.addingTimeInterval(-1), tt: now.addingTimeInterval(1), "x": now]
        let split = Logic.splitCooldowns(cooldowns, now: now)
        XCTAssertEqual(split.expired, [ig, "x"])
        XCTAssertEqual(split.active, [tt: now.addingTimeInterval(1)])
        XCTAssertEqual(Logic.splitCooldowns([:], now: now).expired, [])
    }

    func testScheduleMinutesClampsToFloorPlusOne() {
        XCTAssertEqual(Logic.scheduleMinutes(setting: 5), 16)
        XCTAssertEqual(Logic.scheduleMinutes(setting: 15), 16)
        XCTAssertEqual(Logic.scheduleMinutes(setting: 60), 61)
    }

    // MARK: per-app counts

    func daysAgo(_ d: Int, _ decision: Decision = .no) -> CheckIn {
        CheckIn(appID: ig, at: cal.date(byAdding: .day, value: -d, to: now)!, decision: decision)
    }

    func testAppCountsTriedOpenedStopped() {
        let events = [event(ig, minutesAgo: 1), event(ig, minutesAgo: 2, .proceed), event(ig, minutesAgo: 3, .proceed), event(tt, minutesAgo: 4)]
        let counts = Logic.appCounts(events: events)
        XCTAssertEqual(counts.map(\.id), [ig, tt])
        XCTAssertEqual(counts[0].tried, 3)
        XCTAssertEqual(counts[0].opened, 2)
        XCTAssertEqual(counts[0].stopped, 1)
        XCTAssertEqual(counts[0].stoppedShare ?? 0, 1.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(counts[1].stoppedShare, 1)
        XCTAssertTrue(Logic.appCounts(events: []).isEmpty)
    }

    // MARK: daily counts

    func testDailyCountsCoverRequestedDaysOldestFirst() {
        let events = [daysAgo(0), daysAgo(0, .proceed), daysAgo(1), daysAgo(6), daysAgo(7)]
        let days = Logic.dailyCounts(events: events, days: 7, now: now, calendar: cal)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.last?.day, cal.startOfDay(for: now))
        XCTAssertEqual(days.last?.nos, 1)
        XCTAssertEqual(days.last?.proceeds, 1)
        XCTAssertEqual(days[5].nos, 1)
        XCTAssertEqual(days[0].nos, 1)
        XCTAssertEqual(days[0].proceeds, 0)
    }

    // MARK: worst hour

    func at(hour: Int, _ decision: Decision = .proceed) -> CheckIn {
        CheckIn(appID: ig, at: cal.date(bySettingHour: hour, minute: 0, second: 0, of: now)!, decision: decision)
    }

    func testWorstHourNilWhenNoProceeds() {
        XCTAssertNil(Logic.worstHour(events: [], calendar: cal))
        XCTAssertNil(Logic.worstHour(events: [at(hour: 9, .no)], calendar: cal))
    }

    func testWorstHourPicksMostProceedsIgnoringNos() {
        let events = [at(hour: 23), at(hour: 23), at(hour: 9), at(hour: 9, .no), at(hour: 9, .no), at(hour: 9, .no)]
        XCTAssertEqual(Logic.worstHour(events: events, calendar: cal), 23)
    }

    func testWorstHourTieGoesToEarlierHour() {
        XCTAssertEqual(Logic.worstHour(events: [at(hour: 23), at(hour: 9)], calendar: cal), 9)
    }

    // MARK: grouping

    func testGroupedByDayNewestFirst() {
        let today10 = at(hour: 10), today11 = at(hour: 11)
        let yesterday = CheckIn(appID: ig, at: cal.date(byAdding: .day, value: -1, to: at(hour: 9).at)!, decision: .no)
        let groups = Logic.groupedByDay(events: [yesterday, today10, today11], calendar: cal)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].day, cal.startOfDay(for: now))
        XCTAssertEqual(groups[0].events.map(\.id), [today11.id, today10.id])
        XCTAssertEqual(groups[1].events.map(\.id), [yesterday.id])
    }

    func testGroupedByDayEmpty() {
        XCTAssertTrue(Logic.groupedByDay(events: [], calendar: cal).isEmpty)
    }
}
