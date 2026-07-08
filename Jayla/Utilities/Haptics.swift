//
//  Haptics.swift
//  Jayla
//
//  The two haptic voices Jayla speaks, in one place so every button
//  feels the same. Logging is the app's whole loop, so each log action
//  answers with a soft physical "got it" — the Duolingo pattern: touch
//  confirms faster than the eye can find the count tick up.
//
//  Haptics are iPhone-hardware-only; the os(iOS) guards keep the fast
//  macOS type-check build compiling (simulators silently no-op anyway).
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum Haptics {
    /// Soft tap for every log action — feed, poop, pee, start nap.
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// The wake-up payoff: a nap just completed and its duration was
    /// saved — a "success" buzz, warmer than a plain tap.
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
