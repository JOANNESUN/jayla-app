//
//  GenderPills.swift
//  Jayla
//
//  The gender tab: two capsule pills, girl fills blossom pink and boy
//  fills sky blue — the feed and sleep palettes moonlighting. Shared by
//  onboarding and the profile edit sheet so the two always match.
//

import SwiftUI

struct GenderPills: View {
    @Binding var gender: Gender

    var body: some View {
        HStack(spacing: 8) {
            pill(.girl)
            pill(.boy)
        }
    }

    private func pill(_ option: Gender) -> some View {
        let selected = gender == option
        let ink = option == .girl ? Theme.feedInk : Theme.sleepInk
        let badge = option == .girl ? Theme.feedBadge : Theme.sleepBadge
        return Button {
            guard gender != option else { return }
            gender = option
            Haptics.tap()
        } label: {
            Text(option == .girl ? "Girl" : "Boy")
                .font(Theme.text(14, .extraBold, relativeTo: .subheadline))
                .foregroundStyle(selected ? ink : Theme.softInk)
                .padding(.horizontal, 18)
                .frame(minHeight: 34)
                .background(selected ? badge : .white, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        selected ? ink : Theme.softInk.opacity(0.35),
                        lineWidth: selected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var gender = Gender.girl
    GenderPills(gender: $gender)
        .padding()
        .background(Theme.background)
}
