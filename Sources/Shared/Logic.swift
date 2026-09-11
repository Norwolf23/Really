import Foundation

/// Pure functions. No I/O, no singletons, fully unit-tested.
enum Logic {
    /// 1 for the first open of the day, 2 for the second, and so on.
    static func openNumberToday(events: [CheckIn], appID: String, now: Date, calendar: Calendar = .current) -> Int {
        events.filter { $0.appID == appID && calendar.isDate($0.at, inSameDayAs: now) }.count + 1
    }

    static func tier(openNumber: Int, annoyedAt: Int, brutalAt: Int) -> Tier {
        if openNumber >= brutalAt { return .brutal }
        if openNumber >= annoyedAt { return .annoyed }
        return .normal
    }

    static func effectiveTier(base: Tier, openNumber: Int, annoyedAt: Int, brutalAt: Int, escalates: Bool) -> Tier {
        guard escalates else { return base }
        return max(base, tier(openNumber: openNumber, annoyedAt: annoyedAt, brutalAt: brutalAt))
    }

    /// A random line from the tier (falling back to a lower tier, then anything). The shield extension can't
    /// remember what it showed last, so a repeat now and then is the price of randomness.
    static func pickQuestion<G: RandomNumberGenerator>(pack: [Question], tier: Tier, using rng: inout G) -> Question? {
        guard !pack.isEmpty else { return nil }
        var candidates = pack.filter { $0.tier == tier }
        if candidates.isEmpty { candidates = pack.filter { $0.tier < tier } }
        if candidates.isEmpty { candidates = pack }
        return candidates.randomElement(using: &rng)
    }

    struct HourCount: Identifiable {
        let hour: Int
        var opened: Int
        var stopped: Int
        var id: Int { hour }
    }

    /// Asks per hour of day, all time.
    static func hourCounts(events: [CheckIn], calendar: Calendar = .current) -> [HourCount] {
        var counts = (0..<24).map { HourCount(hour: $0, opened: 0, stopped: 0) }
        for event in events {
            let h = calendar.component(.hour, from: event.at)
            if event.decision == .proceed { counts[h].opened += 1 } else { counts[h].stopped += 1 }
        }
        return counts
    }

    /// Gentle-phase lines: a nudge, one button, no question.
    static let reminders = [
        "Careful, don't get lost in the reels.",
        "Heads-up: the scroll is endless, your afternoon isn't.",
        "Quick reminder to chill. It'll all still be here later.",
        "Easy. You don't need to keep opening this.",
        "Small nudge: notice you're here, then carry on.",
    ]

    /// How many opens a day get a reminder instead of a question: 4 or 5. Derived from the date, not stored, so the
    /// read-only config extension and the action extension always agree, and the cutoff shifts day to day.
    static func gentleLimit(now: Date, calendar: Calendar = .current) -> Int {
        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        return 4 + (((day &* 2_654_435_761) >> 16) & 1)
    }

    static func isGentle(openNumber: Int, limit: Int, enabled: Bool) -> Bool {
        enabled && openNumber <= limit
    }

    enum ShieldStep { case through, close }

    /// Primary "Yea, I am" kicks you out; secondary "Nope, I've got a reason to be here" lets you in.
    /// In the gentle phase the only button is "Okay thanks!", which lets you in.
    static func shieldStep(primary: Bool, gentle: Bool) -> ShieldStep {
        primary && !gentle ? .close : .through
    }

    static func anyCooldownActive(_ cooldowns: [String: Date], now: Date) -> Bool {
        cooldowns.values.contains { $0 > now }
    }

    /// Cooldowns whose end has passed, and the ones still running.
    static func splitCooldowns(_ cooldowns: [String: Date], now: Date) -> (expired: [String], active: [String: Date]) {
        let active = cooldowns.filter { $0.value > now }
        let expired = cooldowns.keys.filter { active[$0] == nil }.sorted()
        return (expired, active)
    }

