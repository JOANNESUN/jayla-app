//
//  HomeView.swift
//  Jayla
//
//  The "Today dashboard" (design 1a): name header, a countdown hero
//  card that owns the next-feed prediction, then a 2×2 quick-log grid.
//  Logging sits above the fold — the countdown and its cycle progress
//  bar are the reward that keeps the logging loop going. The photo
//  lives on the profile tab.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    let baby: BabyProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
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
                        heroCard(now: timeline.date)
                        sleepSection(now: timeline.date)
                        quickLogGrid(now: timeline.date)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 32)
                }
                // The header stays put while the cards scroll under it.
                .safeAreaInset(edge: .top, spacing: 0) { header }
            }
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

    // One pinned line: small photo, name, age, on a coral brand bar
    // (Joanne picked it from five header mockups). Display-only — the
    // keepsake page owns photo changing and editing.
    private var header: some View {
        HStack(spacing: 10) {
            Group {
                if let data = baby.photoData, let image = Image(photoData: data) {
                    image.resizable().scaledToFill()
                } else {
                    Circle()
                        .fill(Theme.feedBadge)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.accent)
                        )
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))

            Text(baby.name)
                .font(Theme.display(20, relativeTo: .title3))
                .foregroundStyle(.white)
            Text("· \(baby.ageDescription)")
                .font(Theme.text(13, relativeTo: .footnote))
                .foregroundStyle(Color(hex: "FFD9D4"))

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        // The bar paints up behind the status bar too, so the coral
        // runs to the physical top of the screen.
        .background { Theme.accent.ignoresSafeArea(edges: .top) }
    }

    // MARK: - Hero card

    // The ONE place feed lives: prediction, past fact AND the log
    // action (the quick-log grid is instants only — poop/pee). The
    // little bell marks the honest contract: this is the prediction
    // that will remind you.
    private func heroCard(now: Date) -> some View {
        let nextFeed = prediction(for: .feed, now: now)
        // Same 60-second threshold heroCountdown uses for "any time
        // now", so the full bar and the copy always agree.
        let overdue = nextFeed.map { $0.nextTime.timeIntervalSince(now) <= 60 } ?? false
        return VStack(alignment: .leading, spacing: 0) {
            // The informational block reads as ONE VoiceOver sentence —
            // the bell glyph, caveat, bar and countdown are meaningless
            // as separate stops. The log button below stays its own stop.
            VStack(alignment: .leading, spacing: 0) {
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
                            Text("\(ActivityType.feed.pastTense) \(Format.humanTime(since: lastFeed.timestamp, now: now))")
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(heroAccessibilityLabel(for: nextFeed, now: now))

            Button {
                log(.feed)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(.footnote, weight: .heavy))
                    Text("Log feed")
                        .font(Theme.display(17, relativeTo: .headline))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
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
        "\(overdue ? "expected around" : "around") \(Format.time(prediction.nextTime))"
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
        return "Next feed around \(Format.time(prediction.nextTime))\(caveat). "
            + "\(spokenCountdown(to: prediction.nextTime, from: now)). "
            + "Jayla will remind you."
    }

    // MARK: - Quick log

    // Sleep is the other "live" activity, so it gets a hero-style
    // full-width card (SleepCard), not a tile. HomeView resolves the
    // open nap at action time so a stale render can't act on the
    // wrong state.
    private func sleepSection(now: Date) -> some View {
        let nap = openNap(now: now)
        return SleepCard(
            now: now,
            ageBand: baby.ageBand,
            openNapStart: nap?.timestamp,
            durationEstimate: napDurationEstimate(now: now),
            nextNap: nap == nil ? prediction(for: .sleep, now: now) : nil,
            lastSleptText: lastEvent(.sleep).map {
                "\(ActivityType.sleep.pastTense) \(Format.humanTime(since: $0.timestamp, now: now))"
            },
            justWokeDuration: nap == nil ? justWokeNap(now: now)?.durationSeconds : nil,
            onStartNap: { log(.sleep) },
            onWakeUp: {
                guard let nap = openNap(now: .now) else { return }
                wakeUp(nap)
            },
            onAdjust: { adjustingNap = openNap(now: .now) },
            onUndoWake: {
                guard let nap = justWokeNap(now: .now) else { return }
                ActivityRepository(context: modelContext).reopenNap(nap)
                Task { await Rescheduler.recomputeAndReschedule() }
            }
        )
    }

    /// The nap whose "Wake up" was tapped in the last half hour — the
    /// window during which the card shows the wake summary and offers
    /// undo. After that it's history (the analysis tab's job later).
    private func justWokeNap(now: Date) -> ActivityEvent? {
        guard let nap = events.first(where: {
            $0.type == .sleep && ($0.durationSeconds ?? 0) > 0
        }), let duration = nap.durationSeconds else { return nil }
        let end = nap.timestamp.addingTimeInterval(duration)
        guard now.timeIntervalSince(end) < 30 * 60,
              now.timeIntervalSince(end) >= 0 else { return nil }
        return nap
    }

    // The grid holds the instants only — poop and pee. One glance, one
    // number: how many times today. The live activities (feed, sleep)
    // own their heroes above. At accessibility text sizes half-width
    // tiles can't fit their text, so the grid collapses to one column.
    private func quickLogGrid(now: Date) -> some View {
        let columns = typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach([ActivityType.poop, .pee]) { type in
                TrackerCard(
                    type: type,
                    count: todayCount(for: type, now: now),
                    onLog: { log(type) }
                )
            }
        }
    }

    // MARK: - Data helpers

    private func lastEvent(_ type: ActivityType) -> ActivityEvent? {
        events.first { $0.type == type }
    }

    // How many times today, for the poop/pee tiles. Computed against
    // the timeline's `now` so the count rolls to 0 at midnight without
    // extra plumbing.
    private func todayCount(for type: ActivityType, now: Date) -> Int {
        events.count {
            $0.typeRaw == type.rawValue
                && Calendar.current.isDate($0.timestamp, inSameDayAs: now)
        }
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

    /// How long the current nap is expected to run, from the durations
    /// of recent completed naps. Feeds SleepCard's ring and wake text —
    /// display-only, deliberately never a notification (nap time is
    /// quiet time).
    private func napDurationEstimate(now: Date) -> IntervalEstimate? {
        let durations = events.compactMap { event -> (value: TimeInterval, date: Date)? in
            guard event.type == .sleep,
                  let duration = event.durationSeconds, duration > 0 else { return nil }
            return (duration, event.timestamp.addingTimeInterval(duration))
        }
        return PredictionEngine.estimateInterval(
            samples: durations,
            now: now,
            config: .napDurationConfig(ageBand: baby.ageBand)
        )
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

    // MARK: - Formatting

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
                .labelsHidden()
                // .wheel doesn't exist on macOS, which the fast
                // type-check build (`-destination 'platform=macOS'`)
                // compiles for.
                #if os(iOS)
                .datePickerStyle(.wheel)
                #endif

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
