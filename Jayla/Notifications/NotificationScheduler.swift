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

// nonisolated: UNUserNotificationCenter is thread-safe, and both the
// main actor (in-app logs) and BackgroundLogger (notification actions)
// call in here.
nonisolated enum NotificationScheduler {
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
        // Lets the snooze action rebuild the reminder without touching
        // the database.
        content.userInfo = ["babyName": babyName]
        // .timeSensitive (pierces Focus/DND) needs an entitlement that
        // personal (free) dev teams cannot provision — Apple rejects the
        // profile outright. Revisit if the account ever moves to a paid
        // Apple Developer membership.
        content.interruptionLevel = .active

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

    #if DEBUG
    /// Print the authorization + delivery settings and what's pending —
    /// run from Xcode and read the console to see what iOS will actually
    /// do with our reminder.
    static func debugDumpStatus() async {
        let center = UNUserNotificationCenter.current()
        let s = await center.notificationSettings()
        print("🔔 [Jayla] notif auth: \(name(of: s.authorizationStatus))"
            + " · alerts: \(name(of: s.alertSetting))"
            + " · lock screen: \(name(of: s.lockScreenSetting))"
            + " · notif center: \(name(of: s.notificationCenterSetting))"
            + " · sound: \(name(of: s.soundSetting))")
        let pending = await center.pendingNotificationRequests()
        if pending.isEmpty {
            print("🔔 [Jayla] no pending reminder")
        }
        for request in pending {
            let fire = (request.trigger as? UNCalendarNotificationTrigger)?
                .nextTriggerDate()?
                .formatted(date: .omitted, time: .standard) ?? "?"
            print("🔔 [Jayla] pending '\(request.identifier)' → fires \(fire)")
        }
    }

    private static func name(of status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined"
        case .denied: "DENIED"
        case .authorized: "authorized"
        case .provisional: "provisional (quiet)"
        case .ephemeral: "ephemeral"
        @unknown default: "unknown"
        }
    }

    private static func name(of setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: "n/a"
        case .disabled: "OFF"
        case .enabled: "on"
        @unknown default: "unknown"
        }
    }
    #endif

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
