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

## Design docs

- Spec: `docs/superpowers/specs/2026-09-06-really-design.md`
- Plan: `docs/superpowers/plans/2026-09-06-really-v1.md`
