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

    // Asset-catalog name of the kawaii icon on the poop/pee count tiles.
    // Feed and sleep hero cards keep their mascots.
    var icon: String { rawValue }

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

    /// Edge stroke of the poop/pee count tiles — a shade deeper than the
    /// tile surface. Clear for feed/sleep, which draw no border.
    var borderColor: Color {
        switch self {
        case .poop: Theme.poopBorder
        case .pee:  Theme.peeBorder
        case .feed, .sleep: .clear
        }
    }

    /// Color of the big daily count on the poop/pee tiles. Pee gets its
    /// own dark shade — marigold ink washes out on the butter surface.
    var countColor: Color {
        switch self {
        case .pee: Theme.peeCount
        default:   inkColor
        }
    }

    /// Spoken label for the "+" log button, e.g. "Log feed" — the visual
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
