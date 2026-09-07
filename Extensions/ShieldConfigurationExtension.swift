import ManagedSettings
import ManagedSettingsUI
import UIKit

/// iOS asks this for the shield screen every time a picked app is opened.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let store = Store()
        store.state.lastShown = Shown(id: application.bundleIdentifier ?? "unknown",
                                      name: application.localizedDisplayName ?? "that app")
        // ponytail: one fixed question for now; packs/tiers come back once this feels right on a phone.
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: UIImage(named: "shield-icon"),
            title: ShieldConfiguration.Label(text: "REALLY?", color: .gray),
            subtitle: ShieldConfiguration.Label(text: "Are you avoiding something again?", color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Yea, I am", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Nope, I've got a reason to be here", color: .white)
        )
    }
}
