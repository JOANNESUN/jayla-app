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
   `lastEvent + expected`, deliberately NOT clamped to the future — a
   clamped time slides forward on every re-render. Overdue predictions
   display as "any time now"; only the Rescheduler clamps
   (`max(…, now + 5min)`) before scheduling the alert.
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
- [x] **Phase 5 — UI/UX clarity pass.** One place per fact: the status
  card owns the next-feed prediction (bell icon = "will remind you";
  confidence caveat only while uncertain). Tracker cards are minimal —
  past fact only ("Fed 5 min ago", coarse human time, never ticking
  seconds) plus a button that just says "Log". Joanne's decision:
  predictions for sleep/poop/pee no longer shown on cards at all
  (engine still computes them; they return when there's an honest use,
  e.g. the nap nudge). *Redesign — "Today dashboard" (picked as 1a from
  Joanne's Claude Design exploration; reference colors/fonts from
  `Jayla Home (standalone).html`):* header = 84pt photo (the only
  tap-to-change-photo spot) + name + age, no menu/tab bar/edit (future
  updates); a countdown hero card owns the next-feed prediction — big
  "1h 5m" (Baloo 2), "around 2:30 PM · rough guess", a cycle progress
  bar (elapsed ÷ `expectedInterval`, full when overdue → smaller
  "any time now" + "expected around …"), and a "Fed 25 min ago /
  ~2h cycle" footer; below it a 2×2 quick-log grid — mascot badge,
  "+" log button (the only tap target; accidental whole-card logs are
  worse than a smaller target), name, time since. The countdown is the
  reward that compels logging. *Fonts:* Baloo 2 ExtraBold (display) +
  Nunito Bold/ExtraBold/Black (body), SIL OFL, bundled in
  `Jayla/Fonts/` and registered at runtime via CoreText (generated
  Info.plist stays untouched; previews work). Joanne's hand-drawn
  mascots (SVG image sets, vector data preserved) replace SF Symbols;
  baby-face app icon (`app-icon.svg` beside the mascot sources,
  rendered → flattened RGB PNG). *Accessibility:* custom fonts scale
  via `relativeTo`, badges on `@ScaledMetric`, grid collapses to one
  column at accessibility sizes, app capped at AX2; VoiceOver reads
  the hero as one sentence (spelled-out countdown + "Jayla will remind
  you") and "+" buttons announce their activity; pickers labeled.
  Deferred: sleep-duration UI (needs start/stop logging → Phase 6 nap
  work) and real dark mode (Blush is deliberately light-only).
- [x] **Sleep as a state — nap toggle, wake prediction, state-aware
  notifications** (branch `sleep-toggle-notifications`). Market research
  (Huckleberry SweetSpot, Napper, Nara, Baby Daybook) settled the design:
  predict sleep *onset* and notify with lead time while awake; never ping
  during a nap (wake estimate is display-only); backdating is table
  stakes. *Data:* a nap in progress is a `.sleep` event with
  `durationSeconds == nil`; "Wake up" fills the duration in. No schema
  change; a 16h guard keeps legacy instant-tap sleep rows (all nil
  duration) from reading as open, and only `durationSeconds > 0` rows
  feed duration stats. *Engine:* weighted core extracted as
  `estimateInterval(samples:)` so nap durations reuse the double
  window/recency/prior machinery; nap-duration priors ~1h–1.5h by age
  band. *Notifications:* `pending_nap` fires 15 min before the predicted
  nap start ("guideline, not a deadline" copy); `nap_check` is the
  runaway-nap guard at `max(2× predicted duration, 2.5h)` — a check-in
  no competitor ships (they all let a forgotten timer run; Nara's 24h
  red badge is the market's best). Exactly one of the two is pending,
  managed by `Rescheduler.rescheduleNap` (same choke-point pattern;
  DEBUG env `JAYLA_NAP_REMINDER_IN_SECONDS`). *UI:* the sleep card is a
  toggle — awake: "+" starts a nap instantly, subtitle shows the
  next-nap estimate; asleep: sun button ends it, "Asleep 42m", wake
  estimate, and a "since 2:40 · adjust" wheel to backdate a running
  start (clamped to the past). Sleep predictions live on the sleep card,
  not the hero — one place per fact.
  *Home redesign follow-up (Joanne's mockup, branch `ui-ux-design`):*
  feed and sleep are the two "live" activities, so each hero owns its
  facts, prediction AND action — the feed hero gained a full-width
  "+ Log feed" pill, and sleep became a second hero-style card
  (`Views/SleepCard.swift`): awake = "NEXT NAP" + bell + Start nap
  pill; asleep = blue-tinted card with a progress ring (elapsed ÷
  predicted duration, "~35m left"), wake estimate, adjust row, Wake up
  pill, and deliberately NO bell (display-only, no mid-nap pings). The
  quick-log grid is instants only (poop/pee); TrackerCard reverted to
  the simple type/subtitle/onLog tile. At accessibility sizes the ring
  stacks above the text (AnyLayout swap, same idea as the grid
  collapse).
  *Research-driven refinements:* nap prediction shows a **window**
  ("between 1:15 and 1:45"), half-width = confidence (10/15/25 min) +
  age pad (newborn +10, infant +5) — sleep readiness is a 15–30 min
  biological range, and next-nap timing beats wake-time prediction as
  the primary fact (wake windows + cortisol penalty; market unanimous:
  SweetSpot, Napper, Nanit all lead with nap onset). Under 4 months the
  awake card adds "her sleepy cues beat the clock at this age". On
  "Wake up" the card transforms in place into a **wake summary** for
  30 min — "slept 1h 12m", a short-nap flag under 45 min (one sleep
  cycle; experts shorten the next window after these), the updated
  next-nap window, and a one-tap "still asleep? undo" (reopens the
  nap). Never a modal — taps are the currency at 3am. Daily sleep
  totals deliberately deferred to the future **analysis tab** (history
  of feed/nap/pee/poop).
  *Poop/pee tiles (branch `pee-poop-daily-count`):* the tiles drop the
  "25 min ago" line for a big **daily count** — parents need how many
  times today, not when — with Joanne's kawaii poop/pee icons shown
  full-size. The count is computed against the timeline's `now`, so it
  rolls to 0 at midnight for free. Timestamps are still stored per
  event for the future analysis tab. Visual treatment iterated in-place
  on the branch (see its commits for the current styling).
- [x] **History page (branch `history-page`).** The analysis tab, iteration 1.
  Market research (Huckleberry's Day/Week/List/Summary sprawl, Nara's
  "data is an ongoing reference" study, classic infant actograms)
  converged on ONE page answering the three questions parents bring to
  history: *is a rhythm forming* → a 24h day-column **pattern chart**
  (sleep as ribbons, feeds as dots, pee/poop daily counts under each
  column, 30 days, opens scrolled to today); *what exactly happened* →
  tap a column for that day's chronological event list (swipe-to-delete
  = the correction surface; deleting a feed/sleep goes through the
  Rescheduler choke point like logging one); *how much / how many* →
  the day totals row (daily sleep total lands here as promised; wet
  diapers per day is the number pediatricians ask for). Sleeps are
  split at midnight (`DayLog.swift`, pure Foundation — every minute
  lands on the day it was slept; `./JaylaTests/run-daylog.sh`). The
  open nap draws as a growing gradient ribbon, counted live. Navigation
  is a minimal 2-tab TabView (Today / History) in ContentView. Shared
  time strings extracted to `Utilities/Formatters.swift`. Deferred to
  iteration 2: scroll-back past 30 days, editing times from history,
  stats/insights.
- [ ] **Phase 6 — Pattern-shift flagging & engine polish.** Change-point
  check (recent ~3 intervals vs the prior window; a consistent >~25%
  shift temporarily shortens the half-life and surfaces a hint like
  "feeds are spacing out"), MAD outlier clamp, permission promotion.
  Candidates from the notification-philosophy analysis: stale-reminder
  content ("it's been a while since the last logged feed"), silent
  response-lag recording (measure-first), and later a daytime
  nap-window nudge (requires sleep start/stop logging — see the sleep
  discussion in *Notification philosophy*) — re-read that section
  before building any of these.

## Verification

- **Engine:** `./JaylaTests/run.sh` — synthetic timestamp arrays covering
  steady rhythm → confident; lengthening intervals → tracks, doesn't lag;
  window exclusion; cold-start blend; late-log clamp; erratic data → low
  confidence. Runs with `swiftc` alone, no simulator.
- **App:** build with `xcodebuild -scheme Jayla -destination
  'platform=macOS' build` for a fast type-check, or against
  `'generic/platform=iOS Simulator'` now that the dev Mac has iOS
  simulator runtimes (iPhone 17 family, Xcode 26); run for real from
  Xcode on a simulator or iPhone — see `RUNNING.md`. Flows can be
  verified headlessly by seeding the SwiftData sqlite store with
  `sqlite3` (Core Data epoch = unix − 978307200) and reading the DEBUG
  console prints.
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
