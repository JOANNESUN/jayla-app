//
//  HomeView.swift
//  Jayla
//
//  The main dashboard: greeting + baby photo hero + the four log cards.
//  Shown by ContentView once a BabyProfile exists. Tapping the hero photo
//  or the header avatar opens the photo picker to replace the picture.
//

import SwiftUI
import SwiftData
import PhotosUI

struct HomeView: View {
    let baby: BabyProfile

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // everyMinute keeps the countdown and predictions fresh
            // while the app is open; logging triggers @Query updates.
            TimelineView(.everyMinute) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        hero(now: timeline.date)
                        trackers(now: timeline.date)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await applyPickedPhoto(item) }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hello,")
                    .font(.system(size: 18, design: .rounded))
                    .foregroundStyle(Theme.softInk)
                Text("\(baby.name)!")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(baby.ageDescription)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Theme.softInk)
            }

            Spacer()

            HStack(spacing: 12) {
                avatar

                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 10, height: 10)
                        .offset(x: -4, y: 4)
                }
            }
        }
        .padding(.top, 8)
    }

    // Tapping the avatar opens the picker to replace the photo.
    private var avatar: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Group {
                if let data = baby.photoData, let image = Image(photoData: data) {
                    image.resizable().scaledToFill()
                } else {
                    Circle()
                        .fill(Theme.sleepBadge)
                        .overlay(
                            Text(String(baby.name.prefix(1)))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.sleepInk)
                        )
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
        }
    }

    // MARK: - Hero

    private func hero(now: Date) -> some View {
        ZStack(alignment: .bottom) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                photoBlock
            }
            .buttonStyle(.plain)

            statusCard(now: now)
                .padding(.horizontal, 16)
                .offset(y: 28)
        }
        .padding(.bottom, 28) // reserve space for the offset overhang
    }

    private var photoBlock: some View {
        Group {
            if let data = baby.photoData, let image = Image(photoData: data) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 34))
            } else {
                RoundedRectangle(cornerRadius: 34)
                    .fill(Theme.sleepBadge)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "figure.child")
                                .font(.system(size: 60))
                            Text("Tap to add a photo")
                                .font(.system(size: 14, design: .rounded))
                        }
                        .foregroundStyle(Theme.sleepInk)
                    )
            }
        }
    }

    // The ONE place the next-feed prediction lives (the tracker cards
    // only show what already happened). The little bell marks the
    // honest contract: this is the prediction that will remind you.
    private func statusCard(now: Date) -> some View {
        let nextFeed = prediction(for: .feed, now: now)
        return HStack(spacing: 14) {
            Circle()
                .fill(Theme.feedBadge)
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Theme.feedInk)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("Next feed")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    if nextFeed != nil {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.softInk)
                            .accessibilityLabel("will remind you")
                    }
                }
                Text(nextFeed.map { statusLine(for: $0) }
                    ?? "Log the first feed to start predictions")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.softInk)
            }

            Spacer()

            if let nextFeed {
                Text(countdownText(to: nextFeed.nextTime, from: now))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.feedInk)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 6)
    }

    /// "Around 10:52 PM", with a gentle caveat only while the engine
    /// isn't confident yet. Once confident, the time stands alone.
    private func statusLine(for prediction: Prediction) -> String {
        let time = "Around \(timeText(prediction.nextTime))"
        switch prediction.confidence {
        case .confident: return time
        case .roughly:   return time + " · rough guess"
        case .learning:  return time + " · still learning"
        }
    }

    // MARK: - Trackers

    // Tracker cards state only what already happened — one glance, one
    // fact. All prediction talk lives in the status card above.
    private func trackers(now: Date) -> some View {
        VStack(spacing: 14) {
            ForEach(ActivityType.allCases) { type in
                TrackerCard(
                    icon: type.icon,
                    badgeColor: type.badgeColor,
                    inkColor: type.inkColor,
                    title: type.label,
                    subtitle: subtitle(for: type, now: now),
                    buttonLabel: type.logButtonLabel,
                    onLog: { log(type) }
                )
            }
        }
    }

    // MARK: - Data helpers

    private func lastEvent(_ type: ActivityType) -> ActivityEvent? {
        events.first { $0.type == type }
    }

    private func subtitle(for type: ActivityType, now: Date) -> String {
        guard let last = lastEvent(type) else { return "Tap to log the first one" }
        return "\(type.pastTense) \(humanTime(since: last.timestamp, now: now))"
    }

    private func prediction(for type: ActivityType, now: Date) -> Prediction? {
        PredictionEngine.predict(
            timestamps: events.filter { $0.typeRaw == type.rawValue }.map(\.timestamp),
            now: now,
            config: .config(for: type, ageBand: baby.ageBand)
        )
    }

    private func log(_ type: ActivityType) {
        ActivityRepository(context: modelContext).log(type)
        // Only feeds drive a notification; the choke point re-reads the
        // store, so it must run after the save above.
        if type == .feed {
            Task { await Rescheduler.recomputeAndReschedule() }
        }
    }

    private func applyPickedPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = PhotoProcessing.downscaledJPEG(from: data) else { return }
        baby.photoData = jpeg
        try? modelContext.save()
    }

    // MARK: - Formatting

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Coarse, calm relative time: "just now" under a minute, then
    /// minutes/hours — never ticking seconds, never "Last now".
    private func humanTime(since date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours < 24 {
            return rest == 0 ? "\(hours)h ago" : "\(hours)h \(rest)m ago"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// "in 1h 5m" / "in 12m" — or "any time now" once the predicted
    /// time has passed (predictions are honest, not clamped).
    private func countdownText(to date: Date, from now: Date) -> String {
        let remaining = date.timeIntervalSince(now)
        guard remaining > 60 else { return "any time now" }
        let minutes = Int(remaining / 60)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 {
            return rest == 0 ? "in \(hours)h" : "in \(hours)h \(rest)m"
        }
        return "in \(minutes)m"
    }
}
