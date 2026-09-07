import ManagedSettings
import ManagedSettingsUI
import UIKit

/// iOS asks this for the shield screen every time a picked app is opened, and again after a `.defer`.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let store = Store()
        store.state.lastShown = Shown(id: application.bundleIdentifier ?? "unknown",
                                      name: application.localizedDisplayName ?? "that app")
        // ponytail: one fixed Instagram flow for now; packs/tiers come back once this works on a phone.
        let secondRound = store.state.round == 2
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: nil,
            title: ShieldConfiguration.Label(text: "REALLY?", color: .gray),
            subtitle: ShieldConfiguration.Label(text: secondRound ? "Do you still want to go through?" : "Here to doomscroll your problems away again?", color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: secondRound ? "No" : "Nah, making a new post", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(text: secondRound ? "Yes" : "Yea", color: .gray)
        )
    }
}
