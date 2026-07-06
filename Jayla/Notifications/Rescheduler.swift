//
//  Rescheduler.swift
//  Jayla
//
//  THE single choke point of the core loop: every write path — an
//  in-app log on the main actor, or the background notification action
//  via BackgroundLogger — ends here. It recomputes the feed prediction
//  and replaces the one pending reminder. Funnel everything through
//  here and the alert can never drift out of sync with the data.
//
//  Two entry points, one core:
//  - recomputeAndReschedule()      main-actor, fetches from mainContext
//  - reschedule(feedTimestamps:…)  plain values, callable from any actor
//

import Foundation
import SwiftData

enum Rescheduler {

    /// Main-actor convenience: re-read the store and reschedule.
    /// Called after in-app logs and on app foreground.
    @MainActor
    static func recomputeAndReschedule(now: Date = .now) async {
        let context = ModelContainerProvider.shared.mainContext
        guard let baby = try? context.fetch(FetchDescriptor<BabyProfile>()).first else {
            NotificationScheduler.cancelFeedReminder()
            return
        }

        let feeds = ActivityRepository(context: context)
            .recentEvents(of: .feed, limit: 20)
            .map(\.timestamp)

        await reschedule(feedTimestamps: feeds,
                         ageBand: baby.ageBand,
                         babyName: baby.name,
                         now: now)
    }

    /// The shared core: predict from plain values and replace the
    /// pending reminder. Takes no models and no context, so the
    /// background actor can call it with values it fetched itself.
    nonisolated static func reschedule(feedTimestamps: [Date],
                                       ageBand: AgeBand,
                                       babyName: String,
                                       now: Date = .now) async {
        #if DEBUG
        // Quick way to test the reminder without waiting hours: set
        // JAYLA_REMINDER_IN_SECONDS in the scheme's Run environment
        // (e.g. 20), log a feed, background the app.
        if let raw = ProcessInfo.processInfo.environment["JAYLA_REMINDER_IN_SECONDS"],
           let seconds = TimeInterval(raw), seconds > 0 {
            await NotificationScheduler.scheduleFeedReminder(
                at: now.addingTimeInterval(seconds),
                babyName: babyName
            )
            return
        }
        #endif

        guard let prediction = PredictionEngine.predict(
            timestamps: feedTimestamps,
            now: now,
            config: .config(for: .feed, ageBand: ageBand)
        ) else {
            NotificationScheduler.cancelFeedReminder()
            return
        }

        await NotificationScheduler.scheduleFeedReminder(
            at: prediction.nextTime,
            babyName: babyName
        )
        #if DEBUG
        print("⏰ [Jayla] Feed reminder scheduled for \(prediction.nextTime.formatted(date: .omitted, time: .standard)) (\(prediction.confidence.label), \(prediction.sampleCount) intervals, blend \(String(format: "%.2f", prediction.priorBlend)))")
        #endif
    }
}
