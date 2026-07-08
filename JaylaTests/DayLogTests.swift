//
//  DayLogTests.swift
//  JaylaTests
//
//  CLI tests for the history page's pure day-bucketing (DayLog.swift).
//  No XCTest, no simulator. Run with:  ./JaylaTests/run-daylog.sh
//
//  Uses a fixed calendar (Gregorian, Auckland) so midnight and DST
//  behavior don't depend on the machine running the tests. Auckland's
//  DST transitions land in April/September — the DST case below uses
//  the September spring-forward (2:00 → 3:00 am, a 23-hour day).
//

import Foundation

// MARK: - Tiny harness

var failures = 0
var checks = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    checks += 1
    if !condition {
        failures += 1
        print("  ✗ FAIL: \(message)  (line \(line))")
    }
}

func expectNear(_ value: Double, _ target: Double, tolerance: Double = 1,
                _ message: String, line: Int = #line) {
    expect(abs(value - target) <= tolerance,
           "\(message) — got \(value), wanted \(target) ± \(tolerance)", line: line)
}

func test(_ name: String, _ body: () -> Void) {
    print("• \(name)")
    body()
}

// MARK: - Fixtures

var cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Pacific/Auckland")!
    return c
}()

let minute: TimeInterval = 60
let hour: TimeInterval = 3_600

/// A local date in the fixed calendar.
func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
    cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}

func sleep(_ id: UUID = UUID(), at start: Date, hours: Double) -> DayLog.Event {
    DayLog.Event(id: id, kind: .sleep, timestamp: start,
                 durationSeconds: hours * hour)
}

func moment(_ kind: DayLog.Kind, at time: Date) -> DayLog.Event {
    DayLog.Event(id: UUID(), kind: kind, timestamp: time, durationSeconds: nil)
}

// MARK: - Tests

