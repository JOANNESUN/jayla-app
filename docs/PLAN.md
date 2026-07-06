# Jayla — Architecture & Build Plan

This is the living design doc: what the app does, how it's built, and the
phased plan to finish it. Update the status checkboxes as phases land.

## Vision

Mom logs a baby activity with **one tap**. After enough logs the app
**predicts the next occurrence** with an honest confidence level, and
**adapts as the baby grows** — feed spacing that stretches from 2h to 4h must
pull the prediction along with it, never regress to stale newborn rhythms.
At the predicted feed time a **local notification** fires; long-pressing it
exposes a **"Log feed"** action that records the event in the background
without opening the app. Every log — tap or notification — recomputes the
prediction and reschedules the next alert. One closed loop; accuracy
compounds with use.

**Locked decisions**

- Local-only storage (no iCloud/CloudKit for now)
- Simple, *explainable* prediction engine — no ML black box
- Actively flag pattern shifts (sleep/feed regressions), don't just adapt silently
- Single profile photo, replaced by tapping the hero/avatar
- "Blush" color theme (`Theme.swift`) sampled from a terracotta street painting

## The core loop

Two entry points — an in-app tap and (from Phase 4) a notification action —
funnel into the *same* write path, then one choke point recomputes and
reschedules:

```
tap OR notification-action
  → log event                       persist to SwiftData
  → PredictionEngine.predict(...)   recency-weighted next-time + confidence
  → NotificationScheduler           cancel + schedule the one pending feed alert
  → (alert fires) → notification-action → loop
```

`BabyProfile.birthdate → ageBand` feeds the engine as a cold-start prior.

## Data model (`Jayla/Models/`)

- **`ActivityType`** — `feed / sleep / poop / pee`, `String`-backed enum.
  Display concerns (SF Symbol, badge/ink colors, labels) live here as
  computed properties over `Theme`.
- **`ActivityEvent`** (`@Model`) — `typeRaw: String` (stored raw so it's
  `#Predicate`-queryable), `timestamp`, `durationSeconds: Double?` (sleep
  only), `source` (`"app"` / `"notification"` — idempotency in Phase 4),
  `createdAt`, `id: UUID`.
- **`BabyProfile`** (`@Model`) — `name`, `birthdate`, optional
  `photoData` (`.externalStorage`). **Age is always derived, never stored**
  (`ageInDays`, `ageDescription`, coarse `ageBand`).

Every prediction query fetches only a recent window (`fetchLimit`), never
full history — the query-layer half of the anti-regression story.

## Prediction engine (`Jayla/Prediction/` — pure, CLI-testable)

`PredictionEngine.predict(timestamps:now:config:) -> Prediction?` — takes
plain `[Date]`, returns a value type. **No SwiftData or SwiftUI imports**, so
it compiles and tests from the terminal (`./JaylaTests/run.sh`).

How a prediction is computed:

1. **Intervals** = gaps between consecutive same-type events.
2. **Double sliding window** — an interval counts only if it's within BOTH
   the last `maxEvents` events *and* the last `maxWindow` of wall time
   (feeds: 10 events / 4 days). This is *the* mechanism that prevents
   regression: old short intervals age out entirely.
3. **Exponential recency weighting** — within the window, an interval's
   weight halves every `halfLife` (feeds: 18h), so a growth shift dominates
   the estimate within about a day.
4. **Expected interval** = weighted mean; **next time** =
   `lastEvent + expected`, clamped to `max(…, now + 5min grace)` so a late
   log never yields a time already in the past.
5. **Confidence** = weighted coefficient of variation (dimensionless, so
   comparable across ages): CV < 0.25 → `confident`, < 0.5 → `roughly`,
   else `learning`. Fewer than 3 intervals, or a still-blended prior, caps
   confidence.
6. **Cold start** — 0 events → no prediction (UI prompts to log);
   1 event → age-band prior; then a linear blend prior→learned over the
   first 4 intervals.

`PredictionPriors.swift` is the thin adapter from app types to engine
config: per-activity window/half-life tuning plus the static
pediatric-spacing priors by `AgeBand` (e.g. feeds: newborn 2.5h → infant
3h → 4+ months 3.75h). Priors are deliberately coarse — they only seed the
estimate until real data takes over.

The regression guard is enforced by test: a week of 2h feeds followed by a
day of 4h feeds must predict > 3.5h.

## Notification philosophy

The baby is already a perfect notification system: crying has a 0% miss
rate — but it's a **lagging** indicator (the need exists, the baby is
distressed, everyone's awake). The prediction is a **leading** indicator.
The app's notification is only valuable in the gap between the two:
**when acting early beats reacting to crying, and mom's attention is
elsewhere**. One line: *Jayla tells you what's coming so the crying
doesn't have to.*

Per activity, that gap is:

- **Feed** — the only activity actionable in advance around the clock.
  Daytime: catch the missed early hunger cues → feed a calm baby
  ("prevent the cry"). Night: wake-to-feed / dream-feed schedules are a
  *deliberate parenting choice*, not a default → opt-in only.
- **Sleep** — strong daytime case (the "awake window": putting her down
  before overtired prevents the worst meltdowns) → candidate for a
  future nap-window nudge, daytime only. Never at night.
- **Poop / pee** — you can't pre-empt a poop; a predicted diaper is
  never worth waking anyone. In-app info lines only, **never**
  notifications.

Consequences:

- **Feed-only notifications** is a philosophy decision, not a Phase 3
  shortcut. Don't add other notification types without re-reading this.
- **Night policy is delegated to iOS, with zero settings UI**: because
  the app lacks the time-sensitive entitlement, Sleep Focus silences
  reminders by default ("the baby will wake you"); a parent who wants
  the 3am dream-feed alarm allows Jayla in their Sleep Focus — opt-in
  alarm clock, configured in iOS Settings, not in our app.
