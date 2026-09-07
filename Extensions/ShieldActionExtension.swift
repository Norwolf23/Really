import DeviceActivity
import Foundation
import ManagedSettings

/// Runs when a shield button is tapped. Nothing here blocks anyone; it only asks, logs, and lets through.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for token: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let store = Store()
        // ponytail: Application(token:) has nil name/bundle id in this extension; the configuration extension just wrote who it showed.
        let shown = store.state.lastShown ?? Shown(id: "unknown", name: "that app")
        store.state.lastAction = "\(action == .primaryButtonPressed ? "Yea" : "Nope") \(Date.now.formatted(date: .omitted, time: .shortened))"
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
            // .none leaves the shield frozen on screen (seen on iOS 26.6), so close; the next tap on the app opens it unshielded.
            completionHandler(.close)
            // Best effort, after the handler: bring the question back later. DeviceActivity calls have hung this
            // extension before, so nothing the user sees depends on it. Apple's minimum interval is 15 min.
            let center = DeviceActivityCenter()
            let name = DeviceActivityName("cooldown")
            let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            let calendar = Calendar.current
            center.stopMonitoring([name])
            try? center.startMonitoring(name, during: DeviceActivitySchedule(
                intervalStart: calendar.dateComponents(parts, from: .now),
                intervalEnd: calendar.dateComponents(parts, from: until),
                repeats: false))
        }
    }
}
