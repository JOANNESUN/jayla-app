//
//  NapMath.swift
//  Jayla
//
//  The pure "which nap just woke?" rule behind the sleep card's
//  post-wake summary and its undo. Foundation-only on purpose —
//  JaylaTests compiles it alone with plain swiftc (same deal as
//  DayLog). HomeView maps ActivityEvents to plain tuples and back.
//

import Foundation

enum NapMath {

    /// How long the "slept 45m · still asleep? undo" summary stays on
    /// the card after a wake. After that the nap is history.
    static let summaryWindow: TimeInterval = 30 * 60

    /// The render clock is TimelineView's minute tick, which lags a
    /// fresh "Wake up" tap by up to 59s — so a nap that ended slightly
    /// "in the future" is a nap that ended *just now*, not bad data.
    static let tickTolerance: TimeInterval = 90

    /// Index of the completed nap that ended within the last half hour,
    /// or nil. Ranked by latest END, not latest start: the adjust sheet
    /// can backdate a running nap's start behind an older completed
    /// nap, and the summary (and its undo!) must still find the nap
    /// that actually just ended.
    static func justWokeIndex(naps: [(start: Date, duration: TimeInterval)],
                              now: Date) -> Int? {
        let ends = naps.enumerated().compactMap { index, nap -> (index: Int, end: Date)? in
            guard nap.duration > 0 else { return nil }
            return (index, nap.start.addingTimeInterval(nap.duration))
        }
        guard let latest = ends.max(by: { $0.end < $1.end }) else { return nil }
        let sinceEnd = now.timeIntervalSince(latest.end)
        guard sinceEnd < summaryWindow, sinceEnd > -tickTolerance else { return nil }
        return latest.index
    }
}
