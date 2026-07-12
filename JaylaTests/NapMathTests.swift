//
//  NapMathTests.swift
//  JaylaTests
//
//  CLI tests for the "which nap just woke?" rule — no XCTest, no
//  simulator. Run with:  ./JaylaTests/run-napmath.sh
//
//  Compiled together with Jayla/Utilities/NapMath.swift only. The two
//  regressions here are the adjust-then-wake bugs: the wake summary
//  missing for up to a minute (stale TimelineView tick), and the wrong
//  nap picked after a start was backdated behind an older nap.
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
let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)  // fixed anchor

func nap(startingAgo: TimeInterval, duration: TimeInterval)
    -> (start: Date, duration: TimeInterval) {
    (t0.addingTimeInterval(-startingAgo), duration)
}

// MARK: - Tests

@main
struct NapMathTests {
    static func main() {
        test("fresh wake within the half-hour window is picked") {
            let picked = NapMath.justWokeIndex(
                naps: [nap(startingAgo: 50 * minute, duration: 45 * minute)],
                now: t0)
            expect(picked == 0, "nap that ended 5m ago should be the just-woke nap")
        }

        test("summary expires after the half-hour window") {
            let picked = NapMath.justWokeIndex(
                naps: [nap(startingAgo: 2 * hour, duration: 45 * minute)],
                now: t0)
            expect(picked == nil, "nap that ended 1h15m ago is history, not a fresh wake")
        }

        test("REGRESSION: wake tap ahead of the stale minute tick still shows") {
            // "Wake up" tapped at t0; the TimelineView clock still says
            // t0 − 59s. The nap's end is 59s in the render clock's
            // future — it must still count as just-woke.
            let picked = NapMath.justWokeIndex(
                naps: [nap(startingAgo: 30 * minute, duration: 30 * minute)],
                now: t0.addingTimeInterval(-59))
            expect(picked == 0, "end 59s ahead of the stale tick must still be just-woke")
        }

        test("an end far in the future is bad data, not a wake") {
            let picked = NapMath.justWokeIndex(
                naps: [nap(startingAgo: 10 * minute, duration: 30 * minute)],
                now: t0)
            expect(picked == nil, "nap 'ending' 20m from now should not read as just-woke")
        }

        test("REGRESSION: backdated start behind an older nap still picks the right nap") {
            // Morning nap 4h ago (index 0). Current nap logged later but
            // its start was adjusted back past the morning nap's start;
            // it just ended at t0. Latest START is the morning nap —
            // latest END is the adjusted one. End must win, or the
            // summary vanishes and undo reopens the wrong nap.
            let naps = [
                nap(startingAgo: 4 * hour, duration: 40 * minute),           // old, ended long ago
                nap(startingAgo: 4.5 * hour, duration: 4.5 * hour),          // adjusted, ends at t0
            ]
            let picked = NapMath.justWokeIndex(naps: naps, now: t0)
            expect(picked == 1, "the nap that just ENDED wins, not the latest start")
        }

        test("open naps (no duration) are ignored") {
            let naps = [
                nap(startingAgo: 20 * minute, duration: 0),                  // open / degenerate
                nap(startingAgo: 50 * minute, duration: 45 * minute),        // ended 5m ago
            ]
            let picked = NapMath.justWokeIndex(naps: naps, now: t0)
            expect(picked == 1, "zero-duration rows never count as a completed nap")
        }

        test("no completed naps → no summary") {
            expect(NapMath.justWokeIndex(naps: [], now: t0) == nil, "empty in, nil out")
        }

        print("\n\(checks) checks, \(failures) failure\(failures == 1 ? "" : "s")")
        if failures > 0 { exit(1) }
        print("All NapMath tests passed ✅")
    }
}
