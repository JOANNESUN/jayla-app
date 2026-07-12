//
//  PredictionPriors.swift
//  Jayla
//
//  The thin adapter between the app's domain types and the pure engine:
//  per-activity tuning plus static pediatric-spacing priors keyed by age
//  band. Priors only matter for the first handful of logs — after
//  ~4 intervals the engine is fully data-driven.
//
//  This file is deliberately NOT compiled by the CLI test runner (it
//  references ActivityType/AgeBand); the engine itself stays pure.
//

import Foundation

nonisolated extension Prediction {

    /// Sleep readiness is a 15–30 minute biological window, not a
    /// moment — so sleep UI shows a range instead of a false-precision
    /// point. Width scales with confidence AND age: under ~4 months
    /// rhythms are inherently fuzzier, so young bands widen the window
    /// no matter how steady the data looks.
    func napWindow(ageBand: AgeBand) -> ClosedRange<Date> {
        let confidenceHalf: TimeInterval = switch confidence {
        case .confident: 10 * 60
        case .roughly:   15 * 60
        case .learning:  25 * 60
        }
        let agePad: TimeInterval = switch ageBand {
        case .newborn: 10 * 60
        case .infant:  5 * 60
        case .older:   0
        }
        let half = confidenceHalf + agePad
        return nextTime.addingTimeInterval(-half)...nextTime.addingTimeInterval(half)
    }
}

nonisolated extension ForecastEngine.Input {

    /// Builds the forecast's plain inputs from the same predictions the
    /// home screen shows — the forecast card is those numbers on a
    /// timeline, never a second opinion.
    /// `sleeps` are (start, duration) pairs; duration nil = open nap.
    static func build(feedTimestamps: [Date],
                      sleeps: [(start: Date, duration: TimeInterval?)],
                      ageBand: AgeBand,
                      now: Date) -> ForecastEngine.Input {
        let feed = PredictionEngine.predict(
            timestamps: feedTimestamps,
            now: now,
            config: .config(for: .feed, ageBand: ageBand))
        let sleep = PredictionEngine.predict(
            timestamps: sleeps.map(\.start),
            now: now,
            config: .config(for: .sleep, ageBand: ageBand))
        let napDuration = PredictionEngine.estimateInterval(
            samples: sleeps.compactMap { sleep in
                guard let duration = sleep.duration, duration > 0 else { return nil }
                return (duration, sleep.start.addingTimeInterval(duration))
            },
            now: now,
            config: .napDurationConfig(ageBand: ageBand))

        // Same open-nap rule as HomeView/ActivityRepository: nil
        // duration within the 16h runaway guard.
        let cutoff = now.addingTimeInterval(-16 * 3_600)
        let asleepSince = sleeps
            .filter { $0.duration == nil && $0.start > cutoff }
            .map(\.start).max()

        var input = ForecastEngine.Input(now: now)
        input.lastFeed = feedTimestamps.max()
        input.feedInterval = feed?.expectedInterval
        input.asleepSince = asleepSince
        if let napDuration { input.napDuration = napDuration.expected }
        input.nextNapStart = asleepSince == nil ? sleep?.nextTime : nil
        input.napInterval = sleep?.expectedInterval
        input.isLearning = (feed?.confidence ?? .learning) == .learning
            && (sleep?.confidence ?? .learning) == .learning
        return input
    }
}

nonisolated extension PredictionEngine.Config {

    private static let hour: TimeInterval = 3_600
    private static let day: TimeInterval = 86_400

    static func config(for type: ActivityType, ageBand: AgeBand) -> PredictionEngine.Config {
        var config = PredictionEngine.Config()
        config.prior = prior(for: type, ageBand: ageBand)

        switch type {
        case .feed:
            // Feeds shift fastest as she grows — short window, 18h half-life
            // so a 2h→4h stretch dominates the estimate within a day.
            config.maxEvents = 10
            config.maxWindow = 4 * day
            config.halfLife = 18 * hour
        case .sleep:
            // Interval between sleep starts; naps consolidate slowly.
            config.maxEvents = 10
            config.maxWindow = 5 * day
            config.halfLife = 2 * day
        case .poop:
            // Sparse and irregular — need a longer window to see a rhythm.
            config.maxEvents = 10
            config.maxWindow = 7 * day
            config.halfLife = 3 * day
        case .pee:
            config.maxEvents = 12
            config.maxWindow = 4 * day
            config.halfLife = 2 * day
        }
        return config
    }

    /// Tuning for predicting how long the current nap will run, from the
    /// durations of recent completed naps (fed to
    /// `PredictionEngine.estimateInterval`). Same window as sleep-start
    /// gaps — nap length consolidates on the same slow timescale.
    static func napDurationConfig(ageBand: AgeBand) -> PredictionEngine.Config {
        var config = PredictionEngine.Config()
        config.maxEvents = 10
        config.maxWindow = 5 * day
        config.halfLife = 2 * day
        config.prior = switch ageBand {
        case .newborn: 1.0 * hour
        case .infant:  1.25 * hour
        case .older:   1.5 * hour
        }
        return config
    }

    /// Typical spacing before we have data. Coarse on purpose — these
    /// seed the estimate, they don't need to be precise.
    private static func prior(for type: ActivityType, ageBand: AgeBand) -> TimeInterval {
        switch (type, ageBand) {
        case (.feed, .newborn): 2.5 * hour
        case (.feed, .infant):  3.0 * hour
        case (.feed, .older):   3.75 * hour

        case (.sleep, .newborn): 2.0 * hour
        case (.sleep, .infant):  2.5 * hour
        case (.sleep, .older):   3.0 * hour

        case (.poop, .newborn): 4 * hour
        case (.poop, .infant):  8 * hour
        case (.poop, .older):   16 * hour

        case (.pee, .newborn): 2.5 * hour
        case (.pee, .infant):  3.0 * hour
        case (.pee, .older):   3.5 * hour
        }
    }
}
