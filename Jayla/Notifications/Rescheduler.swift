//
//  Rescheduler.swift
//  Jayla
//
//  THE single choke point of the core loop: every write path — an
//  in-app log today, the background notification action in Phase 4 —
//  ends by calling recomputeAndReschedule(). It re-reads the store,
//  recomputes the feed prediction, and replaces the one pending
//  reminder. Funnel everything through here and the alert can never
//  drift out of sync with the data.
//

import Foundation
import SwiftData

enum Rescheduler {

    /// Recompute the next-feed prediction from the store and replace
    /// the pending reminder (or cancel it when there's nothing to
    /// predict — e.g. no feeds logged yet).
    @MainActor
    static func recomputeAndReschedule(now: Date = .now) async {
        let context = ModelContainerProvider.shared.mainContext
        guard let baby = try? context.fetch(FetchDescriptor<BabyProfile>()).first else {
            NotificationScheduler.cancelFeedReminder()
            return
        }

        #if DEBUG
        // Quick way to test the reminder without waiting hours: set
        // JAYLA_REMINDER_IN_SECONDS in the scheme's Run environment
        // (e.g. 20), log a feed, background the app.
        if let raw = ProcessInfo.processInfo.environment["JAYLA_REMINDER_IN_SECONDS"],
           let seconds = TimeInterval(raw), seconds > 0 {
            await NotificationScheduler.scheduleFeedReminder(
                at: now.addingTimeInterval(seconds),
                babyName: baby.name
            )
            return
        }
        #endif

        let feeds = ActivityRepository(context: context)
            .recentEvents(of: .feed, limit: 20)
            .map(\.timestamp)

        guard let prediction = PredictionEngine.predict(
            timestamps: feeds,
            now: now,
            config: .config(for: .feed, ageBand: baby.ageBand)
        ) else {
            NotificationScheduler.cancelFeedReminder()
            return
        }

        await NotificationScheduler.scheduleFeedReminder(
            at: prediction.nextTime,
            babyName: baby.name
        )
        #if DEBUG
        print("⏰ [Jayla] Feed reminder scheduled for \(prediction.nextTime.formatted(date: .omitted, time: .standard)) (\(prediction.confidence.label), \(prediction.sampleCount) intervals, blend \(String(format: "%.2f", prediction.priorBlend)))")
        #endif
    }
}
