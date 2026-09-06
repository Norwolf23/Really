# Really? v2 — Design Spec

Date: 2026-09-06
Status: approved by Gustav (design review, same day)
Builds on: v1 spec `2026-09-06-really-design.md` and the v1 implementation (PR #1).

## What v2 adds

Onboarding, a global meanness level with a "gets meaner through the day"
toggle, a reason picked before Continue, richer history (log, reasons
breakdown, worst hour), a Settings tab, and an app icon. No login, no sync,
no Screen Time API, no paid packs.

## Decisions

| Topic | Decision |
|---|---|
| Onboarding | Six screens on first launch, replayable from Settings |
| Meanness | Global base level Mild / Mean / Brutal → tiers normal / annoyed / brutal |
| Escalation | Global toggle "Gets meaner through the day", default on; tier = max(base, day-count tier) when on, base when off |
| Reasons | Continue → sheet with 3-4 per-app preset reasons + Other (text); reason stored on the event; No stores none |
| History | Log grouped by day with app filter; reasons breakdown (7 days); worst hour |
| Settings tab | Third tab: Meanness, escalation toggle, Replay intro |
| Accounts | None. All data local |

## 1. Data model

New `Settings` (Codable), persisted as `settings.json` in the same Application
Support directory via `Store`:

```
struct Settings { var hasOnboarded = false; var meanness: Tier = .normal; var escalates = true }
```

`CheckIn` gains `var reason: String? = nil`. Optional, so v1 `events.json`
decodes unchanged (missing key → nil). No migration.

Pack JSON gains an optional top-level `"reasons": [String]` (3-4 lines, dry,
per-app flavoured). `pack-generic.json` carries the fallback list. Existing
question arrays are untouched (append-only rule still applies).

## 2. Tier rule

```
Logic.effectiveTier(base: Tier, openNumber: Int, annoyedAt: Int, brutalAt: Int, escalates: Bool) -> Tier
  escalates == false → base
  escalates == true  → max(base, tier(openNumber:annoyedAt:brutalAt:))
```

`AskView` uses this in place of `Logic.tier` directly. Per-app thresholds
remain in per-app settings.

## 3. Onboarding

Shown when `settings.hasOnboarded == false`, as a full-screen cover over the
root, black background, serif headings, one primary button per screen.

1. **Welcome** — "Really?" / "You open apps you don't mean to. This asks first."
2. **How it works** — three lines: an automation runs when the app opens;
   Really? asks; Continue after a pause, or No.
3. **The dig** — "You downloaded an app to stop using apps. Really?" / button: "Yes, really."
4. **Choose apps** — multi-select list of the catalog; selected entries are
   added to the Store via `Catalog.gatedApp`. At least one required to continue.
5. **Meanness** — three cards Mild / Mean / Brutal, each showing one sample
   question from the generic pack at that tier. Sets `settings.meanness`.
6. **Set up** — the existing `SetupView` content for the first chosen app,
   with a primary "Open Shortcuts" and a secondary "I'll do it later".

Finishing sets `hasOnboarded = true`. "Replay intro" in Settings resets it.
Copy: dry, no emoji, no exclamation marks.

## 4. Reason sheet

After the pause, Continue presents a bottom sheet (medium detent):
title "Why?" in serif; the app's reasons as full-width buttons; "Other" reveals
a single-line text field with a "Go" button (disabled while empty). Tapping a
reason: `store.record(.proceed, for:, questionID:, reason:)`, open the app's
URL, dismiss. Swiping the sheet away returns to the question screen with
Continue still enabled; nothing recorded. No is unchanged.

Default reasons (generic pack): "Checking one thing", "Bored", "Avoiding
something", "No reason". Per-app packs override with 3-4 flavoured lines.

## 5. Settings tab

Tab bar becomes Apps / Stats / Settings. Settings:

- Section Tone: Picker Meanness (Mild / Mean / Brutal); Toggle "Gets meaner
  through the day" with footer "Uses each app's Annoyed and Brutal thresholds."
- Section Intro: Button "Replay intro".
- Section About: version string.

## 6. Stats additions

- **Log**: `List` of events grouped by day (newest first), row = time
  (HH:mm), app name, "Went through" or "Said no", reason in secondary text.
  Toolbar menu filters by app (All + each app).
- **Reasons, last 7 days**: counts per reason over `.proceed` events, sorted
  descending, with a header line "Leading excuse: <top reason>" (omitted when
  there are none).
- **Worst hour**: the hour of day with the most `.proceed` events over all
  history, shown as "Most likely to cave: 23:00–00:00" (omitted when none).

Logic additions (pure, tested):

```
Logic.reasonCounts(events:, since:, now:) -> [(reason: String, count: Int)]   // proceed events with a reason, desc by count
Logic.worstHour(events:, calendar:) -> Int?                                   // hour 0-23 with most proceed events, nil if none
Logic.groupedByDay(events:, calendar:) -> [(day: Date, events: [CheckIn])]    // newest day first, events newest first
```

## 7. App icon

`Assets.xcassets/AppIcon.appiconset` with a single 1024×1024 PNG: black tile,
white serif "?" centred. Generated by a small Swift script committed as
`makeicon.swift` (same approach as Stayawake), so it can be regenerated.

## 8. Tests

- `effectiveTier`: escalates off returns base at any open number; on returns
  max; base brutal never lowers.
- `reasonCounts`: ignores No events and nil reasons; window boundary; ordering.
- `worstHour`: nil on empty; ties resolve to the earlier hour; ignores No events.
- `groupedByDay`: ordering and grouping across a day boundary.
- `CheckIn` v1 JSON (no `reason` key) decodes; `Settings` round-trips.
- Packs: every pack has 3-4 reasons or falls back to generic reasons.

## Out of scope

Login, cross-device sync, Screen Time API, paid packs, tone slider beyond the
three levels, widgets.
