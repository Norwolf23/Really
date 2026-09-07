import Foundation
import DeviceActivity
import ManagedSettings

/// Runs when a shield button is tapped. Primary = "No", secondary = "Yes, really".
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for token: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let store = Store()
        // ponytail: Application(token:) has nil name/bundle id in this extension; the configuration extension just wrote who it showed.
        let shown = store.state.lastShown ?? Shown(id: "unknown", name: "that app")
        switch action {
        case .primaryButtonPressed:
            store.record(.no, app: shown.id, name: shown.name)
            completionHandler(.close)
        case .secondaryButtonPressed:
            let until = Date.now.addingTimeInterval(Double(store.settings.cooldownMinutes) * 60)
            store.state.cooldowns[shown.id] = until
            store.record(.proceed, app: shown.id, name: shown.name)
            ManagedSettingsStore().shield.applications?.remove(token)
            let center = DeviceActivityCenter()
            let name = DeviceActivityName("cooldown")
            let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            let calendar = Calendar.current
            // ponytail: one shared activity, so overlapping cooldowns end together. Apple's minimum interval is 15 min.
            center.stopMonitoring([name])
            try? center.startMonitoring(name, during: DeviceActivitySchedule(
                intervalStart: calendar.dateComponents(parts, from: .now),
                intervalEnd: calendar.dateComponents(parts, from: until),
                repeats: false))
            completionHandler(.none) // ponytail: if the shield doesn't lift on device, return .close and let the user reopen the app
        @unknown default:
            completionHandler(.close)
        }
    }
}
