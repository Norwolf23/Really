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
}
