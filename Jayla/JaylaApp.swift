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
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Theme is a fixed light palette (literal hex values, no
                // dark variants), so force light mode. Otherwise system
                // Dark Mode flips default text to white, which disappears
                // against our hardcoded white cards.
                .preferredColorScheme(.light)
        }
        .modelContainer(ModelContainerProvider.shared)
    }
}
