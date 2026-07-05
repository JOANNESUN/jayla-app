//
//  JaylaApp.swift
//  Jayla
//
//  Created by JO on 2/7/2026.
//

import SwiftUI
import SwiftData

@main
struct JaylaApp: App {
    #if os(iOS)
    // Registers the notification delegate + categories in
    // didFinishLaunching — required for cold launches from an action.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Theme is a fixed light palette (literal hex values, no
                // dark variants), so force light mode. Otherwise system
                // Dark Mode flips default text to white, which disappears
                // against our hardcoded white cards.
                .preferredColorScheme(.light)
                .task {
                    await NotificationScheduler.requestProvisionalAuthorization()
                }
        }
        .modelContainer(ModelContainerProvider.shared)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Coming to the foreground acknowledges any fired reminder,
            // and the pending one may be stale (e.g. a feed was logged
            // from a notification action while we were backgrounded).
            NotificationScheduler.clearBadge()
            Task { await Rescheduler.recomputeAndReschedule() }
        }
    }
}
