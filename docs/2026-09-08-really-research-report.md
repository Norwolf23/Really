# Really? — research and review report

**Date:** 2026-09-08 (research run the evening of 2026-09-07)
**State:** branch `claude/screentime`, PR #3, commit `6724849`. Confirmed working on Gustav's iPhone 15 (iOS 26.6.1). **No code was changed after that confirmation.** Everything below is a finding or a recommendation, not something already done.

Sources: four parallel investigations (Apple docs, Apple Developer Forums, WWDC22, shipping open-source projects, and a line-by-line review of this repo). Links are inline.

---

## 1. What we now know for certain (from your phone's logs)

These are the facts that cost the evening. They are already in the code and in the project memory.

| Fact | Consequence |
|---|---|
| The button extension's point id is `com.apple.ManagedSettings.shield-action-service`, without "UI". The UI variant matches nothing and iOS silently drops every tap. | Fixed. This was the whole "nothing happens" saga. |
| The shield-drawing extension runs in a stricter sandbox: it can **read** the App Group but cannot write files or shared preferences. Apple confirms this is by design (["prevents your Shield Configuration extension from sharing state"](https://developer.apple.com/forums/thread/727058), [read allowed](https://developer.apple.com/forums/thread/716698)). The button and timer extensions can write. | All writing happens in the button extension. App identity is the opaque token, not a name. |
| Atomic file writes fail in the extensions (the rename needs an unlink the sandbox denies). | Store writes in place. See risk 2.1. |
| Restarting the re-shield timer fires its "interval ended" hook immediately ([Habit Doom](https://habitdoom.com/blog/apple-screen-time-api-guide), [forum](https://developer.apple.com/forums/thread/774285)). | The timer extension now checks the cooldown timestamp before re-shielding. That was the flicker. |
| The default `ManagedSettingsStore()` **is shared** between the app and all its extensions since iOS 16 ([Apple engineer](https://developer.apple.com/forums/thread/707144), [WWDC22](https://developer.apple.com/videos/play/wwdc2022/110336/)). The "container" name in the logs is just the caller. | No named stores or App Group tricks needed. Current code is correct. |
| `.defer` does not redraw the shield while the app is in the foreground ([years-old bug, still on iOS 26](https://developer.apple.com/forums/thread/717269)). | Two-round questions are not possible on a shield. One question per shield. |
| Instagram has an Apple **App Limit** on your phone. | The "Screen Time limit" screen you saw after our shield lifts is Apple's, not ours. Settings → Screen Time → App Limits. |

---

## 2. Risks in the current build, ranked

Severity is about "would Gustav notice on his phone in the next week".

### 2.1 History can be wiped by a torn read — HIGH
`Store.load` treats any decode failure as corruption: it moves the file to `.bak` and starts empty. Writes are now non-atomic, so a reader can catch a half-written file. If the button extension does that, it silently records one event on top of an empty list and history is gone. The app also rewrites both files on every foreground (`reload()` assigns, `didSet` saves), widening the window.
**Fix (small):** app keeps atomic writes (only the extensions are denied); `reload()` sets a flag so it doesn't write back; a failed load returns nil without moving the file aside, and `record` refuses to write over a file it couldn't read.

### 2.2 The shield may not come back after "Nope" — HIGH, and partly Apple's fault
The 15-minute re-shield relies on DeviceActivity, which is the least reliable part of the whole API: one-shot intervals reported never firing on iOS 26.x ([1](https://developer.apple.com/forums/thread/820956), [2](https://developer.apple.com/forums/thread/819224)), Apple: ["known issue, please file a bug"](https://developer.apple.com/forums/thread/751597). Our own code adds three weaknesses: the schedule is started *after* the completion handler (Apple says code after the handler ["will likely not be executed"](https://developer.apple.com/forums/thread/727058)); a 15-minute interval built from two `Date`s can round below the 15-minute floor and throw `intervalTooShort`, which we swallow; and one shared timer name means a second "Nope" cancels the first app's timer.
**What works today:** opening Really? re-applies the shields when no cooldown is active. That's the safety net, and it's why it "works".
**Fix, in order of value:** schedule 16 minutes starting one second from now, with hour/minute/second components only; schedule *before* the handler (the shield removal is the only thing that must precede it); clamp the setting to ≥15; use one timer name per unlock; in the timer extension, re-add only the tokens whose cooldown expired instead of bailing when any is still running. Fallbacks the shipping apps use: re-apply on every app launch (already have it) plus a repeating all-day monitor whose start hook re-applies shields.

### 2.3 App Store validation will reject the build — MEDIUM (blocks shipping, not use)
Extensions carry version `1.0` / `1`; the app is `0.3` / `1`. Verified locally in `Extensions/*-Info.plist`. Apple requires them to match.
**Fix (one line in project.yml):** add `CFBundleShortVersionString` and `CFBundleVersion` to the extension template.

### 2.4 Token bytes can differ between the picker and the extensions — MEDIUM
Apple-confirmed bug since iOS 17.4.1, no workaround ([FB14111223](https://developer.apple.com/forums/thread/758325), [still on 26.2](https://developer.apple.com/forums/thread/814571)). Our design already tolerates it: we store whatever bytes the button extension saw and render `Label(token)` from those bytes, which works even when equality fails ([Apple's own persist-then-display guidance](https://developer.apple.com/documentation/familycontrols/displayingactivitylabels)). The one place it bites: the timer extension re-applies `selection.applicationTokens`, so an app whose extension-side token differs would be re-shielded correctly anyway (we re-apply the whole picker selection, not the logged tokens). Fine as is. Just never match logged ids against the selection.

### 2.5 Picking a category does nothing — MEDIUM
If you tick "Social" instead of individual apps, `applicationTokens` is empty: onboarding's Continue stays disabled and the Apps tab says "No apps yet" while the picker shows ticks. Category-shielded apps also hit a different extension callback we don't override ([forum](https://developer.apple.com/forums/thread/791334)).
**Fix:** `FamilyActivitySelection(includeEntireCategory: true)` expands categories into app tokens, or override the `in category:` variants in both extensions.

### 2.6 Settings file is fragile — MEDIUM
Adding any field to `Settings` (or a token failing to decode) makes the whole file undecodable; the app moves it aside, replays onboarding and forgets the picked apps while the shield stays applied on the phone.
**Fix:** hand-written `init(from:)` with `decodeIfPresent` and defaults.

### 2.7 "Time saved" is now a constant — LOW
`Catalog.sessionMinutes` is keyed by bundle id, but ids are tokens now, so every "no" counts 10 minutes. The Catalog and its tests are dead code. Either drop the stat and the Catalog, or accept the flat number and say so in the UI.

### 2.8 Small things — LOW
- `Task { picking = true }` mutates SwiftUI state off the main actor in two views. Add `@MainActor` to the task.
- events.json is decoded and re-encoded whole on every tap inside an extension with a ~6 MB budget. Cap it (last few thousand events) before it matters.
- `Label(token)` is rendered out-of-process on the main thread; six or more in one list can hang ([FB12332927](https://developer.apple.com/forums/thread/727437)). The Log view renders one per row. Lazy list or a cap if it ever stutters. Font and color modifiers on it are ignored.
- The `.none` response after lifting the shield works on your phone. There is one TestFlight-only report of the shield freezing with it ([DTS, no fix](https://developer.apple.com/forums/thread/807934)); the open-source `react-native-device-activity` returns `.close` instead. Worth knowing before the first TestFlight build.
- Shield config is cached per app launch ([forum](https://developer.apple.com/forums/thread/766643)): when packs/tiers return, the question changes only after the target app is relaunched.

---

## 3. Things that are fine and I'd leave alone

- Shared default store, extension embedding, entitlements, deployment targets (all four at 17.0), extension point ids: all verified.
- The loose 256 px PNG icon: correct format. PDF icons make iOS fall back to the default shield.
- Reading events in the shield-drawing extension for "open number today" is allowed, so escalating meanness can come back without any new plumbing.

---

## 4. Suggested order of work, when you want it

1. Storage safety (2.1) and Settings decoding (2.6). Half a day, prevents the only data-loss path.
2. Re-shield hardening (2.2). Half a day. The fallback already covers you, so this is about not needing to open Really? to re-arm.
3. Version numbers (2.3) and category picks (2.5). Minutes each.
4. Then product work: packs and tiers back on the shield, per-app stats via `Label(token)`.
5. App Store: request the Family Controls distribution entitlement for all four bundle ids as early as possible (Apple reviews manually, days to weeks). Development builds keep working meanwhile.

---

## 5. iOS 26.4 note
Two API additions worth a look when you're on 26.4: `secondaryButtonSubmenuItems` on the shield (up to three extra choices under the second button, [docs](https://developer.apple.com/documentation/managedsettingsui/shieldconfiguration/secondarybuttonsubmenuitems)), which could carry "reasons" without a second screen; and `approvedWithDataAccess`, which exposes real app names and bundle ids, but EU only.
