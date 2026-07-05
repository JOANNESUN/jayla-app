//
//  ContentView.swift
//  Jayla
//
//  Created by JO on 2/7/2026.
//
//  Root router: first launch (no BabyProfile) shows onboarding; after
//  that, the home dashboard.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [BabyProfile]

    var body: some View {
        if let baby = profiles.first {
            HomeView(baby: baby)
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ActivityEvent.self, BabyProfile.self], inMemory: true)
}
