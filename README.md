# Really?

A dry, sarcastic question before you open an app you open too much.

## Build

    brew install xcodegen   # once
    xcodegen generate
    open Really.xcodeproj

Run the `Really` scheme on your iPhone (iOS 17+). Tests: `xcodebuild test -project Really.xcodeproj -scheme Really -destination 'platform=iOS Simulator,name=iPhone 17'`.

## Set up an app

1. In Really?, tap + and add the app.
2. Tap the app, then Automation setup, and follow the six steps in the Shortcuts app.

Starter-pack lines are append-only: editing or reordering a pack shifts saved single-question choices.

The automation runs Really?'s **Check In** action silently. It returns `ask` when
the app is enabled and you are outside the cooldown, and the If block then runs
**Ask**, which opens the question. After Continue, Really? opens the app and
starts the cooldown, so the re-fired automation stays silent.

## What v0.2 adds

- First-launch intro: pick your apps and how mean Really? should be (Mild, Mean, Brutal).
- Settings tab: meanness, "Gets meaner through the day" (uses each app's Annoyed and Brutal thresholds), replay the intro.
- Continue asks why. Pick a reason or type one; it lands in the log.
- Stats: your leading excuse this week, the hour you most often cave, and a full check-in log filterable by app.

## Design docs

- Spec: `docs/superpowers/specs/2026-09-06-really-design.md`
- Plan: `docs/superpowers/plans/2026-09-06-really-v1.md`
- v2 spec: `docs/superpowers/specs/2026-09-06-really-v2-design.md`
- v2 plan: `docs/superpowers/plans/2026-09-06-really-v2.md`
