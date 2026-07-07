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
