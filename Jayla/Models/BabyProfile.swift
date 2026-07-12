//
//  BabyProfile.swift
//  Jayla
//
//  The baby. Age is derived from birthdate every time it's read — never
//  stored — so it's always correct and needs no migration as she grows.
//  ageBand feeds the prediction engine's cold-start priors (Phase 2).
//

import Foundation
import SwiftData

@Model
final class BabyProfile {
    var name: String
    var birthdate: Date
    var createdAt: Date
    // Raw string with a declaration-site default so stores created
    // before the field existed migrate in place — those babies (Jayla)
    // were all girls.
    var genderRaw: String = Gender.girl.rawValue
    // JPEG of the baby's profile photo. externalStorage keeps the blob out
    // of the main SQLite store. nil → show a placeholder.
    @Attribute(.externalStorage) var photoData: Data?

    init(name: String, birthdate: Date, gender: Gender = .girl, photoData: Data? = nil) {
        self.name = name
        self.birthdate = birthdate
        self.createdAt = .now
        self.genderRaw = gender.rawValue
        self.photoData = photoData
    }
}

/// Drives the she/he pronouns sprinkled through the app's copy.
enum Gender: String, Codable, CaseIterable {
    case girl, boy

    /// "she" / "he"
    var subject: String { self == .girl ? "she" : "he" }
    /// "her" / "him"
    var object: String { self == .girl ? "her" : "him" }
    /// "her" / "his"
    var possessive: String { self == .girl ? "her" : "his" }
}

// Coarse age bands — only used to seed predictions before real data exists.
enum AgeBand {
    case newborn   // 0–1 month
    case infant    // ~1–4 months
    case older     // 4+ months
}

extension BabyProfile {
    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .girl }
        set { genderRaw = newValue.rawValue }
    }

    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: birthdate, to: .now).day ?? 0
    }

    /// Human-readable age, e.g. "3 weeks old" / "5 months old".
    var ageDescription: String {
        let comps = Calendar.current.dateComponents([.month, .day], from: birthdate, to: .now)
        let months = comps.month ?? 0
        if months <= 0 {
            let days = max(ageInDays, 0)
            let weeks = days / 7
            if weeks < 1 { return "\(days) day\(days == 1 ? "" : "s") old" }
            return "\(weeks) week\(weeks == 1 ? "" : "s") old"
        }
        return "\(months) month\(months == 1 ? "" : "s") old"
    }

    /// Western zodiac from the birthday — free keepsake flair, derived
    /// like age so it never needs storing or migrating.
    var zodiacSign: String {
        let comps = Calendar.current.dateComponents([.month, .day], from: birthdate)
        guard let month = comps.month, let day = comps.day else { return "" }
        switch (month, day) {
        case (3, 21...), (4, ...19):   return "aries"
        case (4, _), (5, ...20):       return "taurus"
        case (5, _), (6, ...20):       return "gemini"
        case (6, _), (7, ...22):       return "cancer"
        case (7, _), (8, ...22):       return "leo"
        case (8, _), (9, ...22):       return "virgo"
        case (9, _), (10, ...22):      return "libra"
        case (10, _), (11, ...21):     return "scorpio"
        case (11, _), (12, ...21):     return "sagittarius"
        case (12, _), (1, ...19):      return "capricorn"
        case (1, _), (2, ...18):       return "aquarius"
        default:                       return "pisces"
        }
    }

    var ageBand: AgeBand {
        switch ageInDays {
        case ..<31:    .newborn
        case 31..<122: .infant
        default:       .older
        }
    }

    /// The keepsake page's age line — same day/week/month thresholds as
    /// ageDescription, but phrased for the scrapbook: "2 days of pure
    /// magic ✨".
    var keepsakeAge: String {
        let comps = Calendar.current.dateComponents([.month, .day], from: birthdate, to: .now)
        let months = comps.month ?? 0
        let amount: String
        if months <= 0 {
            let days = max(ageInDays, 0)
            let weeks = days / 7
            if weeks < 1 {
                amount = "\(days) day\(days == 1 ? "" : "s")"
            } else {
                amount = "\(weeks) week\(weeks == 1 ? "" : "s")"
            }
        } else {
            amount = "\(months) month\(months == 1 ? "" : "s")"
        }
        return "\(amount) of pure magic ✨"
    }
}
