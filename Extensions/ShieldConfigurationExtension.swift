import ManagedSettings
import ManagedSettingsUI
import UIKit

/// iOS asks this for the shield screen every time a picked app is opened.
/// This extension's sandbox is read-only (no App Group files, no shared prefs), so it only reads.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // ponytail: one fixed question for now; packs/tiers come back once this feels right on a phone.
        // When they do: Store().events + TokenID.string(application.token!) give today's open count,
        // and Catalog.pack(for: application.bundleIdentifier) the pack.
        ShieldConfiguration(
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