- From LinkedIn's ATC playbook (researched Jul 2026), we keep the
  principles that transfer — one pending reminder, quiet-first auth,
  actionable notifications — and explicitly **reject back-off on
  ignored reminders**: LinkedIn drops marketing; ours is an alarm the
  user asked for, and going silent when mom is merely busy is the worst
  failure mode. If reminders go unanswered, adapt the *content* ("it's
  been a while since the last logged feed"), never skip.
- A **response feedback loop** (calibrate predictions from how fast mom
  reacts to reminders) is measure-first: record response lags invisibly
  once Phase 4 generates them, evaluate after weeks of real use, and
  only then build calibration — damped and capped (±20 min) — the
  signal is noisy and partially double-counts what interval learning
  already adapts to.

## Notifications (Phases 3–4, `Notifications/` + `App/`)

- **`AppDelegate`** via `@UIApplicationDelegateAdaptor`; notification
  delegate + categories registered in `didFinishLaunching` (must be live for
  a cold launch from an action — never in a view's `.onAppear`).
- **Provisional authorization** first (quiet delivery, no permission wall);
  promote to prominent alerts on an explicit user affordance later.
- Category `FEED_REMINDER` with a `LOG_FEED` action declared **without**
  `.foreground` (so it logs in the background) plus `SNOOZE_15`.
  `interruptionLevel` is `.active` for now — `.timeSensitive` (pierces
  Focus) needs an entitlement that personal/free dev teams cannot
  provision; revisit on a paid Apple Developer account.
- **One pending feed notification**, stable id `"pending_feed"` —
  reschedule = cancel + re-add, inherently idempotent.
- **Background write:** the action handler must NOT touch the UI's
  main-actor `ModelContext`. It constructs a `@ModelActor BackgroundLogger`
  from the shared `ModelContainer` (containers are `Sendable`, contexts are
  not), logs, recomputes, reschedules, updates the badge.
- **Idempotency:** before a background insert, skip if a same-type
  `source == "notification"` event exists within ~2 minutes.
- **Permission denied?** The app stays a fully functional manual tracker —
  in-app predictions and countdown still work; only the push is lost.

## Build phases

Each phase is independently shippable.

- [x] **Phase 1 — Persistence & logging.** SwiftData models, shared
  container, `ActivityRepository`, four tap-to-log tracker cards, derived
  age. *Plus:* first-run onboarding (name/birthday/photo) and
  tap-to-replace profile photo.
- [x] **Phase 2 — Prediction engine.** Pure engine (double window + recency
  weighting + CV confidence + age-band priors), CLI unit tests, HomeView
  wiring: next-feed countdown in the status card, prediction + confidence
  line on every tracker card, refreshed each minute via `TimelineView`.
- [x] **Phase 3 — Notifications, foreground path.** Scheduler,
  categories/actions, provisional auth, AppDelegate, schedule-on-log via
  the `Rescheduler` choke point, badge clear on foreground. Debug hook:
  `JAYLA_REMINDER_IN_SECONDS` env var schedules a fast test reminder.
  (Time-sensitive entitlement was dropped: personal dev teams can't
  provision it — Apple rejects the profile. Re-add on a paid account.)
- [x] **Phase 4 — Background action logging.** `@ModelActor
  BackgroundLogger` owns the background write path (idempotency guard:
  skip if a notification-sourced feed exists within 2 min); `didReceive`
  routes LOG_FEED → log + reschedule and SNOOZE_15 → re-ask in 15 min
  (baby name rides in `userInfo`, no DB access); Rescheduler refactored
  into a plain-value core shared by both entry points; scheduler /
  categories / prediction types marked `nonisolated` (the project's
  default-MainActor isolation would otherwise fight the background path).
- [ ] **Phase 5 — Pattern-shift flagging & polish.** Change-point check
  (recent ~3 intervals vs the prior window; a consistent >~25% shift
  temporarily shortens the half-life and surfaces a hint like "feeds are
  spacing out"), MAD outlier clamp, permission promotion, undo-last-log.
  Candidates from the notification-philosophy analysis: stale-reminder
  content ("it's been a while since the last logged feed"), silent
  response-lag recording (measure-first), and later a daytime
  nap-window nudge — see *Notification philosophy* above before
  building any of these.

## Verification

- **Engine:** `./JaylaTests/run.sh` — synthetic timestamp arrays covering
  steady rhythm → confident; lengthening intervals → tracks, doesn't lag;
  window exclusion; cold-start blend; late-log clamp; erratic data → low
  confidence. Runs with `swiftc` alone, no simulator.
- **App:** build with `xcodebuild -scheme Jayla -destination
  'platform=macOS' build` for a fast type-check (the dev Mac has no iOS
  simulator runtimes); run for real from Xcode on a simulator or iPhone —
  see `RUNNING.md`.
- **Notifications (3–4):** short debug intervals; verify long-press shows
  `Log feed`/`Snooze`; tapping `Log feed` with the app killed creates
  exactly one event and reschedules; test denied-permission degradation and
  rapid double-tap → one event.

## Known pitfalls (guard from the start)

- Never share a `ModelContext` across actors — share the `ModelContainer`.
- Register the notification delegate in `didFinishLaunching`, not `.onAppear`.
- Xcode 16+ synchronized folder: files added under `Jayla/` join the target
  automatically — but `JaylaTests/` lives *outside* that folder on purpose
  (it must not compile into the app).
- Schema changes during development: SwiftData auto-migrates additive
  optional fields; if the store errors on launch, delete the app to reset
  (see `RUNNING.md`).
