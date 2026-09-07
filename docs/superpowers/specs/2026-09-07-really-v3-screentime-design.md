# Really? v0.3 — Screen Time shield instead of Shortcuts

**Date:** 2026-09-07  
**Status:** approved (Gustav, in chat)

## Why

The v0.1/v0.2 interception needed a six-step Shortcuts automation per app. Gustav could not get it working; nobody else will either. iOS has an API for exactly this: Screen Time (FamilyControls + ManagedSettings + DeviceActivity).

## Decision

**Shield only.** The user grants Screen Time access once and picks apps in the system picker. iOS shows our shield in front of those apps. The shield *is* the popup: "REALLY?" + a pack question + a prominent **No** and a smaller **Yes, really**. No countdown ring, no reason sheet — a shield can't host custom UI.

- **No** → logs a no, closes the app.
- **Yes, really** → logs a through, lifts that app's shield for the cooldown (global setting, 15–240 min, minimum 15 because of the DeviceActivity schedule floor), schedules a DeviceActivity interval whose end puts the shield back. Belt and braces: the app re-applies all shields on foreground once no cooldown is running.

## Parts

| Part | Bundle id | Job |
|---|---|---|
| Really (app) | studio.nickson.really | onboarding, picker, settings, stats |
| ShieldConfig | studio.nickson.really.shield-config | picks tier + question, draws the shield, records which app it showed |
| ShieldAction | studio.nickson.really.shield-action | handles the two buttons, writes the event and cooldown |
| Monitor | studio.nickson.really.monitor | `intervalDidEnd` → re-shield |

Shared JSON in App Group `group.studio.nickson.really`, one writer per file: `settings.json` (app), `events.json` + `state.json` (extensions). Only the configuration extension can read an app's bundle id and name, so it writes `state.lastShown` and the action extension reads it.

Question packs are matched by bundle id (Catalog: 8 known apps → pack name, else generic).

## Dropped with this change

Per-app settings, custom questions, single-question mode, reasons/excuses, the pause ring, the Shortcuts intents. See the plan for what would bring each back.

## Entitlement

`com.apple.developer.family-controls` on all four targets. The development variant works for Xcode installs with no Apple approval. Shipping through App Store Connect needs the distribution entitlement requested per bundle id (all four).
