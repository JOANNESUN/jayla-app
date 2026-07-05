//
//  NotificationScheduler.swift
//  Jayla
//
//  Owns the ONE pending feed reminder. The identifier is stable
//  ("pending_feed"), so rescheduling is cancel + re-add — inherently
//  idempotent, notifications can never accumulate.
//
//  Authorization is provisional-first: reminders start delivering
//  quietly to Notification Center with zero permission friction. A
//  prominent-alert promotion affordance comes in Phase 5.
//

import Foundation
import UserNotifications

enum NotificationScheduler {
    static let pendingFeedID = "pending_feed"

    /// Ask once, quietly. Provisional auth shows no permission dialog;
    /// if the user has explicitly denied, this never re-asks.
    static func requestProvisionalAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(
            options: [.alert, .sound, .badge, .provisional]
        )
    }

    /// Replace the pending feed reminder with one at `date`.
    /// No-op when notifications are denied — the app degrades to a
    /// manual tracker with the in-app countdown still working.
    static func scheduleFeedReminder(at date: Date, babyName: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }

        let content = UNMutableNotificationContent()
        content.title = "\(babyName) may be getting hungry 🍼"
        content.body = "Next feed predicted around "
            + date.formatted(date: .omitted, time: .shortened)
            + ". Long-press to log it."
        content.sound = .default
        content.badge = 1 // cleared when the app comes to the foreground
        content.categoryIdentifier = NotificationCategories.feedReminder
        content.threadIdentifier = "feed"
        // Pierces Focus/DND — a hungry baby doesn't wait. Requires the
        // time-sensitive entitlement (Jayla.entitlements); without it the
        // system quietly downgrades to a normal alert.
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components,
                                                    repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: [pendingFeedID])
        try? await center.add(UNNotificationRequest(identifier: pendingFeedID,
                                                    content: content,
                                                    trigger: trigger))
    }

    static func cancelFeedReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [pendingFeedID])
    }

    /// Badge means "there's an unacknowledged reminder" — clear it
    /// whenever the app comes to the foreground.
    static func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
