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

    // SF Symbol name shown in the card badge.
    var icon: String {
        switch self {
        case .feed:  "drop.fill"
        case .sleep: "moon.fill"
        case .poop:  "toilet.fill"
        case .pee:   "humidity.fill"
        }
    }

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

    var logButtonLabel: String { "Log \(label.lowercased())" }

    // Sleep is the only activity with a duration; the rest are moments.
    var hasDuration: Bool { self == .sleep }
}
