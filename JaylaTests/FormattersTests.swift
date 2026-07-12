//
//  FormattersTests.swift
//  JaylaTests
//
//  CLI tests for the shared time/duration strings — no XCTest, no
//  simulator. Run with:  ./JaylaTests/run-formatters.sh
//
//  durationPadded feeds the sleep-card sentence headlines ("awake for
//  1h 02m and likely tired by …"); the zero-padding exists so the big
//  line doesn't jiggle as minutes tick. Format.time is deliberately
//  untested here — it's locale-dependent by design.
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

let minute: TimeInterval = 60
let hour: TimeInterval = 3_600

// MARK: - Tests

@main
struct FormattersTests {
    static func main() {
        test("duration — plain minutes and hour boundaries") {
            expect(Format.duration(0) == "0m", "0s → 0m")
            expect(Format.duration(42 * minute) == "42m", "42m stays bare")
            expect(Format.duration(hour) == "1h", "exactly 1h drops the minutes")
            expect(Format.duration(hour + 5 * minute) == "1h 5m", "1h05 → 1h 5m (unpadded)")
        }

        test("duration — never negative") {
            expect(Format.duration(-5 * minute) == "0m", "clock skew clamps to 0m")
        }

        test("durationPadded — pads minutes only once there's an hour") {
            expect(Format.durationPadded(2 * minute) == "2m", "under an hour stays bare")
            expect(Format.durationPadded(hour + 2 * minute) == "1h 02m", "1h02 pads to 02m")
            expect(Format.durationPadded(hour + 25 * minute) == "1h 25m", "two digits untouched")
        }

        test("durationPadded — the width-jiggle regression it exists for") {
            // "1h 9m" → "1h 10m" reflows the headline; padded they're equal width.
            let nine = Format.durationPadded(hour + 9 * minute)
            let ten = Format.durationPadded(hour + 10 * minute)
            expect(nine == "1h 09m", "1h09 → 1h 09m")
            expect(nine.count == ten.count, "09m and 10m must be the same width")
        }

        test("durationPadded — exact hours keep the padded 00m") {
            expect(Format.durationPadded(2 * hour) == "2h 00m",
                   "exact hours read '2h 00m' so the shape never changes mid-tick")
            expect(Format.durationPadded(0) == "0m", "zero stays bare minutes")
            expect(Format.durationPadded(-minute) == "0m", "negative clamps like duration")
        }

        test("humanTime — coarse buckets") {
            let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
            expect(Format.humanTime(since: now.addingTimeInterval(-30), now: now) == "just now",
                   "under a minute is 'just now'")
            expect(Format.humanTime(since: now.addingTimeInterval(-5 * minute), now: now) == "5 min ago",
                   "minutes bucket")
            expect(Format.humanTime(since: now.addingTimeInterval(-2 * hour), now: now) == "2h ago",
                   "even hours drop the minutes")
            expect(Format.humanTime(since: now.addingTimeInterval(-(2 * hour + 30 * minute)), now: now) == "2h 30m ago",
                   "hours + minutes bucket")
        }

        print("\n\(checks) checks, \(failures) failure\(failures == 1 ? "" : "s")")
        if failures > 0 { exit(1) }
        print("All Formatters tests passed ✅")
    }
}
