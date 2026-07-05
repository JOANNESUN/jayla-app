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
        [.banner, .sound]
    }

    /// Action taps land here (LOG_FEED / SNOOZE_15 / default open).
    /// Phase 4 routes LOG_FEED through a @ModelActor BackgroundLogger so
    /// it can write with the app killed; until then actions just dismiss.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Phase 4: background logging + snooze land here.
    }
}
