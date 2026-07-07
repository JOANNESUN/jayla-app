//
//  TrackerCard.swift
//  Jayla
//
//  Created by JO on 2/7/2026.
//
//  One quick-log tile of the instants grid (poop/pee — the live
//  activities feed and sleep have their own hero cards): white tile
//  ringed in the activity color, kawaii icon top-left, colored "+"
//  log button top-right, then the day's count.
//  Deliberately no "when": parents only care how many times the baby
//  went today, and every event still stores its timestamp for later
//  analysis.
//

import SwiftUI

struct TrackerCard: View {
    let type: ActivityType
    let count: Int          // times logged today
    // Called when the mom taps the "+". Defaults to a no-op so previews
    // and static uses don't have to supply one.
    var onLog: () -> Void = {}

    // Glyphs sit next to scaling text, so they scale too. The SVGs are
    // cropped tight (no built-in margins), so 48pt reads bigger than
    // the old 56pt box did.
    @ScaledMetric(relativeTo: .headline) private var iconSize = 48.0
    @ScaledMetric(relativeTo: .headline) private var plusSize = 28.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(type.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .accessibilityHidden(true)

                Spacer()

                logButton
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(count)")
                    .font(Theme.display(36, relativeTo: .title))
                    .foregroundStyle(type.countColor)
                Text("today")
                    .font(Theme.text(13, relativeTo: .caption))
                    .foregroundStyle(Theme.softInk)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(type.label), \(count) today")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(type.borderColor, lineWidth: 2)
        )
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
        TrackerCard(type: .poop, count: 3)
        TrackerCard(type: .pee, count: 5)
    }
    .padding()
    .background(Theme.background)
}

#Preview("Accessibility size") {
    TrackerCard(type: .poop, count: 3)
        .environment(\.dynamicTypeSize, .accessibility2)
        .padding()
        .background(Theme.background)
}
