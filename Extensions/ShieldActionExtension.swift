import DeviceActivity
import Foundation
import ManagedSettings

/// Runs when a shield button is tapped. Nothing here blocks anyone; it only asks, logs, and lets through.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for token: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let store = Store()
        let id = TokenID.string(token) // names/bundle ids are unreadable here; the token is the identity
        let openNumber = Logic.openNumberToday(events: store.events, appID: id, now: .now)
        let gentle = Logic.isGentle(openNumber: openNumber, limit: Logic.gentleLimit(now: .now), enabled: store.settings.gentleFirst)
        store.state.lastAction = "\(gentle ? "Okay" : action == .primaryButtonPressed ? "Yea" : "Nope") \(Date.now.formatted(date: .omitted, time: .shortened))"
        // ponytail: no second round. iOS ignores .defer while the app is in the foreground, so a shield gets one question.
        switch Logic.shieldStep(primary: action == .primaryButtonPressed, gentle: gentle) {
        case .close: // Yea, I am
            store.record(.no, app: id)
            completionHandler(.close)
        case .through: // Nope, I've got a reason to be here / Okay thanks!
            let now = Date.now
            let until = now.addingTimeInterval(Double(Logic.scheduleMinutes(setting: store.settings.cooldownMinutes)) * 60)
            store.record(.proceed, app: id)
            store.state.cooldowns[id] = until
            schedule(until: until, now: now)
            var apps = ManagedSettingsStore().shield.applications ?? []
            apps.remove(token)
            ManagedSettingsStore().shield.applications = apps.isEmpty ? nil : apps
            // Everything above runs before the handler: Apple says code after it may never execute.
            completionHandler(.none) // shield is gone, so the app is simply there. If this ever freezes on a device, use .close.
        }
    }

    /// One one-shot DeviceActivity interval per unlock, named by its end time. Stale names are stopped only once
    /// their own end has passed (stopping a live one fires intervalDidEnd immediately). Hour/minute/second
    /// components only: mixing calendar fields on one end is known to break the callbacks.
    private func schedule(until: Date, now: Date) {
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
}
