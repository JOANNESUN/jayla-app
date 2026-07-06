//
//  ActivityType.swift
//  Jayla
//
//  The four things we track. String-backed so it stores as a plain
//  column and stays queryable in #Predicate. Display concerns (icon,
//  colors, labels) live here as computed properties over Theme.
//

import SwiftUI

enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case feed, sleep, poop, pee

    var id: String { rawValue }

    var label: String {
        switch self {
        case .feed:  "Feed"
        case .sleep: "Sleep"
        case .poop:  "Poop"
        case .pee:   "Pee"
        }
    }

    // Asset-catalog name of the hand-drawn mascot shown in the card
    // badge (SVG image sets with vector data preserved).
    var mascot: String { "mascot-\(rawValue)" }

    var badgeColor: Color {
        switch self {
        case .feed:  Theme.feedBadge
        case .sleep: Theme.sleepBadge
        case .poop:  Theme.poopBadge
        case .pee:   Theme.peeBadge
        }
    }

    var inkColor: Color {
        switch self {
        case .feed:  Theme.feedInk
        case .sleep: Theme.sleepInk
        case .poop:  Theme.poopInk
        case .pee:   Theme.peeInk
        }
    }

    // White text washes out on the marigold pee button; every other
    // ink is dark enough to carry it.
    var buttonTextColor: Color { self == .pee ? Theme.ink : .white }

    /// What the on-card button *displays*. Every card just says "Log" —
    /// the card itself already names the activity. VoiceOver gets the
    /// specific `accessibilityLogLabel` instead.
    var logButtonLabel: String { "Log" }

    /// Spoken label for the log button, e.g. "Log feed" — the visual
    /// context (which card the button sits on) is invisible to VoiceOver.
    var accessibilityLogLabel: String { "Log \(label.lowercased())" }

    /// Past-tense verb for the "last happened" line, e.g. "Fed 5 min ago".
    var pastTense: String {
        switch self {
        case .feed:  "Fed"
        case .sleep: "Slept"
        case .poop:  "Pooped"
        case .pee:   "Peed"
        }
    }

    // Sleep is the only activity with a duration; the rest are moments.
    var hasDuration: Bool { self == .sleep }
}
