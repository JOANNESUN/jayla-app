//
//  DayLog.swift
//  Jayla
//
//  Pure day-bucketing for the history page: split sleeps at midnight,
//  group everything by calendar day, total what each day held. No
//  SwiftData, no SwiftUI — HistoryView maps ActivityEvent rows into
//  plain DayLog.Event values, and the CLI tests compile this file alone
//  (./JaylaTests/run-daylog.sh).
//

import Foundation

/// One piece of a sleep as it appears in a single day's column. A sleep
/// crossing midnight becomes two segments; totals sum segments so every
/// minute lands on the day it was actually slept.
struct SleepSegment: Identifiable {
    /// The stored event this segment came from, for delete/selection.
    let eventID: UUID
    let start: Date
    let end: Date
    /// True on the tail of the nap still in progress — drawn "growing".
    let isOpen: Bool

    var id: String { "\(eventID.uuidString)-\(start.timeIntervalSinceReferenceDate)" }
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Everything one calendar day holds, chart-ready.
struct DaySummary: Identifiable {
    /// Local midnight — the day's identity.
    let day: Date
    let sleepSegments: [SleepSegment]
    let feedTimes: [Date]
    let peeCount: Int
    let poopCount: Int

    var id: Date { day }
    var sleepTotal: TimeInterval {
        sleepSegments.reduce(0) { $0 + $1.duration }
    }
    var feedCount: Int { feedTimes.count }
    var isEmpty: Bool {
        sleepSegments.isEmpty && feedTimes.isEmpty && peeCount == 0 && poopCount == 0
    }
}

/// One week of the trend module, oldest week first.
struct WeekStat: Identifiable {
    /// 0 = oldest of the four weeks shown.
    let index: Int
    /// Average sleep per day, over the days that logged any sleep.
    let avgSleep: TimeInterval
    /// How many of the week's days logged sleep — the denominator.
    let daysWithSleep: Int

    var id: Int { index }
}

/// The history page's trend card: weekly sleep averages plus per-day
/// frequencies. Frequencies only — Jayla logs moments, not volumes.
struct TrendSummary {
    enum Direction {
        case up, steady, down
        /// Not enough data in both weeks to compare honestly.
        case unknown
    }

    let weeks: [WeekStat]
    /// Latest week's average sleep per tracked day.
    let avgSleepPerDay: TimeInterval
    let direction: Direction
    /// Fewer, longer naps than the week before (with sleep not down) —
    /// the consolidation milestone parents watch for.
    let napsConsolidating: Bool
    /// Sleeps per day over the last week's sleep-logged days — same
    /// segment counting as the consolidation check (a night crossing
    /// midnight counts on both days).
    let napsPerDay: Double
    let feedsPerDay: Double
    let peePerDay: Double
    let poopPerDay: Double
}

enum DayLog {
    /// Mirror of ActivityType's raw values, so this file stays free of
    /// app/UI imports. Mapped via `Kind(rawValue: event.typeRaw)`.
    enum Kind: String {
        case feed, sleep, poop, pee
    }

    /// A plain-value ActivityEvent.
    struct Event {
        let id: UUID
        let kind: Kind
        let timestamp: Date
        let durationSeconds: Double?
    }

    /// Same rule as the rest of the app: an open nap is a sleep with no
    /// duration yet, and the 16h guard keeps legacy instant-tap sleep
    /// rows (nil duration forever) from reading as "still asleep".
    static let openNapGuard: TimeInterval = 16 * 3_600

    /// Split a sleep interval at every local midnight it crosses.
    /// `calendar.date(byAdding: .day)` (never +86 400) keeps DST days
    /// honest; the loop handles sleeps spanning several midnights.
    static func splitAtMidnights(eventID: UUID, start: Date, end: Date,
                                 isOpen: Bool,
                                 calendar: Calendar) -> [SleepSegment] {
        guard end > start else { return [] }   // zero-length legacy rows → no ribbon
        var segments: [SleepSegment] = []
        var cursor = start
        while cursor < end {
            let day = calendar.startOfDay(for: cursor)
            let nextMidnight = calendar.date(byAdding: .day, value: 1, to: day) ?? end
            let segmentEnd = min(end, nextMidnight)
            segments.append(SleepSegment(eventID: eventID,
                                         start: cursor,
                                         end: segmentEnd,
                                         isOpen: isOpen && segmentEnd == end))
            cursor = segmentEnd
        }
        return segments
    }

    /// Bucket events into one DaySummary per calendar day, oldest first,
    /// covering exactly the last `daysBack` days ending today — empty
    /// days included so the chart draws one column per day. Sleep still
    /// in progress runs to `now`.
    static func build(events: [Event], now: Date, daysBack: Int,
                      calendar: Calendar = .current) -> [DaySummary] {
        let today = calendar.startOfDay(for: now)
        let days: [Date] = (0..<max(daysBack, 1)).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }.reversed()
        guard let windowStart = days.first else { return [] }

        var segmentsByDay: [Date: [SleepSegment]] = [:]
        var feedsByDay: [Date: [Date]] = [:]
        var peeByDay: [Date: Int] = [:]
        var poopByDay: [Date: Int] = [:]

