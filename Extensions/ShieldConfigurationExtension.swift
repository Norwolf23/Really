import ManagedSettings
import ManagedSettingsUI
import UIKit

/// iOS asks this for the shield screen every time a picked app is opened.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let store = Store()
        let id = application.bundleIdentifier ?? "unknown"
        store.state.lastShown = Shown(id: id, name: application.localizedDisplayName ?? "that app")
        let settings = store.settings
        let tier = Logic.effectiveTier(base: settings.meanness,
                                       openNumber: Logic.openNumberToday(events: store.events, appID: id, now: .now),
                                       annoyedAt: settings.annoyedAt,
                                       brutalAt: settings.brutalAt,
                                       escalates: settings.escalates)
        var rng = SystemRandomNumberGenerator()
        let question = Logic.pickQuestion(pack: Packs.questions(for: Catalog.pack(for: id)),
                                          tier: tier,
                                          lastID: store.state.lastQuestion[id],
                                          using: &rng)
        store.state.lastQuestion[id] = question?.id
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: nil,
            title: ShieldConfiguration.Label(text: "REALLY?", color: .gray),
            subtitle: ShieldConfiguration.Label(text: question?.text ?? "Are you sure about this?", color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "No", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Yes, really", color: .gray)
        )
    }
}
