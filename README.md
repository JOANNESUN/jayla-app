# Jayla 🍼

A predictive baby tracker for iOS. One tap logs a **feed, sleep, poop, or pee**;
the app learns the baby's rhythm and predicts when the next one is due — and
keeps adapting as she grows, never regressing to stale newborn patterns.
Eventually, a local notification fires at the predicted feed time and a
long-press **"Log feed"** action records it without even opening the app.

Built by Joanne for her daughter Jayla. 🩷

## Tech

- **SwiftUI + SwiftData**, iOS 26.5+, no third-party dependencies
- **Local-only storage** — no accounts, no cloud, no network
- Custom **"Blush"** theme (`Jayla/Theme.swift`), sampled from a terracotta
  street painting

## The core loop

```
tap in app  OR  notification action
      → log event (SwiftData)
      → PredictionEngine → next time + confidence
      → (Phase 3+) reschedule the feed notification
      → alert fires → long-press "Log feed" → loop
```

## Repo layout

| Path | What it is |
| --- | --- |
| `Jayla/Models/` | SwiftData models: `ActivityEvent`, `BabyProfile`, `ActivityType` |
| `Jayla/Data/` | `ActivityRepository` — the app's single write/read path |
| `Jayla/Prediction/` | The prediction engine. **Pure Swift, no UI/DB imports** |
| `Jayla/Views/` | `HomeView` (dashboard), `OnboardingView` (first run) |
| `Jayla/App/` | Shared `ModelContainer` setup |
| `JaylaTests/` | CLI unit tests for the engine — `./JaylaTests/run.sh`, no simulator needed |
| `docs/PLAN.md` | **Architecture & phased build plan — start here** |
| `RUNNING.md` | How to run on simulator / a physical iPhone, and reset app data |

## Getting started

1. `open Jayla.xcodeproj`
2. Pick an iPhone simulator (or your phone — see [RUNNING.md](RUNNING.md)) and ⌘R
3. Run the engine tests any time with `./JaylaTests/run.sh`

To understand *why* the code is shaped the way it is, read
[docs/PLAN.md](docs/PLAN.md) — it documents the architecture, the prediction
math, and which build phase we're up to.
