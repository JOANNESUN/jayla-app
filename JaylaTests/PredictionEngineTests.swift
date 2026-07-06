//
//  PredictionEngineTests.swift
//  JaylaTests
//
//  CLI tests for the pure prediction engine — no XCTest, no simulator.
//  Run with:  ./JaylaTests/run.sh
//
//  Compiled together with Jayla/Prediction/Prediction.swift and
//  PredictionEngine.swift only (the pure files). Exits non-zero on the
//  first summary if any expectation failed.
//

import Foundation

// MARK: - Tiny harness

var failures = 0
var checks = 0

func expect(_ condition: Bool, _ message: String,
            file: String = #file, line: Int = #line) {
    checks += 1
    if !condition {
        failures += 1
        print("  ✗ FAIL: \(message)  (\((file as NSString).lastPathComponent):\(line))")
    }
}

func expectNear(_ value: Double, _ target: Double, tolerance: Double,
                _ message: String, line: Int = #line) {
    expect(abs(value - target) <= tolerance,
           "\(message) — got \(value), wanted \(target) ± \(tolerance)", line: line)
}

func test(_ name: String, _ body: () -> Void) {
    print("• \(name)")
    body()
}

// MARK: - Fixtures

let hour: TimeInterval = 3_600
let t0 = Date(timeIntervalSince1970: 1_750_000_000) // fixed anchor

/// Events ending at `end`, spaced by the given gaps walking backwards.
/// gaps [3h, 3h] → [end-6h, end-3h, end].
func series(endingAt end: Date, gaps: [TimeInterval]) -> [Date] {
    var times = [end]
    var cursor = end
    for gap in gaps.reversed() {
        cursor = cursor.addingTimeInterval(-gap)
        times.insert(cursor, at: 0)
    }
    return times
}

// Mirrors the production feed tuning in PredictionPriors.swift.
let feedConfig: PredictionEngine.Config = {
    var c = PredictionEngine.Config()
    c.maxEvents = 10
    c.maxWindow = 4 * 86_400
    c.halfLife = 18 * hour
    c.prior = 3 * hour
    return c
}()

// MARK: - Tests

