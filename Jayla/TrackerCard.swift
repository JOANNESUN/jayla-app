//
//  TrackerCard.swift
//  Jayla
//
//  Created by JO on 2/7/2026.
//

import SwiftUI

struct TrackerCard: View {
    // These are props. `let` = immutable, passed in via the
    // memberwise initializer Swift generates automatically.
    let icon: String        // SF Symbol name
    let badgeColor: Color
    let inkColor: Color
    let title: String
    let prediction: String
    let confidence: String
    let buttonLabel: String
    // Called when the mom taps the log button. Defaults to a no-op so
    // previews and static uses don't have to supply one.
    var onLog: () -> Void = {}

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(badgeColor)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(inkColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(prediction)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.softInk)
                if !confidence.isEmpty {
                    Text(confidence)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(inkColor)
                }
            }

            Spacer()

            Button {
                onLog()
            } label: {
                Text(buttonLabel)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(inkColor, in: Capsule())
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 34))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

#Preview {
    TrackerCard(
        icon: "drop.fill",
        badgeColor: Theme.feedBadge,
        inkColor: Theme.feedInk,
        title: "Feed",
        prediction: "Next around 2:30 PM",
        confidence: "confident",
        buttonLabel: "Log feed"
    )
    .padding()
    .background(Theme.background)
}
