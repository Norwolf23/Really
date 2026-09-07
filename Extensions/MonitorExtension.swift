import DeviceActivity

/// Puts the shields back when a cooldown interval ends.
final class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let store = Store()
        store.state.cooldowns = [:]
        Shield.apply(store.settings.selection)
    }
}
