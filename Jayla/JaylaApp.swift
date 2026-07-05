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
        }
        .modelContainer(ModelContainerProvider.shared)
    }
}
