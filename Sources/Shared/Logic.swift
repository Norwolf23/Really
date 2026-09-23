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

    /// Each reason buys this many minutes.
    static let fullBlockSession = 5

    static func fullBlockMinutesUsed(_ grants: [FullBlockGrant], now: Date, calendar: Calendar = .current) -> Int {
        grants.filter { calendar.isDate($0.at, inSameDayAs: now) }.reduce(0) { $0 + $1.minutes }
    }

    static func fullBlockRemaining(dailyMinutes: Int, grants: [FullBlockGrant], now: Date, calendar: Calendar = .current) -> Int {
        max(0, dailyMinutes - fullBlockMinutesUsed(grants, now: now, calendar: calendar))
    }

    /// On takes effect now. Off waits until the next midnight, and the block stays up until then.
    static func fullBlockOffDate(now: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }

    static func fullBlockIsActive(enabled: Bool, offAt: Date?, now: Date) -> Bool {
        if enabled { return true }
        if let offAt, now < offAt { return true }
        return false
    }

    /// Nil when full block is off, a grant is still open, or less than one session is left today.
    static func fullBlockGrantMinutes(active: Bool, dailyMinutes: Int, grants: [FullBlockGrant], now: Date, calendar: Calendar = .current) -> Int? {
        guard active, !grants.contains(where: { $0.until > now }) else { return nil }
        let left = fullBlockRemaining(dailyMinutes: dailyMinutes, grants: grants, now: now, calendar: calendar)
        return left >= fullBlockSession ? fullBlockSession : nil
    }

    static let freeAppLimit = 1

    /// While Pro is on, or a full block is still inside its last day, every picked app stays.
    /// Otherwise one app keeps the question shield.
    static func keptAppIDs(_ ids: [String], pro: Bool, fullBlockActive: Bool) -> Set<String> {
        if pro || fullBlockActive { return Set(ids) }
        return Set(ids.sorted().prefix(freeAppLimit))
    }

    /// Pro ending uses the same rule as turning Full Block off: it holds until the next midnight.
    static func proLapse(fullBlockEnabled: Bool, offAt: Date?, now: Date, calendar: Calendar = .current) -> (enabled: Bool, offAt: Date?) {
        guard fullBlockEnabled else { return (false, offAt) }
        return (false, fullBlockOffDate(now: now, calendar: calendar))
    }

    static func fullBlockShieldLine(remaining: Int) -> String {
        remaining >= fullBlockSession
            ? "Open Really? and write why. \(remaining) minutes left today."
            : "No time left today."
    }

    /// Apps that should be unshielded right now. While full block is active, only an open grant lifts an app.
    /// A question cooldown does not.
    static func unlockedIDs(cooldowns: [String: Date], grants: [String: [FullBlockGrant]], fullBlockActive: Bool, now: Date) -> Set<String> {
        let cooled = Set(cooldowns.filter { $0.value > now }.map(\.key))
        let open = Set(grants.compactMap { id, list in list.contains { $0.until > now } ? id : nil })
        return fullBlockActive ? open : cooled.union(open)
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