        for event in events {
            switch event.kind {
            case .sleep:
                let end: Date
                let isOpen: Bool
                if let duration = event.durationSeconds {
                    end = event.timestamp.addingTimeInterval(duration)
                    isOpen = false
                } else if now.timeIntervalSince(event.timestamp) < openNapGuard,
                          event.timestamp <= now {
                    end = now
                    isOpen = true
                } else {
                    continue   // legacy nil-duration row: no ribbon, no total
                }
                for segment in splitAtMidnights(eventID: event.id,
                                                start: event.timestamp,
                                                end: end,
                                                isOpen: isOpen,
                                                calendar: calendar) {
                    let day = calendar.startOfDay(for: segment.start)
                    guard day >= windowStart, day <= today else { continue }
                    segmentsByDay[day, default: []].append(segment)
                }
            case .feed:
                let day = calendar.startOfDay(for: event.timestamp)
                feedsByDay[day, default: []].append(event.timestamp)
            case .pee:
                peeByDay[calendar.startOfDay(for: event.timestamp), default: 0] += 1
            case .poop:
                poopByDay[calendar.startOfDay(for: event.timestamp), default: 0] += 1
            }
        }

        return days.map { day in
            DaySummary(day: day,
                       sleepSegments: (segmentsByDay[day] ?? [])
                           .sorted { $0.start < $1.start },
                       feedTimes: (feedsByDay[day] ?? []).sorted(),
                       peeCount: peeByDay[day] ?? 0,
                       poopCount: poopByDay[day] ?? 0)
        }
    }

    // MARK: - Trends

    /// A week must have logged sleep on this many days before its
    /// average is worth comparing — two data points aren't a trend.
    static let minTrendDays = 3
    /// Week-over-week change below this reads as "steady".
    static let steadyBand = 0.05

    /// Boil the day buckets down to the trend card: four weekly sleep
    /// averages (last 28 days, newest week last), a week-over-week
    /// direction, and per-day frequencies over the last 7 tracked days.
    /// Returns nil until at least two days have any data at all.
    static func trends(days: [DaySummary]) -> TrendSummary? {
        guard days.filter({ !$0.isEmpty }).count >= 2 else { return nil }

        // Weekly sleep averages over the last 28 days, in 7-day chunks.
        let month = Array(days.suffix(28))
        let chunkCount = (month.count + 6) / 7
        let weeks: [WeekStat] = (0..<chunkCount).map { index in
            let start = max(0, month.count - (chunkCount - index) * 7)
            let end = month.count - (chunkCount - 1 - index) * 7
            let slept = month[start..<end].filter { !$0.sleepSegments.isEmpty }
            let total = slept.reduce(0) { $0 + $1.sleepTotal }
            return WeekStat(index: index,
                            avgSleep: slept.isEmpty ? 0 : total / Double(slept.count),
                            daysWithSleep: slept.count)
        }

        let latest = weeks.last
        let previous = weeks.count >= 2 ? weeks[weeks.count - 2] : nil

        var direction = TrendSummary.Direction.unknown
        var consolidating = false
        if let latest, let previous,
           latest.daysWithSleep >= minTrendDays,
           previous.daysWithSleep >= minTrendDays,
           previous.avgSleep > 0 {
            let change = (latest.avgSleep - previous.avgSleep) / previous.avgSleep
            direction = change > steadyBand ? .up
                      : change < -steadyBand ? .down : .steady

            // Consolidation: fewer sleeps per day, without sleeping less.
            let latestDays = month.suffix(7).filter { !$0.sleepSegments.isEmpty }
            let previousDays = month.suffix(14).prefix(7)
                .filter { !$0.sleepSegments.isEmpty }
            let latestPerDay = Double(latestDays.reduce(0) { $0 + $1.sleepSegments.count })
                / Double(latestDays.count)
            let previousPerDay = Double(previousDays.reduce(0) { $0 + $1.sleepSegments.count })
                / Double(previousDays.count)
            consolidating = previousPerDay - latestPerDay >= 0.5 && direction != .down
        }

        // Frequencies: the last 7 days that logged anything.
        let tracked = Array(days.filter { !$0.isEmpty }.suffix(7))
        let count = Double(tracked.count)
        let sleptDays = days.suffix(7).filter { !$0.sleepSegments.isEmpty }
        let napsPerDay = sleptDays.isEmpty ? 0
            : Double(sleptDays.reduce(0) { $0 + $1.sleepSegments.count })
                / Double(sleptDays.count)
        return TrendSummary(
            weeks: weeks,
            avgSleepPerDay: latest?.avgSleep ?? 0,
            direction: direction,
            napsConsolidating: consolidating,
            napsPerDay: napsPerDay,
            feedsPerDay: Double(tracked.reduce(0) { $0 + $1.feedCount }) / count,
            peePerDay: Double(tracked.reduce(0) { $0 + $1.peeCount }) / count,
            poopPerDay: Double(tracked.reduce(0) { $0 + $1.poopCount }) / count)
    }
}
