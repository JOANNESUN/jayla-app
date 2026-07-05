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
    // Base
    static let background = Color(hex: "FFF2D6")   // warm cream
    static let ink        = Color(hex: "3A241F")   // dark painterly brown
    static let softInk    = Color(hex: "8B6A5A")   // warm muted brown for secondary text
    static let accent     = Color(hex: "FF6B5B")   // vibrant coral CTA

    // Feed — pink / coral
    static let feedBadge  = Color(hex: "FFE1EC")   // soft blossom pink background
    static let feedInk    = Color(hex: "FF6FAE")   // vibrant blossom pink

    // Sleep — blue
    static let sleepBadge = Color(hex: "DDF0FF")   // soft sky blue background
    static let sleepInk   = Color(hex: "4DA6FF")   // vibrant sky blue

    // Poop — green
    static let poopBadge  = Color(hex: "DDF7D2")   // fresh green background
    static let poopInk    = Color(hex: "34C759")   // vibrant leaf green

    // Pee — yellow / marigold
    static let peeBadge   = Color(hex: "FFF0B8")   // warm yellow background
    static let peeInk     = Color(hex: "FFC61A")   // vibrant marigold

    // Extra painterly accents from the reference images
    static let lavender   = Color(hex: "8E5EEA")   // vivid lavender
    static let peach      = Color(hex: "FFA34D")   // peach orange
    static let emerald    = Color(hex: "00B88A")   // vivid plant green
    static let cobalt     = Color(hex: "1E5EF5")   // deep blue
    static let brickRed   = Color(hex: "E6322E")   // strong red
}

extension View {
    /// The soft shadow used on Jayla's white cards, in one place so every
    /// surface reads the same.
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}
