//
//  ActivityRepository.swift
//  Jayla
//
//  Thin @MainActor wrapper over the UI's ModelContext. Views and view
//  models talk to this instead of touching FetchDescriptors directly.
//  Every prediction query pulls only a recent window (fetchLimit), never
//  full history — the query-layer half of the "don't regress as she
//  grows" story.
//

import Foundation
import SwiftData

@MainActor
final class ActivityRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func log(_ type: ActivityType,
             at time: Date = .now,
             durationSeconds: Double? = nil,
             source: String = "app") -> ActivityEvent {
        let event = ActivityEvent(type: type,
                                  timestamp: time,
                                  durationSeconds: durationSeconds,
                                  source: source)
        context.insert(event)
        try? context.save()
        #if DEBUG
        print("📝 [Jayla] Logged \(type.label) at \(time.formatted(date: .omitted, time: .standard)) (source: \(source))")
        #endif
        return event
    }

    #if DEBUG
    /// Dump the whole store to the Xcode console — dev visibility only,
    /// called on launch. Not compiled into Release builds.
    func debugDumpAll() {
        let descriptor = FetchDescriptor<ActivityEvent>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        print("══════════ [Jayla] data dump: \(all.count) event\(all.count == 1 ? "" : "s") ══════════")
        for event in all {
            let day = event.timestamp.formatted(date: .abbreviated, time: .omitted)
            let time = event.timestamp.formatted(date: .omitted, time: .standard)
            print("  \(event.type.label.padding(toLength: 6, withPad: " ", startingAt: 0)) \(day) \(time)  [\(event.source)]")
        }
        print("═══════════════════════════════════════════════")
    }
    #endif

    func recentEvents(of type: ActivityType, limit: Int = 20) -> [ActivityEvent] {
        let raw = type.rawValue
        var descriptor = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { $0.typeRaw == raw },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func lastEvent(of type: ActivityType) -> ActivityEvent? {
        recentEvents(of: type, limit: 1).first
    }

    /// Undo the most recent log of a type.
    func deleteLatest(of type: ActivityType) {
        guard let last = lastEvent(of: type) else { return }
        context.delete(last)
        try? context.save()
    }
}
