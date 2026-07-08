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
    // JPEG of the baby's profile photo. externalStorage keeps the blob out
    // of the main SQLite store. nil → show a placeholder.
    @Attribute(.externalStorage) var photoData: Data?

    init(name: String, birthdate: Date, photoData: Data? = nil) {
        self.name = name
        self.birthdate = birthdate
        self.createdAt = .now
        self.photoData = photoData
    }
}

// Coarse age bands — only used to seed predictions before real data exists.
enum AgeBand {
    case newborn   // 0–1 month
    case infant    // ~1–4 months
    case older     // 4+ months
}

extension BabyProfile {
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
