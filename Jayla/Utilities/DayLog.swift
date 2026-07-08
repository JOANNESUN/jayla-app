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
}
