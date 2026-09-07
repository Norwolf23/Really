import DeviceActivity

/// Puts the shields back when a cooldown interval ends.
final class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let store = Store()
        // stopMonitoring/startMonitoring from the action extension fires this immediately for the old interval,
        // which re-shielded the app the user had just been let into. Only re-shield once every cooldown is really over.
        // 60 s tolerance: the interval can end a moment before the cooldown timestamp.
        guard !Logic.anyCooldownActive(store.state.cooldowns, now: .now.addingTimeInterval(60)) else { return }
        store.state.cooldowns = [:]
        Shield.apply(store.settings.selection)
    }
}
