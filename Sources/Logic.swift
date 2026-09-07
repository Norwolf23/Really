import Foundation

/// Pure functions. No I/O, no singletons, fully unit-tested.
enum Logic {
    static func isInCooldown(_ app: GatedApp, now: Date) -> Bool {
        guard let until = app.cooldownUntil else { return false }
        return now < until
    }

    static func shouldAsk(_ app: GatedApp?, now: Date) -> Bool {
        guard let app, app.enabled else { return false }
        return !isInCooldown(app, now: now)
    }

    /// 1 for the first open of the day, 2 for the second, and so on.
    static func openNumberToday(events: [CheckIn], appID: String, now: Date, calendar: Calendar = .current) -> Int {
        events.filter { $0.appID == appID && calendar.isDate($0.at, inSameDayAs: now) }.count + 1
    }

    static func tier(openNumber: Int, annoyedAt: Int, brutalAt: Int) -> Tier {
        if openNumber >= brutalAt { return .brutal }
        if openNumber >= annoyedAt { return .annoyed }
        return .normal
    }

    static func pickQuestion<G: RandomNumberGenerator>(for app: GatedApp, pack: [Question], tier: Tier, using rng: inout G) -> Question? {
        let pool = app.source == .starterPack ? pack : app.customQuestions
        guard !pool.isEmpty else { return nil }
        if app.mode == .single {
            return pool.first { $0.id == app.singleQuestionID } ?? pool[0]
        }
        var candidates = pool.filter { $0.tier == tier }
        if candidates.isEmpty { candidates = pool.filter { $0.tier < tier } }
        if candidates.isEmpty { candidates = pool }
        if candidates.count > 1 { candidates.removeAll { $0.id == app.lastQuestionID } }
        return candidates.randomElement(using: &rng)
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

    static func timeSavedMinutes(events: [CheckIn], apps: [GatedApp]) -> Int {
        var minutes: [String: Int] = [:]
        for app in apps { minutes[app.id] = app.sessionMinutes }
        return events.filter { $0.decision == .no }.reduce(0) { $0 + (minutes[$1.appID] ?? 0) }
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
}
