//
//  ForecastEngineTests.swift
//  JaylaTests
//
//  CLI tests for the pure forecast engine — no XCTest, no simulator.
//  Run with:  ./JaylaTests/run.sh
//
//  Compiled together with Jayla/Prediction/ForecastEngine.swift only.
//  A fixed UTC calendar keeps hour-of-day assertions (bedtime!) stable
//  no matter where the tests run.
//

import Foundation

// MARK: - Tiny harness (mirrors PredictionEngineTests)

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

func test(_ name: String, _ body: () -> Void) {
    print("• \(name)")
    body()
}

// MARK: - Fixtures

let hour: TimeInterval = 3_600
let minute: TimeInterval = 60

let utc: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()

/// 14:30 UTC on a fixed day — slots therefore run 15:00…19:00, so the
/// last slot straddles the 19:00 bed threshold.
let t0: Date = {
    var comps = DateComponents()
    comps.year = 2026; comps.month = 7; comps.day = 8
    comps.hour = 14; comps.minute = 30
    comps.timeZone = TimeZone(identifier: "UTC")!
    return utc.date(from: comps)!
}()

func slotState(_ forecast: ForecastEngine.Forecast, _ index: Int) -> ForecastEngine.SlotState {
    forecast.slots[index].state
}

// MARK: - Tests

@main
struct ForecastEngineTests {
    static func main() {

test("nothing logged → no forecast") {
    let f = ForecastEngine.forecast(ForecastEngine.Input(now: t0), calendar: utc)
    expect(f == nil, "expected nil with no anchors at all")
}

test("five whole hours, starting at the next hour top") {
    var input = ForecastEngine.Input(now: t0)
    input.lastFeed = t0.addingTimeInterval(-1 * hour)
    input.feedInterval = 3 * hour
    let f = ForecastEngine.forecast(input, calendar: utc)!
    expect(f.slots.count == 5, "expected 5 slots, got \(f.slots.count)")
    expect(utc.component(.hour, from: f.slots[0].hour) == 15,
           "first slot should be 15:00")
    expect(utc.component(.minute, from: f.slots[0].hour) == 0,
           "slots sit on whole hours")
}

test("predicted feed lands in its hour; the hour before reads fussy") {
    var input = ForecastEngine.Input(now: t0)
    // Fed 1h ago, 3h rhythm → next feed 16:30, inside slot 16.
    input.lastFeed = t0.addingTimeInterval(-1 * hour)
    input.feedInterval = 3 * hour
    let f = ForecastEngine.forecast(input, calendar: utc)!
    expect(slotState(f, 1) == .feed, "16:00 slot should be feed, got \(slotState(f, 1))")
    expect(slotState(f, 0) == .chill,
           "15:00 slot is calm — feed is mid-next-hour, not right after it")
}

test("fussy build-up when relief comes just past the hour") {
    var input = ForecastEngine.Input(now: t0)
    // Fed 15m ago, 3h rhythm → next feed 17:15: slot 17 feeds,
    // slot 16 is the cranky front before it.
    input.lastFeed = t0.addingTimeInterval(-15 * minute)
    input.feedInterval = 3 * hour
    let f = ForecastEngine.forecast(input, calendar: utc)!
    expect(slotState(f, 2) == .feed, "17:00 slot should be feed, got \(slotState(f, 2))")
    expect(slotState(f, 1) == .fussy, "16:00 slot should be fussy, got \(slotState(f, 1))")
    expect(f.fussWarning == f.slots[1].hour, "warning points at the first fussy hour")
}

test("asleep now → snoozing mood and a nap slot while the block lasts") {
    var input = ForecastEngine.Input(now: t0)
    input.asleepSince = t0.addingTimeInterval(-20 * minute) // 14:10
    input.napDuration = 2 * hour                            // wake ~16:10
    let f = ForecastEngine.forecast(input, calendar: utc)!
    expect(f.mood == .snoozing, "asleep now must read snoozing, got \(f.mood)")
    expect(slotState(f, 0) == .nap, "15:00 slot should be nap, got \(slotState(f, 0))")
}

test("sleep from 19:00 onwards reads bed, not nap") {
    var input = ForecastEngine.Input(now: t0)
    input.nextNapStart = t0.addingTimeInterval(4.75 * hour) // 19:15
    input.napDuration = 2 * hour
    let f = ForecastEngine.forecast(input, calendar: utc)!
    expect(slotState(f, 4) == .bed, "19:00 slot should be bed, got \(slotState(f, 4))")
}

test("overdue feed → hangry now, feed projected imminently") {
    var input = ForecastEngine.Input(now: t0)
    input.lastFeed = t0.addingTimeInterval(-4 * hour)
    input.feedInterval = 3 * hour // next was due an hour ago
    let f = ForecastEngine.forecast(input, calendar: utc)!
    expect(f.mood == .hungry, "overdue feed must read hungry, got \(f.mood)")
    // Overdue feed sits at now (14:30); the NEXT one lands 17:30.
    expect(slotState(f, 2) == .feed, "17:00 slot should be feed, got \(slotState(f, 2))")
}

test("recent feed → content; approaching feed → peckish") {
    var input = ForecastEngine.Input(now: t0)
    input.lastFeed = t0.addingTimeInterval(-20 * minute)
    input.feedInterval = 3 * hour
    let recent = ForecastEngine.forecast(input, calendar: utc)!
    expect(recent.mood == .content, "20m after a feed reads content, got \(recent.mood)")

    input.lastFeed = t0.addingTimeInterval(-2.5 * hour) // next due in 30m
    let soon = ForecastEngine.forecast(input, calendar: utc)!
    expect(soon.mood == .gettingHungry,
           "30m before a feed reads peckish, got \(soon.mood)")
}

test("nap window opening → sleepy mood") {
    var input = ForecastEngine.Input(now: t0)
    input.lastFeed = t0.addingTimeInterval(-1 * hour)
    input.feedInterval = 3 * hour
    input.nextNapStart = t0.addingTimeInterval(10 * minute)
    input.napDuration = 1 * hour
    let f = ForecastEngine.forecast(input, calendar: utc)!
    expect(f.mood == .sleepy, "nap due in 10m reads sleepy, got \(f.mood)")
}

test("naps repeat at the learned start-to-start spacing") {
    var input = ForecastEngine.Input(now: t0)
    input.nextNapStart = t0.addingTimeInterval(15 * minute) // 14:45
    input.napDuration = 1 * hour                            // → 15:45
    input.napInterval = 2.5 * hour                          // next 17:15
    let f = ForecastEngine.forecast(input, calendar: utc)!
    expect(slotState(f, 0) == .nap, "15:00 asleep, got \(slotState(f, 0))")
    expect(slotState(f, 2) == .nap, "17:00 slot covers the projected 17:15 nap? no — its midpoint 17:30 is inside 17:15–18:15, so nap. got \(slotState(f, 2))")
    expect(slotState(f, 1) == .fussy,
           "16:00 hour ends 45m of wake before the 17:15 nap → fussy, got \(slotState(f, 1))")
}

test("learning flag rides through and softens the mood") {
    var input = ForecastEngine.Input(now: t0)
    input.lastFeed = t0.addingTimeInterval(-1.5 * hour)
    input.feedInterval = 3 * hour
    input.isLearning = true
    let f = ForecastEngine.forecast(input, calendar: utc)!
    expect(f.isLearning, "isLearning must surface on the forecast")
    expect(f.mood == .learning, "no stronger signal → learning mood, got \(f.mood)")
}

print("\n\(checks) checks, \(failures) failure\(failures == 1 ? "" : "s")")
exit(failures == 0 ? 0 : 1)
    }
}
