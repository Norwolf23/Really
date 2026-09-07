import FamilyControls
import Foundation
import ManagedSettings

enum Shield {
    /// Shield exactly the picked apps. Categories from the picker are ignored: a category shield
    /// can't be lifted per app, so "Yes, really" would do nothing for apps inside one.
    static func apply(_ selection: FamilyActivitySelection) {
        ManagedSettingsStore().shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    }

    /// Belt and braces for a late DeviceActivity monitor: once no cooldown is running, put every shield back.
    static func reapplyIfIdle(_ store: Store, now: Date = .now) {
        guard AuthorizationCenter.shared.authorizationStatus == .approved,
              !Logic.anyCooldownActive(store.state.cooldowns, now: now) else { return }
        apply(store.settings.selection)
    }

    static func authorize() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return true
        } catch {
            return false
        }
    }
}
