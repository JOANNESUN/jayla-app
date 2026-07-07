//
//  HomeView.swift
//  Jayla
//
//  The "Today dashboard" (design 1a): photo + greeting header, a
//  countdown hero card that owns the next-feed prediction, then a 2×2
//  quick-log grid. Logging sits above the fold — the countdown and its
//  cycle progress bar are the reward that keeps the logging loop going.
//  Tapping the header photo opens the picker to replace the picture.
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
    // The running nap being backdated via the "since 2:40 · adjust" row.
    @State private var adjustingNap: ActivityEvent?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // everyMinute keeps the countdown, progress bar and
            // predictions fresh while the app is open; logging
            // triggers @Query updates.
            TimelineView(.everyMinute) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        heroCard(now: timeline.date)
                        Text("Quick log")
                            .font(Theme.display(17, relativeTo: .headline))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 2)
                        quickLogGrid(now: timeline.date)
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
        .sheet(item: $adjustingNap) { nap in
            NapAdjustSheet(napStart: nap.timestamp) { newStart in
                ActivityRepository(context: modelContext)
                    .adjustNapStart(nap, to: newStart)
                // The runaway check is anchored to the start time.
                Task { await Rescheduler.recomputeAndReschedule() }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            photoCircle
            VStack(alignment: .leading, spacing: 1) {
                Text(baby.name)
                    .font(Theme.display(22, relativeTo: .title2))
                    .foregroundStyle(Theme.ink)
                Text(baby.ageDescription)
                    .font(Theme.text(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.softInk)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.top, 8)
    }

    // The photo is the one place to change the picture. Fixed size on
    // purpose: it's an image, not text — Dynamic Type shouldn't inflate it.
    private var photoCircle: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Group {
                if let data = baby.photoData, let image = Image(photoData: data) {
                    image.resizable().scaledToFill()
                } else {
                    Circle()
                        .fill(Theme.sleepBadge)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.sleepInk)
                        )
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .cardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(baby.photoData == nil
            ? "Add a photo of \(baby.name)" : "\(baby.name)'s photo")
        .accessibilityHint("Chooses a new photo")
    }

    // MARK: - Hero card

    // The ONE place the next-feed prediction lives (the quick-log cards
    // only show what already happened). The little bell marks the
    // honest contract: this is the prediction that will remind you.
    private func heroCard(now: Date) -> some View {
        let nextFeed = prediction(for: .feed, now: now)
        // Same 60-second threshold heroCountdown uses for "any time
        // now", so the full bar and the copy always agree.
        let overdue = nextFeed.map { $0.nextTime.timeIntervalSince(now) <= 60 } ?? false
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("NEXT FEED")
                    .font(Theme.text(12, .black, relativeTo: .caption))
                    .tracking(1.5)
                    .foregroundStyle(Theme.feedInk)
                if nextFeed != nil {
                    Image(systemName: "bell.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.feedInk)
                }
            }

            if let nextFeed {
                Text(heroCountdown(to: nextFeed.nextTime, from: now))
                    .font(overdue ? Theme.display(30, relativeTo: .title)
                                  : Theme.display(52, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 4)
                Text(statusLine(for: nextFeed, overdue: overdue))
                    .font(Theme.text(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.softInk)

                if let lastFeed = lastEvent(.feed) {
                    cycleBar(lastFeed: lastFeed, prediction: nextFeed, now: now)
                        .padding(.top, 16)
                    HStack {
                        Text("\(ActivityType.feed.pastTense) \(humanTime(since: lastFeed.timestamp, now: now))")
                        Spacer()
                        Text(cycleText(nextFeed.expectedInterval))
                    }
                    .font(Theme.text(11, relativeTo: .caption2))
                    .foregroundStyle(Theme.softInk)
                    .padding(.top, 6)
                }
            } else {
                Text("Log the first feed to start predictions")
                    .font(Theme.text(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.softInk)
                    .padding(.top, 8)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Decorative blush circle peeking from the corner; drawn over
        // the white fill, clipped with it.
        .background(alignment: .topTrailing) {
            Circle()
                .fill(Theme.feedBadge)
                .frame(width: 120, height: 120)
                .offset(x: 20, y: -30)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 6)
        // One spoken sentence — the bell glyph, caveat, bar and
        // countdown are meaningless as separate VoiceOver stops.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(heroAccessibilityLabel(for: nextFeed, now: now))
    }

    /// How far through the feed cycle we are, as a bar. Full = overdue.
    private func cycleBar(lastFeed: ActivityEvent, prediction: Prediction, now: Date) -> some View {
        let elapsed = now.timeIntervalSince(lastFeed.timestamp)
        let fraction = min(max(elapsed / prediction.expectedInterval, 0.02), 1)
        return GeometryReader { geo in
            Capsule()
                .fill(Theme.feedBadge)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * fraction)
                }
        }
        .frame(height: 8)
    }

    /// "~2h cycle" / "~2h 30m cycle" — the learned feed spacing.
    private func cycleText(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 {
            return rest == 0 ? "~\(hours)h cycle" : "~\(hours)h \(rest)m cycle"
        }
        return "~\(minutes)m cycle"
    }

    /// The big number: "1h 5m" / "12m" — or "any time now" once the
    /// predicted time has passed (predictions are honest, not clamped).
    private func heroCountdown(to date: Date, from now: Date) -> String {
        let remaining = date.timeIntervalSince(now)
        guard remaining > 60 else { return "any time now" }
        let minutes = Int(remaining / 60)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 {
            return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
        }
        return "\(minutes)m"
    }

    /// "around 10:52 PM", with a gentle caveat only while the engine
    /// isn't confident yet. Once the time has passed, it's a past fact:
    /// "expected around 10:52 PM".
    private func statusLine(for prediction: Prediction, overdue: Bool) -> String {
        "\(overdue ? "expected around" : "around") \(timeText(prediction.nextTime))"
            + caveat(prediction.confidence)
    }

    /// The gentle honesty suffix, shown only while the engine isn't
    /// confident yet.
    private func caveat(_ confidence: PredictionConfidence) -> String {
        switch confidence {
        case .confident: ""
        case .roughly:   " · rough guess"
        case .learning:  " · still learning"
        }
    }

    private func heroAccessibilityLabel(for prediction: Prediction?, now: Date) -> String {
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

    // MARK: - Quick log

    // Quick-log cards state only what already happened — one glance,
    // one fact. All prediction talk lives in the hero card above. At
    // accessibility text sizes half-width tiles can't fit their text,
    // so the grid collapses to one column.
    private func quickLogGrid(now: Date) -> some View {
        let columns = typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(ActivityType.allCases) { type in
                if type == .sleep {
                    sleepCard(now: now)
                } else {
                    TrackerCard(
                        type: type,
                        subtitle: subtitle(for: type, now: now),
                        onLog: { log(type) }
                    )
                }
            }
        }
    }

    // Sleep is a state, so its card is a toggle: awake shows "+" (start
    // nap) and the next-nap estimate; asleep shows the elapsed time, the
    // wake estimate, a backdate row, and a sun button to end the nap.
    // Sleep predictions live here, not in the hero — one place per fact.
    @ViewBuilder
    private func sleepCard(now: Date) -> some View {
        if let nap = openNap(now: now) {
            TrackerCard(
                type: .sleep,
                subtitle: "Asleep \(elapsedText(since: nap.timestamp, now: now))",
                detail: wakeDetail(for: nap, now: now),
                logIcon: "sun.max.fill",
                logLabel: "Wake up",
                onLog: { wakeUp(nap) },
                adjust: ("since \(timeText(nap.timestamp)) · adjust",
                         { adjustingNap = nap })
            )
        } else {
            TrackerCard(
                type: .sleep,
                subtitle: subtitle(for: .sleep, now: now),
                detail: nextNapDetail(now: now),
                logLabel: "Start nap",
                onLog: { log(.sleep) }
            )
        }
    }

    // MARK: - Data helpers

    private func lastEvent(_ type: ActivityType) -> ActivityEvent? {
        events.first { $0.type == type }
    }

    // The card title already names the activity, so the subtitle is
    // just the time: "25 min ago".
    private func subtitle(for type: ActivityType, now: Date) -> String {
        guard let last = lastEvent(type) else { return "Nothing logged yet" }
        return humanTime(since: last.timestamp, now: now)
    }

    private func prediction(for type: ActivityType, now: Date) -> Prediction? {
        PredictionEngine.predict(
            timestamps: events.filter { $0.typeRaw == type.rawValue }.map(\.timestamp),
            now: now,
            config: .config(for: type, ageBand: baby.ageBand)
        )
    }

    /// The nap in progress, if any — same rule as the repository's
    /// openNap, read from the live @Query so the card flips instantly.
    /// The 16h guard keeps legacy instant-tap sleep rows (nil duration)
    /// from reading as "still asleep".
    private func openNap(now: Date) -> ActivityEvent? {
        let cutoff = now.addingTimeInterval(-16 * 3_600)
        return events.first {
            $0.type == .sleep && $0.durationSeconds == nil && $0.timestamp > cutoff
        }
    }

    /// "likely wakes around 3:20" — display-only, deliberately never a
    /// notification (nap time is quiet time).
    private func wakeDetail(for nap: ActivityEvent, now: Date) -> String? {
        let durations = events.compactMap { event -> (value: TimeInterval, date: Date)? in
            guard event.type == .sleep,
                  let duration = event.durationSeconds, duration > 0 else { return nil }
            return (duration, event.timestamp.addingTimeInterval(duration))
        }
        guard let estimate = PredictionEngine.estimateInterval(
            samples: durations,
            now: now,
            config: .napDurationConfig(ageBand: baby.ageBand)
        ) else { return nil }

        let wake = nap.timestamp.addingTimeInterval(estimate.expected)
        guard wake > now else { return "could wake any time now" }
        return "likely wakes around \(timeText(wake))" + caveat(estimate.confidence)
    }

    private func nextNapDetail(now: Date) -> String? {
        guard let next = prediction(for: .sleep, now: now) else { return nil }
        guard next.nextTime > now else { return "next nap could start any time" }
        return "next nap around \(timeText(next.nextTime))" + caveat(next.confidence)
    }

    private func log(_ type: ActivityType) {
        let repo = ActivityRepository(context: modelContext)
        switch type {
        case .sleep:
            // The card's toggle: the button only reads "Start nap" when
            // no nap is open, but re-check so a stale tap can't stack
            // two open naps.
            if let nap = repo.openNap() {
                repo.endNap(nap)
            } else {
                repo.startNap()
            }
            Task { await Rescheduler.recomputeAndReschedule() }
        case .feed:
            repo.log(type)
            // The choke point re-reads the store, so it must run after
            // the save above.
            Task { await Rescheduler.recomputeAndReschedule() }
        case .poop, .pee:
            repo.log(type)
        }
    }

    private func wakeUp(_ nap: ActivityEvent) {
        ActivityRepository(context: modelContext).endNap(nap)
        Task { await Rescheduler.recomputeAndReschedule() }
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

    /// Running-nap elapsed time: "42m" / "1h 5m". Same shape as the hero
    /// countdown, but counting up.
    private func elapsedText(since date: Date, now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 {
            return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
        }
        return "\(minutes)m"
    }

    /// heroCountdown spelled out for VoiceOver — "1h 5m" reads as
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

// MARK: - Nap adjust sheet

/// "She actually fell asleep at…" — a compact wheel to backdate a
/// running nap's start. Clamped to the past; Save hands the new start
/// back to HomeView, which persists and reschedules.
private struct NapAdjustSheet: View {
    let napStart: Date
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date

    init(napStart: Date, onSave: @escaping (Date) -> Void) {
        self.napStart = napStart
        self.onSave = onSave
        _start = State(initialValue: napStart)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("When did she fall asleep?")
                .font(Theme.display(20, relativeTo: .title3))
                .foregroundStyle(Theme.ink)
                .padding(.top, 24)

            DatePicker("Nap start",
                       selection: $start,
                       in: ...Date.now,
                       displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Button {
                onSave(min(start, .now))
                dismiss()
            } label: {
                Text("Save")
                    .font(Theme.display(17, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Button("Cancel") { dismiss() }
                .font(Theme.text(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.softInk)
                .padding(.bottom, 16)
        }
        .presentationDetents([.height(360)])
        .presentationBackground(Theme.background)
    }
}
