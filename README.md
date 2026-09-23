# Really?

A dry, sarcastic question in front of an app you open too much.

## Support

Open an issue on this repo. Nothing in the app is sent off the phone.

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
One app is free. A second app, Full Block, and custom lines are Pro.

## How it works

Three app extensions share one App Group with the app:

- `ShieldConfig` shows a one-button reminder for the first 4-5 opens of an app each day, then picks the tier (Mild/Mean/Brutal, escalating with today's opens) and a line from the app's pack, and draws the shield.
- `ShieldAction` handles the buttons: logs the answer, lifts the shield and schedules the cooldown.
- `Monitor` puts the shield back when the cooldown ends.

Starter-pack lines are append-only: editing or reordering a pack shifts the "don't repeat the last line" bookkeeping.

## Pro

One app and the question shield are free. Pro adds every other app, Full Block, custom lines, and the reason log.

- `studio.nickson.really.pro.yearly` — $29.99 a year
- `studio.nickson.really.pro.monthly` — $5.99 a month

Both include a 7-day free trial. Match that introductory offer in App Store Connect. The Really scheme uses `Really.storekit` so Xcode can complete a purchase without the store.

If Pro ends, one app keeps the questions. Full Block stays until the next midnight, then stops.

## Shipping to the App Store

The Family Controls *development* entitlement works for Xcode installs. Distribution needs Apple's
approval, requested per bundle id: `studio.nickson.really`, `.shield-config`, `.shield-action`, `.monitor`.

## Design docs

- v1 spec: `docs/superpowers/specs/2026-09-06-really-design.md`
- v2 spec: `docs/superpowers/specs/2026-09-06-really-v2-design.md`
- v3 (Screen Time) spec: `docs/superpowers/specs/2026-09-07-really-v3-screentime-design.md`
