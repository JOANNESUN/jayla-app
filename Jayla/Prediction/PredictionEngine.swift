//
//  PredictionEngine.swift
//  Jayla
//
//  The anti-regression core. Takes raw same-type timestamps, returns a
//  Prediction. Pure Foundation, no persistence imports — callable from
//  SwiftUI, a background notification handler, or a CLI test alike.
//
//  Two mechanisms keep the estimate tracking the baby as she grows
//  instead of regressing to stale newborn rhythms:
//
//  1. Double sliding window — an interval only counts if it falls inside
//     BOTH the last `maxEvents` events and the last `maxWindow` of wall
//     time. As feed spacing stretches 2h→4h, the old short intervals age
//     out entirely rather than dragging the mean down.
//  2. Exponential recency weighting — within the window, newer intervals
//     dominate (half-life ~1 day for feeds), so a shift propagates into
//     the estimate within about one half-life.
//

import Foundation

nonisolated enum PredictionEngine {

    /// Per-activity tuning. Defaults suit feeds; `PredictionPriors`
    /// builds variants for each (activity, age band) pair.
    struct Config: Sendable {
        /// Event-count half of the double window.
        var maxEvents: Int = 10
        /// Wall-time half of the double window.
        var maxWindow: TimeInterval = 4 * 86_400
        /// Recency-weight half-life: an interval this old counts half
        /// as much as one that just ended. Short enough that a growth
        /// shift dominates the estimate within about a day.
        var halfLife: TimeInterval = 18 * 3_600
        /// Predictions are clamped to at least `now + grace` so logging
        /// late never yields a time that is already in the past.
        var grace: TimeInterval = 5 * 60
        /// Age-band prior interval used before enough data exists.
        /// nil → predictions require at least 2 events.
        var prior: TimeInterval?
        /// Intervals needed before the estimate is fully learned; below
        /// this, the prior is blended in on a linear ramp.
        var learnedRampIntervals: Int = 4
    }

    private static let ln2 = log(2.0)

    /// - Parameters:
    ///   - timestamps: same-type event times, any order, any count.
    ///   - now: injected clock (tests pass fixed dates).
    /// - Returns: nil when there is nothing to anchor a prediction to
    ///   (no events at all, or a single event with no prior).
    static func predict(timestamps: [Date],
                        now: Date,
                        config: Config) -> Prediction? {
        let sorted = timestamps.sorted()
        guard let last = sorted.last else { return nil }

        // Double sliding window: recent in wall time AND in event count.
        let cutoff = now.addingTimeInterval(-config.maxWindow)
        let windowed = Array(sorted.filter { $0 >= cutoff }.suffix(config.maxEvents))

        // Intervals between consecutive events, weighted by how recently
        // each interval ended.
        var intervals: [(value: TimeInterval, weight: Double)] = []
        for (earlier, later) in zip(windowed, windowed.dropFirst()) {
            let gap = later.timeIntervalSince(earlier)
            guard gap > 0 else { continue }
            let age = max(0, now.timeIntervalSince(later))
            intervals.append((gap, exp(-age / config.halfLife * Self.ln2)))
        }

        let n = intervals.count
        guard n > 0 || config.prior != nil else { return nil }

        // Weighted mean of the windowed intervals (nil when no data).
        var learned: TimeInterval?
        var cv = 0.0
        if n > 0 {
            let totalWeight = intervals.reduce(0) { $0 + $1.weight }
            let mean = intervals.reduce(0) { $0 + $1.value * $1.weight } / totalWeight
            let variance = intervals.reduce(0) {
                $0 + $1.weight * ($1.value - mean) * ($1.value - mean)
            } / totalWeight
            learned = mean
            cv = mean > 0 ? sqrt(variance) / mean : 0
        }

        // Cold-start ramp: 0 intervals → pure prior, `learnedRampIntervals`
        // or more → pure data, linear blend in between.
        let blend = min(1.0, Double(n) / Double(config.learnedRampIntervals))
        let expected: TimeInterval
        switch (learned, config.prior) {
        case let (mean?, prior?): expected = blend * mean + (1 - blend) * prior
        case let (mean?, nil):    expected = mean
        case let (nil, prior?):   expected = prior
        case (nil, nil):          return nil
        }

        let confidence: PredictionConfidence
        if n < 3 {
            confidence = .learning
        } else if cv < 0.25 {
            // Steady rhythm — but stay modest while the prior still has a say.
            confidence = blend < 1 ? .roughly : .confident
        } else if cv < 0.5 {
            confidence = .roughly
        } else {
            confidence = .learning
        }

        let next = max(last.addingTimeInterval(expected),
                       now.addingTimeInterval(config.grace))
        return Prediction(nextTime: next,
                          expectedInterval: expected,
                          confidence: confidence,
                          sampleCount: n,
                          priorBlend: blend)
    }
}
