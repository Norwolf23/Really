import DeviceActivity

/// Puts shields back when cooldowns end: on each one-shot "cooldown-*" interval's end, and every day at the
/// start of the fallback "daily" interval in case a one-shot never fired.
final class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity == Shield.dailyActivity { Shield.reshieldExpired(Store()) }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Fires immediately when the action extension stops a stale interval, and can run a little early,
        // so only apps whose own cooldown has passed (with a minute's tolerance) get their shield back.
        Shield.reshieldExpired(Store(), now: .now.addingTimeInterval(60))
    }
}
