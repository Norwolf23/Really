import ManagedSettings
import ManagedSettingsUI
import UIKit

/// iOS asks this for the shield screen every time a picked app is opened.
/// This extension's sandbox is read-only (no App Group files, no shared prefs), so it only reads.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let store = Store()
        let settings = store.settings
        let id = application.token.map(TokenID.string) ?? "unknown"
        let openNumber = Logic.openNumberToday(events: store.events, appID: id, now: .now)
        if Logic.isGentle(openNumber: openNumber, limit: Logic.gentleLimit(now: .now), enabled: settings.gentleFirst) {
            return ShieldConfiguration(
                backgroundBlurStyle: .systemUltraThinMaterialDark,
                backgroundColor: .black,
                icon: UIImage(named: "shield-icon"),
                title: ShieldConfiguration.Label(text: "REALLY?", color: .gray),
                subtitle: ShieldConfiguration.Label(text: Logic.reminders.randomElement() ?? "", color: .white),
                primaryButtonLabel: ShieldConfiguration.Label(text: "Okay thanks!", color: .black),
                primaryButtonBackgroundColor: .white
            )
        }
        let tier = Logic.effectiveTier(base: settings.meanness, openNumber: openNumber,
                                       annoyedAt: settings.annoyedAt, brutalAt: settings.brutalAt, escalates: settings.escalates)
        let pack = Packs.questions(for: Catalog.pack(for: application.bundleIdentifier ?? ""))
        var rng = SystemRandomNumberGenerator()
        let question = Logic.pickQuestion(pack: pack, tier: tier, using: &rng)
            ?? Question(id: "fallback", text: "Are you avoiding something again?", tier: .normal)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: UIImage(named: "shield-icon"),
            title: ShieldConfiguration.Label(text: "REALLY?", color: .gray),
            subtitle: ShieldConfiguration.Label(text: question.text, color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: question.yes, color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(text: question.no, color: .white)
        )
    }
}
