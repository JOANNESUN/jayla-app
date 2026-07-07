//
//  Prediction.swift
//  Jayla
//
//  Value types returned by the prediction engine. Pure Foundation —
//  no SwiftData/SwiftUI — so the engine stays unit-testable from the
//  command line (see JaylaTests/).
//

import Foundation

/// How much to trust a prediction. Derived from the weighted coefficient
/// of variation of recent intervals — dimensionless, so it stays
/// comparable as the baby's rhythms stretch out with age.
nonisolated enum PredictionConfidence: String, Sendable {
    case learning
    case roughly
    case confident

    /// Short label for the tracker card's confidence line.
    var label: String {
        switch self {
        case .learning:  "Still learning"
        case .roughly:   "Rough guess"
        case .confident: "Confident"
        }
    }
}

/// A weighted estimate of an interval-shaped quantity that isn't a gap
/// between events — today: how long the current nap will run, from the
/// durations of recent completed naps. Same confidence semantics as
/// `Prediction`.
nonisolated struct IntervalEstimate: Equatable, Sendable {
    let expected: TimeInterval
    let confidence: PredictionConfidence
    /// Number of samples that informed the estimate (0 = pure prior).
    let sampleCount: Int
    /// 0 = entirely age-band prior, 1 = entirely learned from data.
    let priorBlend: Double
}

nonisolated struct Prediction: Equatable, Sendable {
    /// When the next occurrence is expected. May be in the past (e.g.
    /// after a late log) — display layers show "any time now", and the
    /// notification scheduler clamps to the future before scheduling.
    let nextTime: Date

    /// Expected gap between occurrences, after recency weighting and
    /// any prior blending.
    let expectedInterval: TimeInterval

    let confidence: PredictionConfidence

    /// Number of intervals that informed the estimate (0 = pure prior).
    let sampleCount: Int

    /// 0 = entirely age-band prior, 1 = entirely learned from data.
    let priorBlend: Double
}
