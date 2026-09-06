# Really? — Design Spec

Date: 2026-09-06
Status: approved by Gustav (interview + design review, same day)

## What it is

An iPhone app that puts a dry, sarcastic question in front of you when you
open a distracting app. "Are you here to just doomscroll again?" Continue lets
you through after a short pause. No keeps you out. Personal tool first, App
Store product later; starter question packs per app are the eventual thing to
sell.

## Decisions from the interview

| Topic | Decision |
|---|---|
| Platform | iPhone only, iOS 17+ |
| Audience | Personal first, built to be excellent; App Store later |
| Questions | Starter pack per app (bundled) or user-written; show one fixed or rotate randomly |
| Buttons | Continue disabled for a configurable pause, then opens the app; No stays in Really? |
| Cooldown | After Continue, no re-ask for a configurable window per app |
| Stats | Full history, streaks, weekly chart, estimated time saved, escalating tone by opens today |
| Tone | Dry and sarcastic. No spice slider yet |
| Interception | Shortcuts automation + App Intent now; Screen Time API later |

## 1. Project and stack

- Native SwiftUI, iOS 17.0 minimum (automations run without confirmation).
- Path: `~/Projects/Really`. Xcode project generated with xcodegen (same as Stayawake / ShutOff).
- Bundle id `studio.nickson.really`, team 6272CRNH9G.
- No backend, no accounts, no analytics. All data local.
- Persistence: Codable JSON files in Application Support, one file for settings,
  one append-only file for check-in events. Contained in a single `Store` type
  so SwiftData can replace it later.
- App Intents run in the app process, so the intent and the UI share the same
  `Store`. Writes go through one actor to avoid races.

## 2. Interception flow

Really? cannot observe other apps launching. It ships an App Intent, **Check In**,
with one parameter: the gated app. The user creates one Personal Automation in
Shortcuts per gated app:

> When *Instagram* is opened → Run immediately, notify off → Run "Check In" (Instagram)

Intent behaviour:

1. Look up the app's cooldown end time in `Store`.
2. Inside cooldown: return silently. The user is already in the app.
3. Outside cooldown: open Really? via `really://ask?app=<id>` on the question screen.

Question screen behaviour:

- **Continue**: disabled until the pause finishes. Then: log a `continue` event,
  set cooldown end = now + cooldown minutes, open the app's URL scheme. The
  automation fires again on that open, hits the cooldown, and stays silent.
- **No**: log a `no` event, show the Good Call screen (today's tally, streak,
  a one-line sarcastic acknowledgement). iOS cannot send the user to the home
  screen, so this is the terminal state.

App catalog (bundled JSON): id, display name, URL scheme, default average
session minutes. Initial entries: Instagram `instagram://`, TikTok `tiktok://`,
YouTube `youtube://`, X `twitter://`, Reddit `reddit://`, Snapchat `snapchat://`,
Facebook `fb://`, Threads `barcelona://`. Plus **Custom**: user types name and
scheme.

Setup screen per app: numbered steps to create the automation, exact option
names, and an "Open Shortcuts" button (`shortcuts://`). Really? cannot verify the
automation exists; the setup screen shows "last check-in: never / <time>" so the
user can confirm it fired.

Interception seam: the question screen receives an `AppTarget` and a
`letThrough: () -> Void` action. Today that action opens a URL. The Screen Time
version later passes an unshield action instead. Nothing else changes.

## 3. The question screen

- Near-black background, one large question in a sharp serif, high contrast.
- A thin ring that breathes and counts the pause down. Continue is greyed with
  the remaining seconds until the ring closes.
- No is always tappable.
- Question selection: per app, source = `starterPack` or `custom`; mode =
  `single` (a chosen question id) or `rotate` (random from the tier, avoiding the
  last shown).
- Tiers: `normal`, `annoyed`, `brutal`. The tier for a check-in is chosen from
  the app's open count today (count of check-ins, any decision) against
  per-app thresholds, default: annoyed at 3, brutal at 6.
- Starter packs: bundled JSON, one file per app, roughly ten questions per tier,
  dry and sarcastic. Custom questions carry a tier the user picks (default
  normal). This file layout is the seam for paid packs later.

## 4. History and streaks

Event: `{ id, appId, at, decision: continue | no }`. Append-only.

Stats tab:

- Today: check-ins, Continue count, No count, across all apps.
- Per app: same counts, plus the current cooldown state.
- Weekly chart (Swift Charts): stacked bars per day, Continue vs No, last 7 days.
- Time saved: sum over No events of that app's average session minutes
  (editable per app, defaults from the catalog). Labelled as an estimate.
- Streak: consecutive calendar days, ending today or yesterday, with at least
  one No event. Shown on Stats and on the Good Call screen.

## 5. Settings

Per app: enabled, question source, single or rotate, chosen question (single
mode), pause seconds (default 5), cooldown minutes (default 15), escalation
thresholds (default 3 / 6), average session minutes, custom question list
(add, edit, delete, tier).

Global: none for now. Tone is fixed.

## 6. Screens

1. **Apps** (home): list of gated apps with today's counts; add app; tap for
   settings; setup badge if never checked in.
2. **Setup**: per-app automation instructions.
3. **App settings**: section 5 above.
4. **Ask**: the question screen (section 3). Opened only by URL.
5. **Good Call**: post-No screen.
6. **Stats**: section 4.

Tab bar: Apps, Stats.

## 7. Tests

Unit tests, no UI tests:

- Cooldown: inside/outside window, boundary, per-app isolation.
- Question selection: source, single vs rotate, tier from thresholds, no
  immediate repeat in rotate mode.
- Streak: today-only, yesterday-ending, broken chain, empty history.
- Time saved: sums per-app minutes over No events only.

Manual on-device: create one automation for Instagram, verify silent
re-fire after Continue, verify No path.

## Out of scope for this build

Screen Time API, paid packs, tone slider, iCloud sync, widgets, Mac/Android.
