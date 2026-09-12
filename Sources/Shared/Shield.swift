import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum Shield {
    static let dailyActivity = DeviceActivityName("daily")

    /// Shield exactly the picked apps (categories are expanded into apps by the selection itself).
    static func apply(_ selection: FamilyActivitySelection) {
        ManagedSettingsStore().shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        startDailyMonitor()
    }

    /// Put back the shields whose cooldown has passed. Used by the monitor extension and the app on foreground.
    /// With everything expired, the whole selection is re-applied so the shield matches the picker exactly.
    static func reshieldExpired(_ store: Store, now: Date = .now) {
        let split = Logic.splitCooldowns(store.state.cooldowns, now: now)
        guard !split.expired.isEmpty else { return }
        store.state.cooldowns = split.active
        if split.active.isEmpty {
            apply(store.settings.selection)
        } else {
            let tokens = Set(split.expired.compactMap(TokenID.token))
            ManagedSettingsStore().shield.applications = (ManagedSettingsStore().shield.applications ?? []).union(tokens)
        }
    }

    /// App-side wrapper: only once Screen Time access is granted.
    static func reapplyIfIdle(_ store: Store, now: Date = .now) {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { return }
        if store.state.cooldowns.isEmpty {
            apply(store.settings.selection)
        } else {
            reshieldExpired(store, now: now)
        }
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
