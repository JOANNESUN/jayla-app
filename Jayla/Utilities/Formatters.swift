//
//  Formatters.swift
//  Jayla
//
//  The little time/duration strings every card speaks — one place so
//  "1h 5m" reads the same on the home dashboard and in history.
//

import Foundation

enum Format {
    /// "2:30 PM"
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "42m" / "1h 5m" / "1h"
    static func duration(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration / 60))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 {
            return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
        }
        return "\(minutes)m"
    }

    /// Coarse, calm relative time: "just now" under a minute, then
    /// minutes/hours — never ticking seconds, never "Last now".
    static func humanTime(since date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours < 24 {
            return rest == 0 ? "\(hours)h ago" : "\(hours)h \(rest)m ago"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
