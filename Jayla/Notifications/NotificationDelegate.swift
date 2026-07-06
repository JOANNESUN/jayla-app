//
//  NotificationDelegate.swift
//  Jayla
//
//  UNUserNotificationCenterDelegate. Must be assigned in
//  didFinishLaunching (see AppDelegate) — assigning it in a view's
//  .onAppear is too late for a cold launch from a notification action.
//

import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Show the reminder even while the app is open — mom may be in the
    /// app but looking at a different card.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        #if DEBUG
        print("🔔 [Jayla] reminder FIRED while app in foreground → showing banner")
        #endif
        return [.banner, .sound]
    }

    /// Action taps land here (LOG_FEED / SNOOZE_15 / default open) —
    /// possibly with the app backgrounded or cold-launched, so all data
    /// work goes through the BackgroundLogger actor, never the UI's
    /// main-actor context.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        #if DEBUG
        print("🔔 [Jayla] user responded to reminder: \(response.actionIdentifier)")
        #endif
        switch response.actionIdentifier {
        case NotificationCategories.logFeedAction:
            // Logs the feed AND reschedules the next reminder.
            let logger = BackgroundLogger(modelContainer: ModelContainerProvider.shared)
            await logger.logFeedFromNotification()
            NotificationScheduler.clearBadge()

        case NotificationCategories.snoozeAction:
            // Re-ask in 15 minutes. The baby's name rides in userInfo so
            // snoozing needs no database access at all.
            let name = response.notification.request.content
                .userInfo["babyName"] as? String ?? "Baby"
            await NotificationScheduler.scheduleFeedReminder(
                at: Date.now.addingTimeInterval(15 * 60),
                babyName: name
            )
            NotificationScheduler.clearBadge()

        default:
            // Body tap just opens the app; the foreground scenePhase
            // handler already clears the badge and reschedules.
            break
        }
    }
}
