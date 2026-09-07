import ManagedSettings
import ManagedSettingsUI
import UIKit

/// iOS asks this for the shield screen every time a picked app is opened.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // This extension's sandbox denies file writes in the App Group, so hand the app identity to the
        // action extension through shared preferences (cfprefsd) instead of state.json.
        let shared = UserDefaults(suiteName: Store.group)
        shared?.set(application.bundleIdentifier ?? "unknown", forKey: "lastShownID")
        shared?.set(application.localizedDisplayName ?? "that app", forKey: "lastShownName")
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
