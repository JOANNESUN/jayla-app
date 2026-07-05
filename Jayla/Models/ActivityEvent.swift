//
//  ActivityEvent.swift
//  Jayla
//
//  One logged activity. `typeRaw` is stored as a String (not the enum
//  directly) so it is trivially queryable in #Predicate and migrates
//  cleanly. `source` distinguishes a tap in the app from a background
//  notification action — used for idempotency in a later phase.
//

import Foundation
import SwiftData

@Model
final class ActivityEvent {
    // TODO(perf): add #Index([\.typeRaw, \.timestamp]) once data volume grows.
    var id: UUID
    var typeRaw: String
    var timestamp: Date            // when the activity happened (start, for sleep)
    var durationSeconds: Double?   // sleep only; nil for feed/poop/pee
    var source: String             // "app" | "notification"
    var createdAt: Date            // insertion time (audit / dedup window)

    var type: ActivityType {
        get { ActivityType(rawValue: typeRaw) ?? .feed }
        set { typeRaw = newValue.rawValue }
    }

    init(type: ActivityType,
         timestamp: Date = .now,
         durationSeconds: Double? = nil,
         source: String = "app") {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.timestamp = timestamp
        self.durationSeconds = durationSeconds
        self.source = source
        self.createdAt = .now
    }
}
