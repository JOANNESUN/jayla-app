//
//  NotificationCategories.swift
//  Jayla
//
//  The interactive category attached to every feed reminder. Long-
//  pressing the notification shows the actions:
//
//  - LOG_FEED  — declared WITHOUT .foreground, so in Phase 4 it can log
//    the feed in the background without opening the app.
//  - SNOOZE_15 — re-ask in 15 minutes.
//
//  Registered once at launch by AppDelegate (categories must be set
//  before a notification using them is delivered).
//

import UserNotifications

nonisolated enum NotificationCategories {
    static let feedReminder = "FEED_REMINDER"
    static let logFeedAction = "LOG_FEED"
    static let snoozeAction = "SNOOZE_15"

    static func register(in center: UNUserNotificationCenter) {
        let logFeed = UNNotificationAction(
            identifier: logFeedAction,
            title: "Log feed",
            options: [] // no .foreground → handled in the background
        )
        let snooze = UNNotificationAction(
            identifier: snoozeAction,
            title: "Snooze 15 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: feedReminder,
            actions: [logFeed, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }
}
