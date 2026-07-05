//
//  Theme.swift
//  Jayla
//
//  Created by JO on 2/7/2026.
//

import SwiftUI

// SwiftUI has no hex-color initializer built in — everyone writes this
// extension once per project. It parses "F1EFEF" into RGB components.
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue:  Double(rgb & 0xFF) / 255
        )
    }
}

// "Blush" palette — sampled from a terracotta street scene painting:
// warm salmon-pink walls, slate-blue sky and snow shadows, sage
// shopfront, marigold awning. One namespace, used everywhere.
enum Theme {
    static let background = Color(hex: "F6E7E0")   // blush plaster
    static let ink        = Color(hex: "43292A")   // dark rosewood
    static let softInk    = Color(hex: "A88C86")   // faded mortar
    static let accent     = Color(hex: "E07863")   // salmon coral (CTA, alert dot)

    static let feedBadge  = Color(hex: "F8D5C9")   // salmon pink
    static let feedInk    = Color(hex: "D66B57")
    static let sleepBadge = Color(hex: "C4D3DE")   // slate blue
    static let sleepInk   = Color(hex: "5A7890")

    // The old "diaper" palette is split into poop (sage) and pee
    // (marigold), matching the four distinct activities we now track.
    static let poopBadge  = Color(hex: "CCD9AC")
    static let poopInk    = Color(hex: "6E8A4A")
    static let peeBadge   = Color(hex: "F3DEA0")
    static let peeInk     = Color(hex: "C89A34")
}

extension View {
    /// The soft shadow used on Jayla's white cards, in one place so every
    /// surface reads the same.
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}
