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

    // MARK: question selection

    struct FixedRNG: RandomNumberGenerator {
        var value: UInt64
        mutating func next() -> UInt64 { value }
    }

    let pack: [Question] = [
        Question(id: "n0", text: "n0", tier: .normal),
        Question(id: "n1", text: "n1", tier: .normal),
        Question(id: "a0", text: "a0", tier: .annoyed),
        Question(id: "b0", text: "b0", tier: .brutal),
    ]

    func testPickReturnsNilForEmptyPool() {
        var rng = FixedRNG(value: 0)
        XCTAssertNil(Logic.pickQuestion(for: app(), pack: [], tier: .normal, using: &rng))
    }

    func testPickSingleReturnsChosenQuestion() {
        var a = app(); a.mode = .single; a.singleQuestionID = "a0"
        var rng = FixedRNG(value: 0)
        XCTAssertEqual(Logic.pickQuestion(for: a, pack: pack, tier: .brutal, using: &rng)?.id, "a0")
    }

    func testPickSingleFallsBackToFirstWhenIDMissing() {
        var a = app(); a.mode = .single; a.singleQuestionID = "gone"
        var rng = FixedRNG(value: 0)
        XCTAssertEqual(Logic.pickQuestion(for: a, pack: pack, tier: .normal, using: &rng)?.id, "n0")
    }

    func testPickRotateStaysInTier() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<20 {
            let q = Logic.pickQuestion(for: app(), pack: pack, tier: .annoyed, using: &rng)
            XCTAssertEqual(q?.tier, .annoyed)
        }
    }

    func testPickRotateFallsBackToLowerTierThenAnything() {
        let onlyNormal = pack.filter { $0.tier == .normal }
        var rng = SystemRandomNumberGenerator()
        XCTAssertEqual(Logic.pickQuestion(for: app(), pack: onlyNormal, tier: .brutal, using: &rng)?.tier, .normal)
        let onlyBrutal = pack.filter { $0.tier == .brutal }
        XCTAssertEqual(Logic.pickQuestion(for: app(), pack: onlyBrutal, tier: .normal, using: &rng)?.id, "b0")
    }

    func testPickRotateAvoidsLastShown() {
        var a = app(); a.lastQuestionID = "n0"
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<20 {
            XCTAssertEqual(Logic.pickQuestion(for: a, pack: pack, tier: .normal, using: &rng)?.id, "n1")
        }
    }

    func testPickRotateRepeatsWhenOnlyOneCandidate() {
        var a = app(); a.lastQuestionID = "a0"
        var rng = SystemRandomNumberGenerator()
        XCTAssertEqual(Logic.pickQuestion(for: a, pack: pack, tier: .annoyed, using: &rng)?.id, "a0")
    }

    func testPickUsesCustomQuestionsWhenSourceIsCustom() {
        var a = app(); a.source = .custom
        a.customQuestions = [Question(id: "c", text: "custom", tier: .normal)]
        var rng = SystemRandomNumberGenerator()
        XCTAssertEqual(Logic.pickQuestion(for: a, pack: pack, tier: .normal, using: &rng)?.id, "c")
    }

    // MARK: streak

    func daysAgo(_ d: Int, _ decision: Decision = .no) -> CheckIn {
        CheckIn(appID: "instagram", at: cal.date(byAdding: .day, value: -d, to: now)!, decision: decision)
    }

    func testStreakZeroWithNoEvents() {
        XCTAssertEqual(Logic.streak(events: [], now: now, calendar: cal), 0)
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        XCTAssertEqual(Logic.streak(events: [daysAgo(0), daysAgo(1), daysAgo(2)], now: now, calendar: cal), 3)
    }

    func testStreakSurvivesWhenTodayHasNoNoYet() {
        XCTAssertEqual(Logic.streak(events: [daysAgo(1), daysAgo(2)], now: now, calendar: cal), 2)
    }

    func testStreakBreaksOnGap() {
        XCTAssertEqual(Logic.streak(events: [daysAgo(0), daysAgo(2), daysAgo(3)], now: now, calendar: cal), 1)
    }

    func testStreakIgnoresContinueEvents() {
        XCTAssertEqual(Logic.streak(events: [daysAgo(0, .proceed), daysAgo(1)], now: now, calendar: cal), 1)
        XCTAssertEqual(Logic.streak(events: [daysAgo(0, .proceed), daysAgo(1, .proceed)], now: now, calendar: cal), 0)
    }

    func testStreakZeroWhenLastNoWasTwoDaysAgo() {
        XCTAssertEqual(Logic.streak(events: [daysAgo(2), daysAgo(3)], now: now, calendar: cal), 0)
    }

    // MARK: time saved

    func testTimeSavedSumsSessionMinutesOverNoEvents() {
        var ig = app("instagram"); ig.sessionMinutes = 12
        var tt = app("tiktok"); tt.sessionMinutes = 20
        let events = [event("instagram", minutesAgo: 1), event("instagram", minutesAgo: 2, .proceed), event("tiktok", minutesAgo: 3), event("gone", minutesAgo: 4)]
        XCTAssertEqual(Logic.timeSavedMinutes(events: events, apps: [ig, tt]), 32)
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

    // MARK: effective tier

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

    // MARK: reasons

    func reasoned(_ reason: String?, daysAgo d: Int = 0, _ decision: Decision = .proceed) -> CheckIn {
        CheckIn(appID: "instagram", at: cal.date(byAdding: .day, value: -d, to: now)!, decision: decision, reason: reason)
    }

    func testReasonCountsOnlyCountsProceedWithReasonInsideWindow() {
        let events = [
            reasoned("Bored"), reasoned("Bored"), reasoned("Checking one thing"),
            reasoned("Bored", daysAgo: 0, .no), reasoned(nil), reasoned(""), reasoned("Old", daysAgo: 10),
        ]
        let since = cal.date(byAdding: .day, value: -7, to: now)!
        let counts = Logic.reasonCounts(events: events, since: since)
        XCTAssertEqual(counts.map(\.reason), ["Bored", "Checking one thing"])
        XCTAssertEqual(counts.map(\.count), [2, 1])
    }

    func testReasonCountsTieBreaksAlphabetically() {
        let counts = Logic.reasonCounts(events: [reasoned("Zzz"), reasoned("Aaa")], since: now.addingTimeInterval(-60))
        XCTAssertEqual(counts.map(\.reason), ["Aaa", "Zzz"])
    }

    // MARK: worst hour

    func at(hour: Int, _ decision: Decision = .proceed) -> CheckIn {
        CheckIn(appID: "instagram", at: cal.date(bySettingHour: hour, minute: 0, second: 0, of: now)!, decision: decision)
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
        let yesterday = CheckIn(appID: "instagram", at: cal.date(byAdding: .day, value: -1, to: at(hour: 9).at)!, decision: .no)
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
