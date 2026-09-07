import DeviceActivity
import Foundation
import ManagedSettings

/// Runs when a shield button is tapped. Nothing here blocks anyone; it only asks, logs, and lets through.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for token: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let store = Store()
        // ponytail: Application(token:) has nil name/bundle id in this extension; the configuration extension just wrote who it showed.
        let shown = store.state.lastShown ?? Shown(id: "unknown", name: "that app")
        // ponytail: no second round. iOS ignores .defer while the app is in the foreground, so a shield gets one question.
        switch Logic.shieldStep(primary: action == .primaryButtonPressed) {
        case .close: // Yea, I am
            store.record(.no, app: shown.id, name: shown.name)
            completionHandler(.close)
        case .through: // Nope, I've got a reason to be here
            store.record(.proceed, app: shown.id, name: shown.name)
            let until = Date.now.addingTimeInterval(Double(store.settings.cooldownMinutes) * 60)
            store.state.cooldowns[shown.id] = until
            ManagedSettingsStore().shield.applications?.remove(token)
            // Bring the question back later. Apple's minimum interval is 15 min.
            let center = DeviceActivityCenter()
            let name = DeviceActivityName("cooldown")
            let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            let calendar = Calendar.current
            center.stopMonitoring([name])
            try? center.startMonitoring(name, during: DeviceActivitySchedule(
                intervalStart: calendar.dateComponents(parts, from: .now),
                intervalEnd: calendar.dateComponents(parts, from: until),
                repeats: false))
            completionHandler(.none) // ponytail: if the shield doesn't lift on device, return .close and let the user reopen the app
        }
    }
}
