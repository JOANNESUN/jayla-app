//
//  ContentView.swift
//  Jayla
//
//  Created by JO on 2/7/2026.
//
//  Root router: first launch (no BabyProfile) shows onboarding; after
//  that, two tabs — the Today dashboard and the history page.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [BabyProfile]
    @State private var tab = ContentView.initialTab

    // Dev-only: JAYLA_OPEN_HISTORY=1 (or =month) launches straight into
    // the history tab so headless simulator runs can read its console
    // dump and screenshot either page.
    private static var initialTab: Int {
        #if DEBUG
        ProcessInfo.processInfo.environment["JAYLA_OPEN_HISTORY"] != nil ? 1 : 0
        #else
        0
        #endif
    }

    var body: some View {
        if let baby = profiles.first {
            TabView(selection: $tab) {
                HomeView(baby: baby)
                    .tabItem { Label("Today", systemImage: "sun.max.fill") }
                    .tag(0)
                HistoryView()
                    .tabItem { Label("History", systemImage: "calendar") }
                    .tag(1)
            }
            .tint(Theme.accent)
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ActivityEvent.self, BabyProfile.self], inMemory: true)
}
