//
//  AppDelegate.swift
//  Jayla
//
//  Exists for exactly one reason: the notification delegate and the
//  interactive categories MUST be registered in didFinishLaunching.
//  When the user taps "Log feed" on a reminder with the app killed,
//  iOS cold-launches the app and delivers the action immediately — a
//  delegate assigned later (e.g. in a view's .onAppear) misses it.
//
//  iOS-only: the macOS build (used as a fast type-check target) has no
//  UIApplicationDelegate and simply skips notification wiring.
//

#if os(iOS)
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    // Retained here — UNUserNotificationCenter keeps only a weak
    // reference to its delegate.
    private let notificationDelegate = NotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationDelegate
        NotificationCategories.register(in: center)
        return true
    }
}
#endif
