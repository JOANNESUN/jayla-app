//
//  BackgroundLogger.swift
//  Jayla
//
//  The background write path. When mom taps "Log feed" on the
//  notification, the app may be backgrounded — or not running at all —
//  so the handler must NOT touch the UI's main-actor ModelContext.
//  @ModelActor gives this actor its own context on its own executor,
//  built from the shared ModelContainer (containers are Sendable,
//  contexts are not) — the supported SwiftData background-write pattern.
//

import Foundation
import SwiftData

@ModelActor
actor BackgroundLogger {

    /// Log a feed triggered by the notification action, then reschedule
    /// the next reminder from this actor's own view of the store.
    func logFeedFromNotification(now: Date = .now) async {
        let feedRaw = ActivityType.feed.rawValue
        let notificationSource = "notification"

        // Idempotency: a double-tap or redelivered action must not create
        // a second event. Skip the insert if we already logged a feed
        // from a notification within the last 2 minutes.
        let cutoff = now.addingTimeInterval(-120)
        var duplicateCheck = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate {
                $0.typeRaw == feedRaw
                    && $0.source == notificationSource
                    && $0.timestamp > cutoff
            }
        )
        duplicateCheck.fetchLimit = 1
        let isDuplicate = !((try? modelContext.fetch(duplicateCheck)) ?? []).isEmpty

        if isDuplicate {
            #if DEBUG
            print("📝 [Jayla] Skipped duplicate notification feed (within 2 min)")
            #endif
        } else {
            let event = ActivityEvent(type: .feed, timestamp: now,
                                      source: notificationSource)
            modelContext.insert(event)
            try? modelContext.save()
            #if DEBUG
            print("📝 [Jayla] Logged Feed at \(now.formatted(date: .omitted, time: .standard)) (source: notification, background)")
            #endif
        }

        // Extract plain values inside the actor — models never cross
        // actor boundaries — and run the shared choke-point reschedule.
        //
        // Deliberately feed-only: the nap notifications (pending_nap /
        // nap_check) are computed purely from sleep data, which logging
        // a feed never changes, so skipping rescheduleNap here is safe.
        // If a notification action ever writes sleep data, that path
        // must also call Rescheduler.rescheduleNap — otherwise a stale
        // "nap time is coming" nudge can fire mid-nap.
        guard let baby = try? modelContext.fetch(FetchDescriptor<BabyProfile>()).first else {
            NotificationScheduler.cancelFeedReminder()
            return
        }
        let babyName = baby.name
        let ageBand = baby.ageBand

        var recentFeeds = FetchDescriptor<ActivityEvent>(
            predicate: #Predicate { $0.typeRaw == feedRaw },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        recentFeeds.fetchLimit = 20
        let timestamps = ((try? modelContext.fetch(recentFeeds)) ?? []).map(\.timestamp)

        await Rescheduler.reschedule(feedTimestamps: timestamps,
                                     ageBand: ageBand,
                                     babyName: babyName,
                                     now: now)
    }
}
