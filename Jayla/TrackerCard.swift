//
//  TrackerCard.swift
//  Jayla
//
//  Created by JO on 2/7/2026.
//
//  One quick-log tile of the instants grid (poop/pee — the live
//  activities feed and sleep have their own hero cards): mascot badge
//  top-left, colored "+" log button top-right, then the activity name
//  and the last-happened fact.
//

import SwiftUI

struct TrackerCard: View {
    let type: ActivityType
    let subtitle: String    // what already happened, e.g. "25 min ago"
    // Called when the mom taps the "+". Defaults to a no-op so previews
    // and static uses don't have to supply one.
    var onLog: () -> Void = {}

    // Badges hold glyphs next to scaling text, so they scale too.
    @ScaledMetric(relativeTo: .headline) private var badgeSize = 42.0
    @ScaledMetric(relativeTo: .headline) private var plusSize = 28.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
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

                Spacer()

                logButton
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(type.label)
                    .font(Theme.display(17, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(Theme.text(12, relativeTo: .caption))
                    .foregroundStyle(Theme.softInk)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .cardShadow()
    }

    // The "+" is the ONLY tap target — a whole-card button logs by
    // accident when a tired parent scrolls one-handed.
    private var logButton: some View {
        Button {
            onLog()
        } label: {
            Image(systemName: "plus")
                .font(.system(.footnote, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: plusSize, height: plusSize)
                .background(type.inkColor, in: Circle())
                // Keep the visual small but the touch target ≥ 44pt.
                .frame(width: 44, height: 44, alignment: .topTrailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The button just shows "+"; VoiceOver can't see which card it
        // sits on, so it gets the activity-specific label.
        .accessibilityLabel(type.accessibilityLogLabel)
    }
}

#Preview("Instants grid") {
    let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    return LazyVGrid(columns: columns, spacing: 14) {
        TrackerCard(type: .poop, subtitle: "3h ago")
        TrackerCard(type: .pee, subtitle: "Nothing logged yet")
    }
    .padding()
    .background(Theme.background)
}

#Preview("Accessibility size") {
    TrackerCard(type: .poop, subtitle: "25 min ago")
        .environment(\.dynamicTypeSize, .accessibility2)
        .padding()
        .background(Theme.background)
}
