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
//  Note the asymmetry: recomputeAndReschedule refreshes feed AND nap
//  notifications; the background path (BackgroundLogger) calls only the
//  feed half, which is safe while notification actions can only log
//  feeds. A future background write that touches sleep data must also
//  call rescheduleNap.
//

import Foundation
import SwiftData

enum Rescheduler {

    /// Main-actor convenience: re-read the store and reschedule both the
    /// feed reminder and the sleep-state notification.
    /// Called after in-app logs and on app foreground.
    @MainActor
    static func recomputeAndReschedule(now: Date = .now) async {
        let context = ModelContainerProvider.shared.mainContext
        guard let baby = try? context.fetch(FetchDescriptor<BabyProfile>()).first else {
            NotificationScheduler.cancelFeedReminder()
            NotificationScheduler.cancelNapReminder()
            NotificationScheduler.cancelNapCheck()
            return
        }

        let repo = ActivityRepository(context: context)
        let feeds = repo.recentEvents(of: .feed, limit: 20).map(\.timestamp)

        let sleeps = repo.recentEvents(of: .sleep, limit: 20)
        let completedDurations = sleeps.compactMap { event -> (value: TimeInterval, date: Date)? in
            guard let duration = event.durationSeconds, duration > 0 else { return nil }
            return (duration, event.timestamp.addingTimeInterval(duration))
        }

        await reschedule(feedTimestamps: feeds,
                         ageBand: baby.ageBand,
                         babyName: baby.name,
                         now: now)
        await rescheduleNap(napStarts: sleeps.map(\.timestamp),
                            completedDurations: completedDurations,
                            openNapStart: repo.openNap(now: now)?.timestamp,
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

        // Scheduling-side clamp: the prediction may already be in the
        // past (late log); an alert must always be in the future.
        let grace: TimeInterval = 5 * 60
        let fireDate = max(prediction.nextTime, now.addingTimeInterval(grace))

        await NotificationScheduler.scheduleFeedReminder(
            at: fireDate,
            babyName: babyName
        )
        #if DEBUG
        print("⏰ [Jayla] Feed reminder scheduled for \(fireDate.formatted(date: .omitted, time: .standard)) (\(prediction.confidence.label), \(prediction.sampleCount) intervals, blend \(String(format: "%.2f", prediction.priorBlend)))")
        #endif
    }

    /// The sleep-state half of the choke point. Exactly one of the two
    /// nap notifications is ever pending:
    ///   awake  → pending_nap  (lead-time nudge before the predicted nap)
    ///   asleep → nap_check    (runaway guard at ~2× predicted duration)
    nonisolated static func rescheduleNap(napStarts: [Date],
                                          completedDurations: [(value: TimeInterval, date: Date)],
                                          openNapStart: Date?,
                                          ageBand: AgeBand,
                                          babyName: String,
                                          now: Date = .now) async {
        let grace: TimeInterval = 5 * 60

        #if DEBUG
        // Compressed-time testing, like JAYLA_REMINDER_IN_SECONDS for
        // feeds: schedules whichever nap notification the current state
        // calls for, N seconds from now.
        if let raw = ProcessInfo.processInfo.environment["JAYLA_NAP_REMINDER_IN_SECONDS"],
           let seconds = TimeInterval(raw), seconds > 0 {
            if openNapStart != nil {
                NotificationScheduler.cancelNapReminder()
                await NotificationScheduler.scheduleNapCheck(
                    at: now.addingTimeInterval(seconds), babyName: babyName)
            } else {
                NotificationScheduler.cancelNapCheck()
                let start = now.addingTimeInterval(seconds + 15 * 60)
                await NotificationScheduler.scheduleNapReminder(
                    at: now.addingTimeInterval(seconds),
                    babyName: babyName,
                    window: start...start.addingTimeInterval(30 * 60))
            }
            return
        }
        #endif

        if let napStart = openNapStart {
            // Asleep: no pings during the nap (display-only wake estimate)
            // — only the runaway guard, well clear of a normal nap.
            NotificationScheduler.cancelNapReminder()

            // The duration prior always exists, so the fallback is only
            // defensive.
            let duration = PredictionEngine.estimateInterval(
                samples: completedDurations,
                now: now,
                config: .napDurationConfig(ageBand: ageBand)
            )?.expected ?? 1.5 * 3_600

            let checkAt = napStart.addingTimeInterval(max(2 * duration, 2.5 * 3_600))
            let fireDate = max(checkAt, now.addingTimeInterval(grace))
            await NotificationScheduler.scheduleNapCheck(at: fireDate,
                                                         babyName: babyName)
            #if DEBUG
            print("⏰ [Jayla] Nap check scheduled for \(fireDate.formatted(date: .omitted, time: .standard)) (predicted duration \(Int(duration / 60)) min)")
            #endif
        } else {
            NotificationScheduler.cancelNapCheck()

            guard let prediction = PredictionEngine.predict(
                timestamps: napStarts,
                now: now,
                config: .config(for: .sleep, ageBand: ageBand)
            ) else {
                NotificationScheduler.cancelNapReminder()
                return
            }

            // Lead time: the nudge is for starting a wind-down, so it
            // has to land before the predicted window opens, not in it.
            let window = prediction.napWindow(ageBand: ageBand)
            let lead: TimeInterval = 15 * 60
            let fireDate = max(window.lowerBound.addingTimeInterval(-lead),
                               now.addingTimeInterval(grace))
            await NotificationScheduler.scheduleNapReminder(at: fireDate,
                                                            babyName: babyName,
                                                            window: window)
            #if DEBUG
            print("⏰ [Jayla] Nap reminder scheduled for \(fireDate.formatted(date: .omitted, time: .standard)) (\(prediction.confidence.label), \(prediction.sampleCount) intervals)")
            #endif
        }
    }
}
