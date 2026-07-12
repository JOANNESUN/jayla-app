//
//  ForecastEngine.swift
//  Jayla
//
//  The keepsake page's "nursery weather channel": the existing
//  predictions (next feed, next nap, nap length) arranged on a small
//  hour-by-hour timeline instead of shown one at a time. Nothing new is
//  learned here — the engine just walks the predicted rhythm forward a
//  few hours and labels each hour with its dominant state.
//
//  "Fussy" is deliberately inferred, never logged: the rough patch is
//  the last half hour before predicted relief arrives (a feed or a
//  nap), which is exactly when hunger and tiredness peak. Keeping it
//  inferred keeps logging one-tap.
//
//  Pure Foundation, plain inputs — CLI-testable like PredictionEngine.
//  PredictionPriors.swift builds Input from the app's domain types.
//

import Foundation

nonisolated enum ForecastEngine {

    /// Everything the simulation needs, as plain values. Optionals are
    /// honest gaps (nothing logged yet), not errors — the forecast
    /// degrades gracefully around them.
    struct Input {
        var now: Date
        /// Most recent feed and the learned gap between feeds.
        var lastFeed: Date?
        var feedInterval: TimeInterval?
        /// Set while a nap is open — she is asleep right now.
        var asleepSince: Date?
        /// Expected nap length (prior-backed, so always available).
        var napDuration: TimeInterval = 45 * 60
        /// Predicted start of the next nap (nil while asleep).
        var nextNapStart: Date?
        /// Learned gap between nap starts.
        var napInterval: TimeInterval?
        /// Both feed and sleep predictions still at .learning.
        var isLearning: Bool = false
    }

    enum Mood: Equatable {
        case snoozing, content, gettingHungry, hungry, sleepy, learning
    }

    enum SlotState: Equatable {
        case nap, feed, fussy, chill, bed
    }

    struct Slot: Equatable {
        let hour: Date
        let state: SlotState
    }

    struct Forecast: Equatable {
        let mood: Mood
        /// The next `slotCount` whole hours, labelled.
        let slots: [Slot]
        /// Start of the first fussy hour, nil when the outlook is calm.
        let fussWarning: Date?
        /// Surfaced so the card can show the honesty caveat.
        let isLearning: Bool
    }

    static let slotCount = 5
    /// Sleep between these local hours (evening through early morning)
    /// reads as "bed", not "nap".
    private static let bedHour = 19
    private static let morningHour = 6
    /// Minimum plausible awake stretch between naps.
    private static let minWake: TimeInterval = 45 * 60
    /// How close relief (feed/nap) must be past the hour's end for the
    /// hour to read as the fussy build-up to it.
    private static let fussLead: TimeInterval = 30 * 60

    /// nil only when there is nothing at all to anchor a forecast to.
    static func forecast(_ input: Input,
                         calendar: Calendar = .current) -> Forecast? {
        guard input.lastFeed != nil || input.asleepSince != nil
                || input.nextNapStart != nil else { return nil }

        let now = input.now
        guard let firstHour = calendar.dateInterval(of: .hour, for: now)?.end
        else { return nil }
        let hours = (0..<slotCount).compactMap {
            calendar.date(byAdding: .hour, value: $0, to: firstHour)
        }
        guard let horizon = hours.last.map({ $0.addingTimeInterval(3_600 + fussLead) })
        else { return nil }

        let naps = projectedNaps(input, until: horizon)
        let feeds = projectedFeeds(input, until: horizon)

        var slots: [Slot] = []
        for hour in hours {
            let end = hour.addingTimeInterval(3_600)
            let mid = hour.addingTimeInterval(1_800)
            let state: SlotState
            if let nap = naps.first(where: { $0.start <= mid && mid < $0.end }) {
                // Evening-through-early-morning sleep is bed; hour-of-day
                // from the block's start (clamped to this slot) so a
                // 7pm-onwards stretch reads as one bedtime past midnight.
                let startHour = calendar.component(.hour, from: max(nap.start, hour))
                state = startHour >= bedHour || startHour < morningHour ? .bed : .nap
            } else if feeds.contains(where: { hour <= $0 && $0 < end }) {
                state = .feed
            } else if isFussy(hourEnd: end, feeds: feeds, naps: naps) {
                state = .fussy
            } else {
                state = .chill
            }
            slots.append(Slot(hour: hour, state: state))
        }

        return Forecast(mood: mood(input),
                        slots: slots,
                        fussWarning: slots.first { $0.state == .fussy }?.hour,
                        isLearning: input.isLearning)
    }

    // MARK: - Now

    private static func mood(_ input: Input) -> Mood {
        let now = input.now
        if input.asleepSince != nil { return .snoozing }
        if let lastFeed = input.lastFeed,
           now.timeIntervalSince(lastFeed) < 45 * 60 { return .content }
        if let lastFeed = input.lastFeed, let gap = input.feedInterval {
            // Raw, unclamped next feed — same honesty as the hero card.
            let nextFeed = lastFeed.addingTimeInterval(gap)
            if nextFeed <= now { return .hungry }
            if nextFeed.timeIntervalSince(now) <= 40 * 60 { return .gettingHungry }
        }
        if let nextNap = input.nextNapStart,
           nextNap.timeIntervalSince(now) <= 20 * 60 { return .sleepy }
        return input.isLearning ? .learning : .content
    }

    // MARK: - Simulation

    /// Sleep blocks over the horizon: the open nap (or the predicted
    /// next one), then repeats at the learned nap-start spacing.
    private static func projectedNaps(_ input: Input,
                                      until horizon: Date)
        -> [(start: Date, end: Date)] {
        let duration = max(input.napDuration, 15 * 60)

        var naps: [(start: Date, end: Date)] = []
        if let since = input.asleepSince {
            // Asleep now is a logged fact; if the wake estimate has
            // already passed, she'll be up "any time now" — keep the
            // block alive just a little past now.
            naps.append((since, max(since.addingTimeInterval(duration),
                                    input.now.addingTimeInterval(5 * 60))))
        } else if let next = input.nextNapStart {
            // Overdue nap = imminent, not in the past.
            let start = max(next, input.now)
            naps.append((start, start.addingTimeInterval(duration)))
        }

        // A too-short learned interval would stack naps on top of each
        // other; keep at least a minimum awake stretch between blocks.
        if let interval = input.napInterval, var lastStart = naps.last?.start {
            let stride = max(interval, duration + minWake)
            while true {
                var start = lastStart.addingTimeInterval(stride)
                if let lastEnd = naps.last?.end,
                   start < lastEnd.addingTimeInterval(minWake) {
                    start = lastEnd.addingTimeInterval(minWake)
                }
                guard start < horizon else { break }
                naps.append((start, start.addingTimeInterval(duration)))
                lastStart = start
            }
        }
        return naps
    }

    /// Feed moments over the horizon: last feed plus the learned gap,
    /// repeating. An overdue feed sits at `now` — imminent, not lost.
    private static func projectedFeeds(_ input: Input,
                                       until horizon: Date) -> [Date] {
        guard let lastFeed = input.lastFeed,
              let gap = input.feedInterval, gap > 60 else { return [] }
        var feeds: [Date] = []
        var next = max(lastFeed.addingTimeInterval(gap), input.now)
        while next < horizon {
            feeds.append(next)
            next = next.addingTimeInterval(gap)
        }
        return feeds
    }

    /// The build-up hour before predicted relief: fussy when a feed or
    /// a nap is due within `fussLead` after this hour ends. (Relief
    /// inside the hour itself already labels the hour .feed/.nap.)
    private static func isFussy(hourEnd: Date,
                                feeds: [Date],
                                naps: [(start: Date, end: Date)]) -> Bool {
        func inWindow(_ date: Date) -> Bool {
            date >= hourEnd && date < hourEnd.addingTimeInterval(fussLead)
        }
        return feeds.contains(where: inWindow)
            || naps.contains { inWindow($0.start) }
    }
}
