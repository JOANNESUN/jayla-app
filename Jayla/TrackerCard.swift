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
//  Long-pressing the tile (anywhere but the "+") asks to undo the
//  latest log of that activity — correction without any visible UI.
//

import SwiftUI

struct TrackerCard: View {
    let type: ActivityType
    let count: Int          // times logged today
    // Called when the mom taps the "+". Defaults to a no-op so previews
    // and static uses don't have to supply one.
    var onLog: () -> Void = {}
    // Called when the mom long-presses the tile — "take the last one
    // back". The card only signals intent; HomeView owns the
    // confirmation and the delete.
    var onUndoRequest: () -> Void = {}

    // Glyphs sit next to scaling text, so they scale too. The SVGs are
    // cropped tight (no built-in margins).
    @ScaledMetric(relativeTo: .headline) private var iconSize = 44.0
    @ScaledMetric(relativeTo: .headline) private var plusSize = 28.0

    // Centered column — big icon with the "+" tucked into its corner,
    // count underneath — so nothing fights for width on a half-width
    // tile and the text never wraps on narrower phones.
    var body: some View {
        VStack(spacing: 6) {
            Image(type.icon)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)
                .overlay(alignment: .bottomTrailing) {
                    logButton.offset(x: 20, y: 8)
                }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(count)")
                    .font(Theme.display(32, relativeTo: .title))
                    .foregroundStyle(type.countColor)
                Text("today")
                    .font(Theme.text(13, relativeTo: .caption))
                    .foregroundStyle(Theme.softInk)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(type.label), \(count) today")
            // Long-press is invisible to VoiceOver, so the undo rides
            // along as a custom action on the count element.
            .accessibilityAction(named: "Undo last \(type.label.lowercased())") {
                onUndoRequest()
            }

            // Makes the long-press undo discoverable; silent to VoiceOver
            // (the custom action above already covers it).
            UndoHint()
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(type.borderColor, lineWidth: 2)
        )
        .cardShadow()
        // The "+" keeps winning touches on its own 44pt frame, so a
        // long-press can never double as an accidental log.
        .onLongPressGesture(minimumDuration: 0.5) {
            onUndoRequest()
        }
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
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The button just shows "+"; VoiceOver can't see which card it
        // sits on, so it gets the activity-specific label.
        .accessibilityLabel(type.accessibilityLogLabel)
    }
}

/// The quiet "hold to undo" caption shared by the log surfaces — the feed
/// hero and the poop/pee tiles. Deliberately silent to VoiceOver: each
/// surface already exposes an "Undo last …" custom action.
struct UndoHint: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.tap")
            Text("hold to undo")
        }
        .font(Theme.text(10, relativeTo: .caption2))
        .foregroundStyle(Theme.softInk)
        .accessibilityHidden(true)
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
