//
//  HomeView.swift
//  Jayla
//
//  The main dashboard: greeting, next-feed reminder card, round baby
//  photo, then the four log cards (poop + pee share a compact row).
//  Shown by ContentView once a BabyProfile exists. Tapping the photo
//  opens the picker to replace the picture — it's the only entry point
//  now that the header avatar is gone.
//

import SwiftUI
import SwiftData
import PhotosUI

struct HomeView: View {
    let baby: BabyProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    @State private var pickerItem: PhotosPickerItem?

    // The status badge sits next to scaling text, so it scales too.
    @ScaledMetric(relativeTo: .title3) private var statusBadgeSize = 48.0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // everyMinute keeps the countdown and predictions fresh
            // while the app is open; logging triggers @Query updates.
            TimelineView(.everyMinute) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        statusCard(now: timeline.date)
                        photoCircle
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

    // One calm line: name and age together, no buttons competing.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Hello, \(baby.name)!")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(baby.ageDescription)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.softInk)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Status card

    // The ONE place the next-feed prediction lives (the tracker cards
    // only show what already happened). The little bell marks the
    // honest contract: this is the prediction that will remind you.
    // First card on the screen so the photo never pushes it around.
    private func statusCard(now: Date) -> some View {
        let nextFeed = prediction(for: .feed, now: now)
        // Same 60-second threshold countdownText uses for "any time now",
        // so the color shift and the copy always agree.
        let overdue = nextFeed.map { $0.nextTime.timeIntervalSince(now) <= 60 } ?? false
        // At accessibility text sizes the row runs out of width and the
        // countdown drops below the text instead of truncating it.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 14))
        return layout {
            HStack(spacing: 14) {
                Circle()
                    .fill(Theme.feedBadge)
                    .frame(width: statusBadgeSize, height: statusBadgeSize)
                    .overlay(
                        Image(ActivityType.feed.mascot)
                            .resizable()
                            .scaledToFit()
                            .padding(5)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("Next feed")
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if nextFeed != nil {
                            Image(systemName: "bell.fill")
                                .font(.caption2)
                                .foregroundStyle(Theme.softInk)
                        }
                    }
                    Text(nextFeed.map { statusLine(for: $0, overdue: overdue) }
                        ?? "Log the first feed to start predictions")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.softInk)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let nextFeed {
                Text(countdownText(to: nextFeed.nextTime, from: now))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(overdue ? Theme.accent : Theme.feedInk)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 6)
        // One spoken sentence — the bell glyph, caveat, and countdown
        // are meaningless as separate VoiceOver stops.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusAccessibilityLabel(for: nextFeed, now: now))
    }

    /// "Around 10:52 PM", with a gentle caveat only while the engine
    /// isn't confident yet. Once the time has passed, it's a past fact:
    /// "Expected around 10:52 PM".
    private func statusLine(for prediction: Prediction, overdue: Bool) -> String {
        let time = "\(overdue ? "Expected around" : "Around") \(timeText(prediction.nextTime))"
        switch prediction.confidence {
        case .confident: return time
        case .roughly:   return time + " · rough guess"
        case .learning:  return time + " · still learning"
        }
    }

    private func statusAccessibilityLabel(for prediction: Prediction?, now: Date) -> String {
        guard let prediction else {
            return "Next feed. Log the first feed to start predictions."
        }
        let caveat: String
        switch prediction.confidence {
        case .confident: caveat = ""
        case .roughly:   caveat = ", rough guess"
        case .learning:  caveat = ", still learning"
        }
        return "Next feed around \(timeText(prediction.nextTime))\(caveat). "
            + "\(spokenCountdown(to: prediction.nextTime, from: now)). "
            + "Jayla will remind you."
    }

    // MARK: - Photo

    // Fixed size on purpose: it's a picture, not text — Dynamic Type
    // shouldn't inflate it.
    private var photoCircle: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Group {
                if let data = baby.photoData, let image = Image(photoData: data) {
                    image.resizable().scaledToFill()
                } else {
                    Circle()
                        .fill(Theme.sleepBadge)
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "figure.child")
                                    .font(.system(size: 36))
                                Text("Tap to add a photo")
                                    .font(.system(.footnote, design: .rounded))
                            }
                            .foregroundStyle(Theme.sleepInk)
                        )
                }
            }
            .frame(width: 150, height: 150)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 4))
            .shadow(color: .black.opacity(0.08), radius: 15, y: 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(baby.photoData == nil
            ? "Add a photo of \(baby.name)" : "\(baby.name)'s photo")
        .accessibilityHint("Chooses a new photo")
    }

    // MARK: - Trackers

    // Tracker cards state only what already happened — one glance, one
    // fact. All prediction talk lives in the status card above. Feed
    // and sleep get full rows; poop and pee matter less, so they share
    // one — except at accessibility sizes, where half-width cards
    // can't fit their text and the pair stacks.
    private func trackers(now: Date) -> some View {
        let pairLayout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return VStack(spacing: 12) {
            TrackerCard(type: .feed, subtitle: subtitle(for: .feed, now: now),
                        onLog: { log(.feed) })
            TrackerCard(type: .sleep, subtitle: subtitle(for: .sleep, now: now),
                        onLog: { log(.sleep) })
            pairLayout {
                TrackerCard(type: .poop, subtitle: subtitle(for: .poop, now: now),
                            isCompact: true, onLog: { log(.poop) })
                TrackerCard(type: .pee, subtitle: subtitle(for: .pee, now: now),
                            isCompact: true, onLog: { log(.pee) })
            }
        }
    }

    // MARK: - Data helpers

    private func lastEvent(_ type: ActivityType) -> ActivityEvent? {
        events.first { $0.type == type }
    }

    private func subtitle(for type: ActivityType, now: Date) -> String {
        guard let last = lastEvent(type) else { return "Nothing logged yet" }
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

    /// countdownText spelled out for VoiceOver — "in 1h 5m" reads as
    /// letters, "in 1 hour 5 minutes" reads as time.
    private func spokenCountdown(to date: Date, from now: Date) -> String {
        let remaining = date.timeIntervalSince(now)
        guard remaining > 60 else { return "Any time now" }
        let minutes = Int(remaining / 60)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 {
            let h = "\(hours) hour\(hours == 1 ? "" : "s")"
            return rest == 0 ? "In \(h)" : "In \(h) \(rest) minutes"
        }
        return "In \(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}
