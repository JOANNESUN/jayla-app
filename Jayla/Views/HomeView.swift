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
import UserNotifications

struct HomeView: View {
    let baby: BabyProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    // The event a long-press asked to take back — non-nil drives the
    // "Remove last …?" confirmation dialog.
    @State private var undoTarget: ActivityEvent?
    // True only when the user explicitly turned notifications off in
    // Settings — drives the recovery banner above the hero card.
    @State private var notificationsDenied = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // everyMinute keeps the countdown, progress bar and
            // predictions fresh while the app is open; logging
            // triggers @Query updates.
            TimelineView(.everyMinute) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if notificationsDenied {
                            NotificationsOffBanner()
                        }
                        heroCard(now: timeline.date)
                        sleepSection(now: timeline.date)
                        quickLogGrid(now: timeline.date)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                // The header stays put while the cards scroll under it.
                .safeAreaInset(edge: .top, spacing: 0) { BabyHeaderBar(baby: baby) }
            }
        }
        // Check on launch AND every return to foreground — the banner's
        // whole job is reacting to what the user just did in Settings.
        .task { await refreshNotificationStatus() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshNotificationStatus() }
        }
        // "I logged the wrong one" — long-press on the feed hero or a
        // poop/pee tile lands here. The dialog names exactly what it's
        // about to remove, so a mis-scroll never deletes silently.
        .confirmationDialog(
            undoTarget.map { "Remove last \($0.type.label.lowercased())?" } ?? "",
            isPresented: Binding(
                get: { undoTarget != nil },
                set: { if !$0 { undoTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: undoTarget
        ) { event in
            Button("Remove \(event.type.label.lowercased()) · \(Format.time(event.timestamp))",
                   role: .destructive) {
                remove(event)
            }
        } message: { event in
            Text("\(event.type.pastTense) \(Format.humanTime(since: event.timestamp, now: .now))")
        }
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
                    Text("HUNGRY AT…")
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
                    // Time leads now — parents read a clock time faster than
                    // "hours from now", so the big line is the "when" and the
                    // countdown drops to the honest small print beneath it.
                    Text(heroHeadline(to: nextFeed.nextTime, from: now, overdue: overdue))
                        .font(overdue ? Theme.display(30, relativeTo: .title)
                                      : Theme.display(52, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 4)
                    Text(heroSubline(for: nextFeed, overdue: overdue, now: now))
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
            // The long-press below is invisible to VoiceOver; the undo
            // rides along as a custom action on the info block.
            .accessibilityAction(named: "Undo last feed") { requestUndo(.feed) }

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

            // Make the long-press undo discoverable — real users had no way
            // to find it. VoiceOver already has the custom action above, so
            // the caption stays silent to avoid a redundant stop.
            UndoHint()
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
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
        // "Take the last feed back" — the Log feed button keeps winning
        // touches on its own frame, so a long-press can never double as
        // an accidental log.
        .onLongPressGesture(minimumDuration: 0.5) { requestUndo(.feed) }
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

    /// The big line: the predicted clock time ("10:52 PM"), or "any time
    /// now" once that time has passed (predictions are honest, not clamped).
    private func heroHeadline(to date: Date, from now: Date, overdue: Bool) -> String {
        overdue ? "any time now" : Format.time(date)
    }

    /// The small print under the time: the countdown while we're waiting
    /// ("in about 1h 5m"), or a past fact once overdue ("expected around
    /// 10:52 PM"). The gentle caveat rides along until the engine is sure.
    private func heroSubline(for prediction: Prediction, overdue: Bool, now: Date) -> String {
        if overdue {
            return "expected around \(Format.time(prediction.nextTime))"
                + caveat(prediction.confidence)
        }
        return "in about \(heroCountdown(to: prediction.nextTime, from: now))"
            + caveat(prediction.confidence)
    }

    /// The countdown text ("1h 5m" / "12m") that now rides in the subline —
    /// or "any time now" (only reached via the overdue path above).
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
            gender: baby.gender,
            openNapStart: nap?.timestamp,
            durationEstimate: napDurationEstimate(now: now),
            nextNap: nap == nil ? prediction(for: .sleep, now: now) : nil,
            awakeSince: nap == nil ? awakeSince() : nil,
            justWokeDuration: nap == nil ? justWokeNap(now: now)?.durationSeconds : nil,
            onStartNap: { log(.sleep) },
            onWakeUp: {
                guard let nap = openNap(now: .now) else { return }
                wakeUp(nap)
            },
            onUndoNap: {
                // "not asleep? undo" — cancel a mis-started nap. Deleting the
                // open nap reverts to the awake state; reschedule since the
                // next-nap prediction moves with it.
                guard let nap = openNap(now: .now) else { return }
                Haptics.tap()
                ActivityRepository(context: modelContext).delete(nap)
                Task { await Rescheduler.recomputeAndReschedule() }
            },
            onUndoWake: {
                guard let nap = justWokeNap(now: .now) else { return }
                Haptics.tap()
                ActivityRepository(context: modelContext).reopenNap(nap)
                Task { await Rescheduler.recomputeAndReschedule() }
            }
        )
    }

    /// When she last woke = the end of the most recent completed nap.
    /// Drives the awake card's "awake for …" headline and its window bar.
    /// nil until there's a finished nap to measure from.
    private func awakeSince() -> Date? {
        guard let last = lastEvent(.sleep), let dur = last.durationSeconds else { return nil }
        return last.timestamp.addingTimeInterval(dur)
    }

    /// The nap whose "Wake up" was tapped in the last half hour — the
    /// window during which the card shows the wake summary and offers
    /// undo. After that it's history (the analysis tab's job later).
    /// The pick itself lives in NapMath (pure, CLI-tested): latest END
    /// wins even when an adjusted start reordered the events, and an
    /// end a few seconds ahead of the stale minute tick still counts.
    private func justWokeNap(now: Date) -> ActivityEvent? {
        let completed = events.filter {
            $0.type == .sleep && ($0.durationSeconds ?? 0) > 0
        }
        guard let index = NapMath.justWokeIndex(
            naps: completed.map { ($0.timestamp, $0.durationSeconds ?? 0) },
            now: now
        ) else { return nil }
        return completed[index]
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
                    onLog: { log(type) },
                    onUndoRequest: { requestUndo(type) }
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

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsDenied = settings.authorizationStatus == .denied
    }

    private func log(_ type: ActivityType) {
        Haptics.tap()
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

    /// A long-press asked to take the last log of a type back. Nothing
    /// to undo → nothing happens; the gesture stays consequence-free.
    private func requestUndo(_ type: ActivityType) {
        guard let last = lastEvent(type) else { return }
        Haptics.tap()
        undoTarget = last
    }

    /// The confirmed undo. Sleep never comes through here — the sleep
    /// card has its own wake-undo — so only a feed needs the reschedule
    /// (poop/pee don't drive notifications, same as when logging them).
    private func remove(_ event: ActivityEvent) {
        Haptics.undo()
        let wasFeed = event.type == .feed
        ActivityRepository(context: modelContext).delete(event)
        if wasFeed {
            Task { await Rescheduler.recomputeAndReschedule() }
        }
    }

    private func wakeUp(_ nap: ActivityEvent) {
        // The nap's "success" buzz — the one log action that completes
        // something rather than starting it.
        Haptics.success()
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