@main
struct DayLogTestsMain {
    static func main() {

test("nap inside one day stays one segment on that day") {
    let start = date(2026, 7, 7, 13, 0)
    let days = DayLog.build(events: [sleep(at: start, hours: 1.5)],
                            now: date(2026, 7, 7, 20, 0), daysBack: 3,
                            calendar: cal)
    expect(days.count == 3, "3 day buckets")
    let today = days.last!
    expect(today.sleepSegments.count == 1, "one segment")
    expectNear(today.sleepTotal, 1.5 * hour, "total 1h30")
    expect(days[0].sleepSegments.isEmpty && days[1].sleepSegments.isEmpty,
           "earlier days empty")
}

test("22:30 + 6h splits into 1h30 and 4h30 on consecutive days") {
    let id = UUID()
    let start = date(2026, 7, 6, 22, 30)
    let days = DayLog.build(events: [sleep(id, at: start, hours: 6)],
                            now: date(2026, 7, 7, 12, 0), daysBack: 3,
                            calendar: cal)
    let day6 = days[1], day7 = days[2]
    expect(day6.sleepSegments.count == 1 && day7.sleepSegments.count == 1,
           "one segment each day")
    expectNear(day6.sleepTotal, 1.5 * hour, "day 6 gets 1h30")
    expectNear(day7.sleepTotal, 4.5 * hour, "day 7 gets 4h30")
    expect(day7.sleepSegments[0].start == date(2026, 7, 7, 0, 0),
           "second segment starts at midnight")
    expect(day6.sleepSegments[0].eventID == id
        && day7.sleepSegments[0].eventID == id,
           "both segments point at the stored event")
}

test("sleep spanning two midnights lands on three days") {
    let start = date(2026, 7, 5, 23, 0)
    let days = DayLog.build(events: [sleep(at: start, hours: 26)],
                            now: date(2026, 7, 7, 12, 0), daysBack: 3,
                            calendar: cal)
    expectNear(days[0].sleepTotal, 1 * hour, "day 5: 23:00–24:00")
    expectNear(days[1].sleepTotal, 24 * hour, "day 6: full day")
    expectNear(days[2].sleepTotal, 1 * hour, "day 7: 00:00–01:00")
}

test("open nap runs to now and is flagged open") {
    let start = date(2026, 7, 7, 13, 0)
    let now = date(2026, 7, 7, 13, 40)
    let days = DayLog.build(
        events: [DayLog.Event(id: UUID(), kind: .sleep, timestamp: start,
                              durationSeconds: nil)],
        now: now, daysBack: 2, calendar: cal)
    let today = days.last!
    expect(today.sleepSegments.count == 1, "open nap has a segment")
    expect(today.sleepSegments.first?.isOpen == true, "flagged open")
    expectNear(today.sleepTotal, 40 * minute, "counts 40m so far")
}

test("open nap crossing midnight: only the tail segment is open") {
    let start = date(2026, 7, 6, 23, 0)
    let now = date(2026, 7, 7, 5, 0)
    let days = DayLog.build(
        events: [DayLog.Event(id: UUID(), kind: .sleep, timestamp: start,
                              durationSeconds: nil)],
        now: now, daysBack: 2, calendar: cal)
    expect(days[0].sleepSegments.first?.isOpen == false, "head is closed")
    expect(days[1].sleepSegments.first?.isOpen == true, "tail is open")
    expectNear(days[1].sleepTotal, 5 * hour, "tail counts 5h")
}

test("legacy nil-duration row past the 16h guard draws nothing") {
    let start = date(2026, 7, 5, 10, 0)
    let days = DayLog.build(
        events: [DayLog.Event(id: UUID(), kind: .sleep, timestamp: start,
                              durationSeconds: nil)],
        now: date(2026, 7, 7, 12, 0), daysBack: 3, calendar: cal)
    expect(days.allSatisfy { $0.sleepSegments.isEmpty }, "no ribbon anywhere")
}

test("zero-length sleep row draws nothing") {
    let days = DayLog.build(
        events: [sleep(at: date(2026, 7, 7, 10, 0), hours: 0)],
        now: date(2026, 7, 7, 12, 0), daysBack: 1, calendar: cal)
    expect(days[0].sleepSegments.isEmpty, "no segment")
}

test("feeds, pee and poop bucket by their own day") {
    let events = [
        moment(.feed, at: date(2026, 7, 6, 9, 0)),
        moment(.feed, at: date(2026, 7, 7, 8, 0)),
        moment(.feed, at: date(2026, 7, 7, 11, 0)),
        moment(.pee, at: date(2026, 7, 7, 8, 5)),
        moment(.pee, at: date(2026, 7, 7, 10, 0)),
        moment(.poop, at: date(2026, 7, 6, 9, 30)),
    ]
    let days = DayLog.build(events: events, now: date(2026, 7, 7, 12, 0),
                            daysBack: 2, calendar: cal)
    expect(days[0].feedCount == 1 && days[0].poopCount == 1
        && days[0].peeCount == 0, "day 6 counts")
    expect(days[1].feedCount == 2 && days[1].peeCount == 2
        && days[1].poopCount == 0, "day 7 counts")
    expect(days[1].feedTimes == days[1].feedTimes.sorted(), "feed times sorted")
}

test("window: exactly daysBack buckets, empty days included, outside dropped") {
    let days = DayLog.build(
        events: [moment(.feed, at: date(2026, 6, 1, 9, 0))],   // long before window
        now: date(2026, 7, 7, 12, 0), daysBack: 30, calendar: cal)
    expect(days.count == 30, "30 buckets")
    expect(days.first!.day == date(2026, 6, 8, 0, 0), "window starts Jun 8")
    expect(days.allSatisfy(\.isEmpty), "old feed dropped, all days empty")
    expect(days.last!.day == date(2026, 7, 7, 0, 0), "ends today")
}

test("sleep starting before the window spills its in-window segment in") {
    // Window is 2 days: Jul 6–7. Sleep starts Jul 5 23:00 for 3h.
    let days = DayLog.build(
        events: [sleep(at: date(2026, 7, 5, 23, 0), hours: 3)],
        now: date(2026, 7, 7, 12, 0), daysBack: 2, calendar: cal)
    expectNear(days[0].sleepTotal, 2 * hour, "Jul 6 gets the 00:00–02:00 spill")
}

test("DST spring-forward day still splits at real midnights") {
    // Auckland 2026: clocks go 2:00 → 3:00 am on Sep 27 (23h day).
    // Sleep 21:00 Sep 26 → 07:00 Sep 27 (10h wall-to-wall = 10h real
    // here because the skipped hour is inside the second segment).
    let days = DayLog.build(
        events: [sleep(at: date(2026, 9, 26, 21, 0), hours: 9)],
        now: date(2026, 9, 27, 12, 0), daysBack: 2, calendar: cal)
    expectNear(days[0].sleepTotal, 3 * hour, "Sep 26 gets 21:00–24:00")
    expectNear(days[1].sleepTotal, 6 * hour, "Sep 27 gets the rest")
    let total = days.reduce(0) { $0 + $1.sleepTotal }
    expectNear(total, 9 * hour, "no minutes lost or invented across DST")
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
