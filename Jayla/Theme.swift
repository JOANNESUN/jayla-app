//
//  Theme.swift
//  Jayla
//
//  Created by JO on 2/7/2026.
//

import SwiftUI
import CoreText

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
    static let sleepBadge  = Color(hex: "DDF0FF")   // soft sky blue background
    static let sleepInk    = Color(hex: "4DA6FF")   // vibrant sky blue
    static let sleepAccent = Color(hex: "2E6FD6")   // deep blue — DND label + headline
                                                    // numbers, the blue twin of awakeAccent

    // Awake — the gold Start-nap pill is the sunny cue that sets the
    // (white) awake card apart from the blue asleep card at a glance.
    static let awakeButton = Color(hex: "FFBE00")   // gold Start-nap pill (dark ink text)
    static let awakeAccent = Color(hex: "E09A16")   // readable gold for the AWAKE label
                                                    // + the numbers in the headline

    // Poop — warm brown, sampled from the kawaii poop icon
    static let poopInk    = Color(hex: "A6713E")   // icon brown ("+" button, count)
    static let poopBorder = Color(hex: "C69C6D")   // tan ring on the white tile

    // Pee — yellow / marigold
    static let peeInk     = Color(hex: "FFC61A")   // vibrant marigold
    static let peeBorder  = Color(hex: "EFC94C")   // marigold ring on the white tile
    static let peeCount   = Color(hex: "C7771E")   // burnt orange — marigold is
                                                   // too pale to read as text

    // Extra painterly accents from the reference images
    static let lavender   = Color(hex: "8E5EEA")   // vivid lavender
    static let peach      = Color(hex: "FFA34D")   // peach orange
    static let emerald    = Color(hex: "00B88A")   // vivid plant green
    static let cobalt     = Color(hex: "1E5EF5")   // deep blue
    static let brickRed   = Color(hex: "E6322E")   // strong red

    // Keepsake (profile) page — paler cream card + washi-tape tan,
    // sampled from the keepsake reference mock
    static let keepsakeCard = Color(hex: "FDF6E3") // paler cream than background
    static let keepsakeTape = Color(hex: "D9C49A") // washi tape tan
    static let keepsakeDate = Color(hex: "A6512E") // warm terracotta "born …" line

    // Empty 24h tracks on the history charts. Cool light gray on
    // purpose: cream tracks made the whole chart read as one yellow
    // block against the cream page — Joanne's call.
    static let chartTrack = Color(hex: "EEF1F5")

    // The pinned header bar on home/history. Coral won after blush and
    // the icon's marigold both auditioned — Joanne's final call.
    static let headerBar = accent

    // MARK: - Fonts (Baloo 2 display + Nunito body, both SIL OFL)

    // The TTFs live in Jayla/Fonts/ and ship as plain bundle resources.
    // Registered at runtime instead of via Info.plist UIAppFonts: the
    // project generates its Info.plist, and lazy registration also makes
    // fonts work in Xcode previews. `static let` = runs exactly once.
    private static let fontsRegistered: Void = {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf",
                                    subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    /// Nunito weights used by the design. Raw values are the fonts'
    /// PostScript names (verified with CoreText after download).
    enum TextWeight: String {
        case bold      = "Nunito-Bold"
        case extraBold = "Nunito-ExtraBold"
        case black     = "Nunito-Black"
    }

    /// Chunky display font: the baby's name, the countdown, card titles.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        _ = fontsRegistered
        return .custom("Baloo2-ExtraBold", size: size, relativeTo: style)
    }

    /// Body font. Nunito has no true regular in our bundle on purpose —
    /// the design never goes lighter than bold.
    static func text(_ size: CGFloat, _ weight: TextWeight = .bold,
                     relativeTo style: Font.TextStyle) -> Font {
        _ = fontsRegistered
        return .custom(weight.rawValue, size: size, relativeTo: style)
    }

    /// Handwritten font (Caveat, SIL OFL) — keepsake captions only:
    /// "our Jayla 💛" and the "born …" line on the profile page.
    static func handwritten(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        _ = fontsRegistered
        return .custom("Caveat-Bold", size: size, relativeTo: style)
    }
}

extension View {
    /// The soft shadow used on Jayla's white cards, in one place so every
    /// surface reads the same.
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}