    /// DeviceActivity refuses intervals under 15 min, and a 15-min interval built from two Dates can round below
    /// the floor once seconds are dropped. So: at least the floor, plus one.
    static func scheduleMinutes(setting: Int) -> Int {
        max(15, setting) + 1
    }

    struct AppCount: Identifiable, Equatable {
        let id: String
        var tried: Int   // every time the shield asked
        var opened: Int  // times the answer let them in
        var stopped: Int { tried - opened }
        /// Share of asks that ended with the app closed. Nil until the app has been asked once.
        var stoppedShare: Double? { tried == 0 ? nil : Double(stopped) / Double(tried) }
    }

    /// Per app, most-tried first.
    static func appCounts(events: [CheckIn]) -> [AppCount] {
        Dictionary(grouping: events, by: \.appID).map { id, mine in
            AppCount(id: id, tried: mine.count, opened: mine.filter { $0.decision == .proceed }.count)
        }
        .sorted { $0.tried != $1.tried ? $0.tried > $1.tried : $0.id < $1.id }
    }

    /// Today's asks per app, most first. `tried` is the opens count; the shield is down during a cooldown, so
    /// re-opens inside one are not seen.
    static func opensToday(events: [CheckIn], now: Date, calendar: Calendar = .current) -> [AppCount] {
        appCounts(events: events.filter { calendar.isDate($0.at, inSameDayAs: now) })
    }

    /// Mean asks per day for one app over the last `days` days, today included.
    static func averageOpensPerDay(events: [CheckIn], appID: String, days: Int, now: Date, calendar: Calendar = .current) -> Double {
        guard days > 0, let start = calendar.date(byAdding: .day, value: 1 - days, to: calendar.startOfDay(for: now)) else { return 0 }
        let count = events.filter { $0.appID == appID && $0.at >= start }.count
        return Double(count) / Double(days)
    }

    /// What open number `openNumber` gets: "gentle", "questions", "mean" or "brutal".
    static func stage(openNumber: Int, settings: Settings, now: Date, calendar: Calendar = .current) -> String {
        if isGentle(openNumber: openNumber, limit: gentleLimit(now: now, calendar: calendar), enabled: settings.gentleFirst) { return "gentle" }
        switch effectiveTier(base: settings.meanness, openNumber: openNumber, annoyedAt: settings.annoyedAt,
                             brutalAt: settings.brutalAt, escalates: settings.escalates) {
        case .normal: return "questions"
        case .annoyed: return "mean"
        case .brutal: return "brutal"
        }
    }

    struct DayCount: Identifiable {
        let day: Date
        var proceeds: Int
        var nos: Int
        var id: Date { day }
    }

    static func dailyCounts(events: [CheckIn], days: Int, now: Date, calendar: Calendar = .current) -> [DayCount] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let that = events.filter { calendar.isDate($0.at, inSameDayAs: day) }
            return DayCount(day: day,
                            proceeds: that.filter { $0.decision == .proceed }.count,
                            nos: that.filter { $0.decision == .no }.count)
        }
    }

    static func worstHour(events: [CheckIn], calendar: Calendar = .current) -> Int? {
        var counts = [Int](repeating: 0, count: 24)
        for event in events where event.decision == .proceed {
            counts[calendar.component(.hour, from: event.at)] += 1
        }
        guard let best = counts.max(), best > 0 else { return nil }
        return counts.firstIndex(of: best)
    }

    struct DayGroup: Identifiable {
        let day: Date
        let events: [CheckIn]
        var id: Date { day }
    }

    static func groupedByDay(events: [CheckIn], calendar: Calendar = .current) -> [DayGroup] {
        let groups = Dictionary(grouping: events) { calendar.startOfDay(for: $0.at) }
        return groups.keys.sorted(by: >).map { day in
            DayGroup(day: day, events: (groups[day] ?? []).sorted { $0.at > $1.at })
        }
    }
}
