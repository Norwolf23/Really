# Really?

A dry, sarcastic question in front of an app you open too much.

## Build

    brew install xcodegen   # once
    xcodegen generate
    open Really.xcodeproj

Run the `Really` scheme on your iPhone (iOS 17+). The shield only works on a real device.
Tests: `xcodebuild test -project Really.xcodeproj -scheme Really -destination 'platform=iOS Simulator,name=iPhone 17'`.

## Set up

1. Open Really?, grant Screen Time access when asked.
2. Pick apps in the system picker. Done.

iOS now shows the Really? shield whenever one of those apps opens. **No** closes it.
**Yes, really** lets you in for the cooldown (Settings, 15 min minimum), then the shield is back.

## How it works

Three app extensions share one App Group with the app:

- `ShieldConfig` picks the tier (Mild/Mean/Brutal, escalating with today's opens) and a line from the app's pack, and draws the shield.
- `ShieldAction` handles the buttons: logs the answer, lifts the shield and schedules the cooldown.
- `Monitor` puts the shield back when the cooldown ends.

Starter-pack lines are append-only: editing or reordering a pack shifts the "don't repeat the last line" bookkeeping.

## Shipping to the App Store

The Family Controls *development* entitlement works for Xcode installs. Distribution needs Apple's
approval, requested per bundle id: `studio.nickson.really`, `.shield-config`, `.shield-action`, `.monitor`.

## Design docs

- v1 spec: `docs/superpowers/specs/2026-09-06-really-design.md`
- v2 spec: `docs/superpowers/specs/2026-09-06-really-v2-design.md`
- v3 (Screen Time) spec: `docs/superpowers/specs/2026-09-07-really-v3-screentime-design.md`
