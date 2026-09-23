import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum Shield {
    static let dailyActivity = DeviceActivityName("daily")

    /// Shield the picked apps, leaving off anything with a live cooldown or an open full-block grant.
    static func apply(_ store: Store, now: Date = .now) {
        let active = Logic.fullBlockIsActive(enabled: store.settings.fullBlockEnabled, offAt: store.settings.fullBlockOffAt, now: now)
        let unlocked = Logic.unlockedIDs(cooldowns: store.state.cooldowns, grants: store.settings.fullBlockGrants, fullBlockActive: active, now: now)
        let tokens = store.settings.selection.applicationTokens.subtracting(Set(unlocked.compactMap(TokenID.token)))
        let current = ManagedSettingsStore().shield.applications ?? []
        if current != tokens {
            ManagedSettingsStore().shield.applications = tokens.isEmpty ? nil : tokens
        }
        startDailyMonitor()
    }

    /// Drop expired cooldowns, then make the shield match the picker. An open full-block grant stays off the shield.
    static func reshieldExpired(_ store: Store, now: Date = .now) {
        let split = Logic.splitCooldowns(store.state.cooldowns, now: now)
        if !split.expired.isEmpty { store.state.cooldowns = split.active }
        apply(store, now: now)
    }

    /// App-side wrapper: only once Screen Time access is granted.
    static func reapplyIfIdle(_ store: Store, now: Date = .now) {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { return }
        reshieldExpired(store, now: now)
    }

    /// Write a reason and lift one app for one session, if the daily cap still has room.
    /// The grant stays in settings: that list is the log of when and why.
    @discardableResult
    static func letIn(store: Store, id: String, reason: String, now: Date = .now) -> Bool {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let active = Logic.fullBlockIsActive(enabled: store.settings.fullBlockEnabled, offAt: store.settings.fullBlockOffAt, now: now)
        var grants = store.settings.fullBlockGrants[id] ?? []
        guard !trimmed.isEmpty, Logic.fullBlockGrantMinutes(active: active, dailyMinutes: store.settings.fullBlockDailyMinutes, grants: grants, now: now) != nil else { return false }
        let minutes = Logic.fullBlockSession
        let until = now.addingTimeInterval(Double(minutes) * 60)
        grants.append(FullBlockGrant(reason: trimmed, at: now, until: until, minutes: minutes))
        store.settings.fullBlockGrants[id] = grants
        if TokenID.token(id) != nil {
            scheduleUnlock(until: until, now: now)
            apply(store, now: now)
        }
        return true
    }

    /// One one-shot DeviceActivity interval per unlock, named by its end time. Stale names are stopped only once
    /// their own end has passed (stopping a live one fires intervalDidEnd immediately). Hour/minute/second
    /// components only: mixing calendar fields on one end is known to break the callbacks.
    static func scheduleUnlock(until: Date, now: Date) {
        let center = DeviceActivityCenter()
        let stale = center.activities.filter { name in
            guard name.rawValue.hasPrefix("cooldown-"), let end = Double(name.rawValue.dropFirst(9)) else { return false }
            return end <= now.timeIntervalSince1970
        }
        if !stale.isEmpty { center.stopMonitoring(stale) }
        let parts: Set<Calendar.Component> = [.hour, .minute, .second]
        let calendar = Calendar.current
        try? center.startMonitoring(DeviceActivityName("cooldown-\(Int(until.timeIntervalSince1970))"), during: DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(parts, from: now.addingTimeInterval(1)),
            intervalEnd: calendar.dateComponents(parts, from: until),
            repeats: false))
    }

    /// Fallback for one-shot DeviceActivity intervals that never fire: a repeating all-day interval whose
    /// start hook re-shields whatever has expired. Cheap to keep alive; harmless when nothing expired.
    static func startDailyMonitor() {
        let center = DeviceActivityCenter()
        guard !center.activities.contains(dailyActivity) else { return }
        try? center.startMonitoring(dailyActivity, during: DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true))
    }

    static func authorize() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return true
        } catch {
            return false
        }
    }
}
