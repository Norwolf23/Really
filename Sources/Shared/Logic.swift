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

    static func pickQuestion<G: RandomNumberGenerator>(pack: [Question], tier: Tier, lastID: String?, using rng: inout G) -> Question? {
        guard !pack.isEmpty else { return nil }
        var candidates = pack.filter { $0.tier == tier }
        if candidates.isEmpty { candidates = pack.filter { $0.tier < tier } }
        if candidates.isEmpty { candidates = pack }
        if candidates.count > 1 { candidates.removeAll { $0.id == lastID } }
        return candidates.randomElement(using: &rng)
    }

    enum ShieldStep { case through, close }

    /// Primary "Yea, I am" kicks you out; secondary "Nope, I've got a reason to be here" lets you in.
    static func shieldStep(primary: Bool) -> ShieldStep {
        primary ? .close : .through
    }

    static func anyCooldownActive(_ cooldowns: [String: Date], now: Date) -> Bool {
        cooldowns.values.contains { $0 > now }
    }

    static func streak(events: [CheckIn], now: Date, calendar: Calendar = .current) -> Int {
        let noDays = Set(events.filter { $0.decision == .no }.map { calendar.startOfDay(for: $0.at) })
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        var day: Date
        if noDays.contains(today) { day = today } else if noDays.contains(yesterday) { day = yesterday } else { return 0 }
        var count = 0
        while noDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    static func timeSavedMinutes(events: [CheckIn]) -> Int {
        events.filter { $0.decision == .no }.reduce(0) { $0 + Catalog.sessionMinutes(for: $1.appID) }
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
