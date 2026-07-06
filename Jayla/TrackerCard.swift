//
//  TrackerCard.swift
//  Jayla
//
//  Created by JO on 2/7/2026.
//

import SwiftUI

struct TrackerCard: View {
    let type: ActivityType
    let subtitle: String    // what already happened, e.g. "Fed 5 min ago"
    // Compact cards (poop/pee) share one row: mascot on top, small
    // button below — visually subordinate to the full-width cards.
    var isCompact = false
    // Called when the mom taps the log button. Defaults to a no-op so
    // previews and static uses don't have to supply one.
    var onLog: () -> Void = {}

    // The badge holds the mascot next to scaling text, so it must grow
    // with the user's Dynamic Type setting or it reads as an afterthought.
    @ScaledMetric(relativeTo: .title3) private var badgeSize = 46.0
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if isCompact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 26))
        .cardShadow()
    }

    // Badge + text left, button right — except at accessibility text
    // sizes, where the row runs out of width and the button drops below.
    private var regularLayout: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 14))
        return layout {
            HStack(spacing: 14) {
                badge
                VStack(alignment: .leading, spacing: 3) {
                    titleText
                    subtitleText
                }
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            logButton
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 8) {
            badge
            VStack(spacing: 2) {
                titleText
                subtitleText.multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            logButton
        }
        .frame(maxWidth: .infinity)
    }

    private var badge: some View {
        Circle()
            .fill(type.badgeColor)
            .frame(width: badgeSize, height: badgeSize)
            .overlay(
                Image(type.mascot)
                    .resizable()
                    .scaledToFit()
                    .padding(5)
            )
            .accessibilityHidden(true)
    }

    private var titleText: some View {
        Text(type.label)
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(Theme.ink)
    }

    private var subtitleText: some View {
        Text(subtitle)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(Theme.softInk)
            .lineLimit(2)
    }

    private var logButton: some View {
        Button {
            onLog()
        } label: {
            Text(type.logButtonLabel)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(type.buttonTextColor)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(type.inkColor, in: Capsule())
        }
        // Every button displays "Log"; VoiceOver can't see which card
        // it sits on, so it gets the activity-specific label.
        .accessibilityLabel(type.accessibilityLogLabel)
    }
}

#Preview("Regular") {
    VStack(spacing: 12) {
        TrackerCard(type: .feed, subtitle: "Fed 25 min ago")
        TrackerCard(type: .sleep, subtitle: "Nothing logged yet")
    }
    .padding()
    .background(Theme.background)
}

#Preview("Compact row") {
    HStack(spacing: 12) {
        TrackerCard(type: .poop, subtitle: "Pooped 3h ago", isCompact: true)
        TrackerCard(type: .pee, subtitle: "Peed 40 min ago", isCompact: true)
    }
    .padding()
    .background(Theme.background)
}

#Preview("Accessibility size") {
    TrackerCard(type: .feed, subtitle: "Fed 25 min ago")
        .environment(\.dynamicTypeSize, .accessibility2)
        .padding()
        .background(Theme.background)
}
