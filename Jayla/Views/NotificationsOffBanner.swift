//
//  NotificationsOffBanner.swift
//  Jayla
//
//  Shown on Home only while notifications are DENIED. Provisional auth
//  means most users never see a permission dialog at all — this banner
//  exists for the one unhappy path iOS allows no re-ask for: the user
//  turned Jayla's notifications off in Settings. The app can never
//  flip that switch itself; the closest Apple permits is deep-linking
//  straight to Jayla's own notification settings page, which is what
//  the tap does.
//
//  Whole-banner tap is deliberate (unlike the quick-log tiles, where
//  the "+" is the only target): opening Settings by accident is
//  harmless and reversible, logging a phantom feed is not.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct NotificationsOffBanner: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: openNotificationSettings) {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminders are off")
                        .font(Theme.text(14, .extraBold, relativeTo: .subheadline))
                        .foregroundStyle(Theme.ink)
                    Text("Jayla can't nudge you before feeds and naps — tap to turn them on.")
                        .font(Theme.text(12, relativeTo: .caption))
                        .foregroundStyle(Theme.softInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.softInk)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1.5)
            )
            .cardShadow()
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications are off. Jayla can't remind you "
            + "before feeds and naps. Opens Settings to turn them on.")
    }

    private func openNotificationSettings() {
        #if os(iOS)
        // Lands directly on Settings → Jayla → Notifications (iOS 16+),
        // not just the app's settings root.
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
        #endif
    }
}

#Preview {
    NotificationsOffBanner()
        .padding()
        .background(Theme.background)
}
