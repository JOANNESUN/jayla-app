//
//  BabyHeaderBar.swift
//  Jayla
//
//  The pinned blush header bar — small photo, name, age on one line —
//  shared by the home and history tabs via safeAreaInset. Display-only:
//  the keepsake page owns photo changing and editing.
//

import SwiftUI

struct BabyHeaderBar: View {
    let baby: BabyProfile

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let data = baby.photoData, let image = Image(photoData: data) {
                    image.resizable().scaledToFill()
                } else {
                    Circle()
                        .fill(Theme.feedBadge)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.accent)
                        )
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))

            Text(baby.name)
                .font(Theme.display(20, relativeTo: .title3))
                .foregroundStyle(Theme.ink)
            Text("· \(baby.ageDescription)")
                .font(Theme.text(13, relativeTo: .footnote))
                .foregroundStyle(Theme.softInk)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        // The bar paints up behind the status bar too, so the blush
        // runs to the physical top of the screen.
        .background { Theme.headerBar.ignoresSafeArea(edges: .top) }
    }
}

#Preview {
    ZStack(alignment: .top) {
        Theme.background.ignoresSafeArea()
        BabyHeaderBar(baby: BabyProfile(name: "Jayla",
                                        birthdate: Calendar.current.date(
                                            byAdding: .month, value: -5, to: .now)!))
    }
}