@main
struct PredictionEngineTests {
    static func main() {

test("no events → no prediction, even with a prior") {
    let p = PredictionEngine.predict(timestamps: [], now: t0, config: feedConfig)
    expect(p == nil, "expected nil with zero events")
}

test("single event → pure age-band prior, still learning") {
    let last = t0.addingTimeInterval(-1 * hour)
    let p = PredictionEngine.predict(timestamps: [last], now: t0, config: feedConfig)!
    expectNear(p.expectedInterval, 3 * hour, tolerance: 1, "interval should equal the prior")
    expect(p.priorBlend == 0, "blend should be 0 (all prior), got \(p.priorBlend)")
    expect(p.confidence == .learning, "confidence should be learning, got \(p.confidence)")
    expectNear(p.nextTime.timeIntervalSince(last), 3 * hour, tolerance: 1,
               "next = last + prior")
}

test("single event without a prior → no prediction") {
    var c = feedConfig
    c.prior = nil
    let p = PredictionEngine.predict(timestamps: [t0.addingTimeInterval(-hour)],
                                     now: t0, config: c)
    expect(p == nil, "one event and no prior cannot anchor a prediction")
}

test("steady rhythm → learned interval, confident") {
    // 8 feeds exactly 3h apart, last one just now.
    let times = series(endingAt: t0, gaps: Array(repeating: 3 * hour, count: 7))
    var c = feedConfig
    c.prior = 4 * hour // wrong prior on purpose — data must win
    let p = PredictionEngine.predict(timestamps: times, now: t0, config: c)!
    expectNear(p.expectedInterval, 3 * hour, tolerance: 60,
               "steady 3h rhythm should predict ~3h despite a 4h prior")
    expect(p.priorBlend == 1, "7 intervals → fully learned, got \(p.priorBlend)")
    expect(p.confidence == .confident, "zero variance → confident, got \(p.confidence)")
    expectNear(p.nextTime.timeIntervalSince(t0), 3 * hour, tolerance: 60,
               "next feed 3h from last")
}

test("cold-start ramp: 3 events blend prior toward data") {
    // Two 2h intervals, prior 4h → blended estimate strictly between.
    let times = series(endingAt: t0, gaps: [2 * hour, 2 * hour])
    var c = feedConfig
    c.prior = 4 * hour
    let p = PredictionEngine.predict(timestamps: times, now: t0, config: c)!
    expect(p.expectedInterval > 2 * hour + 60 && p.expectedInterval < 4 * hour - 60,
           "blend should land between data (2h) and prior (4h), got \(p.expectedInterval / hour)h")
    expectNear(p.priorBlend, 0.5, tolerance: 0.01, "2 of 4 ramp intervals → blend 0.5")
    expect(p.confidence == .learning, "n=2 intervals → still learning")
}

test("fifth log → fully learned, prior has no influence left") {
    // 5 events = 4 intervals = the full cold-start ramp.
    let times = series(endingAt: t0, gaps: Array(repeating: 2 * hour, count: 4))
    var c = feedConfig
    c.prior = 4 * hour // must be ignored once fully learned
    let p = PredictionEngine.predict(timestamps: times, now: t0, config: c)!
    expect(p.priorBlend == 1, "4 intervals → blend 1.0, got \(p.priorBlend)")
    expectNear(p.expectedInterval, 2 * hour, tolerance: 60,
               "estimate should be pure data (2h), untouched by the 4h prior")
}

test("growth tracking: lengthening intervals do not lag (regression guard)") {
    // A week of 2h feeds, then the last day stretches to 4h.
    // The engine must track toward 4h, not average back to ~2h.
    var gaps = Array(repeating: 2 * hour, count: 60)   // old newborn rhythm
    gaps += Array(repeating: 4 * hour, count: 6)       // last 24h, grown up
    let times = series(endingAt: t0, gaps: gaps)
    let p = PredictionEngine.predict(timestamps: times, now: t0, config: feedConfig)!
    expect(p.expectedInterval > 3.5 * hour,
           "estimate must track the new 4h spacing, got \(p.expectedInterval / hour)h")
}

test("double window: events older than maxWindow are ignored entirely") {
    // Dense 2h feeds 10 days ago (outside the 4-day window), then a
    // sparse recent 4h rhythm. Old data must have zero pull.
    let oldEnd = t0.addingTimeInterval(-10 * 86_400)
    let old = series(endingAt: oldEnd, gaps: Array(repeating: 2 * hour, count: 8))
    let recent = series(endingAt: t0, gaps: Array(repeating: 4 * hour, count: 5))
    let p = PredictionEngine.predict(timestamps: old + recent, now: t0, config: feedConfig)!
    expectNear(p.expectedInterval, 4 * hour, tolerance: 5 * 60,
               "only the recent 4h rhythm should count")
}

test("erratic intervals → low confidence") {
    let times = series(endingAt: t0, gaps: [1 * hour, 5 * hour, 1.5 * hour, 6 * hour, 1 * hour])
    let p = PredictionEngine.predict(timestamps: times, now: t0, config: feedConfig)!
    expect(p.confidence != .confident,
           "wildly varying gaps must not be confident, got \(p.confidence)")
}

test("late log clamp: prediction is never in the past") {
    // Steady 3h rhythm but the last feed was 8h ago — raw next time
    // (last + 3h) is 5h in the past. Must clamp to now + grace.
    let last = t0.addingTimeInterval(-8 * hour)
    let times = series(endingAt: last, gaps: Array(repeating: 3 * hour, count: 6))
    let p = PredictionEngine.predict(timestamps: times, now: t0, config: feedConfig)!
    expect(p.nextTime >= t0.addingTimeInterval(feedConfig.grace - 1),
           "next time must be clamped to now + grace, got \(p.nextTime.timeIntervalSince(t0) / 60)m from now")
}

test("unsorted input is handled") {
    let times = series(endingAt: t0, gaps: Array(repeating: 3 * hour, count: 5)).shuffled()
    let p = PredictionEngine.predict(timestamps: times, now: t0, config: feedConfig)!
    expectNear(p.expectedInterval, 3 * hour, tolerance: 60, "order must not matter")
}

test("duplicate timestamps (zero gaps) are skipped, not divided by") {
    let base = series(endingAt: t0, gaps: [3 * hour, 3 * hour, 3 * hour])
    let times = base + [base[1]] // exact duplicate in the middle
    let p = PredictionEngine.predict(timestamps: times, now: t0, config: feedConfig)!
    expectNear(p.expectedInterval, 3 * hour, tolerance: 60,
               "duplicate event must not distort the estimate")
}

// MARK: - Summary

        print("")
        if failures == 0 {
            print("✅ All \(checks) checks passed")
            exit(0)
        } else {
            print("❌ \(failures) of \(checks) checks failed")
            exit(1)
        }
    }
}
