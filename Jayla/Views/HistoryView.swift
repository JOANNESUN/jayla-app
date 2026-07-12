//
//  HistoryView.swift
//  Jayla
//
//  The history tab, to Joanne's design: a Today | Month pill, sleep
//  always on top, feed/poop/pee only ever aggregate numbers — no
//  event-by-event rows anywhere, her explicit call.
//
//  Today → sleep card (total so far, live; the day as a horizontal
//          24h strip) + count-today cards with "last 2:30 pm" lines.
//  Month → the 30-day rhythm actogram (WHEN she sleeps), then four
//          squares: sleep avg/day (completed days only, with the
//          week-over-week delta) and feeds/poops/pees per day. Wet
//          diapers per day is the number the pediatrician asks for.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    let baby: BabyProfile

    @Query private var events: [ActivityEvent]
    @State private var page = HistoryView.initialPage

    private enum Page { case today, month }

    // Dev-only: JAYLA_OPEN_TAB=history-month starts on the month page
    // for headless screenshots.
    private static var initialPage: Page {
        #if DEBUG
        ProcessInfo.processInfo.environment["JAYLA_OPEN_TAB"] == "history-month"
            ? .month : .today
        #else
        .today
        #endif
    }

    /// The page (and trend math) covers this many days.
    private static let daysBack = 30

    init(baby: BabyProfile) {
        self.baby = baby
        // One extra day so a sleep that starts before the window still
        // spills its in-window segment onto the first visible column.
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -(Self.daysBack + 1),
            to: Calendar.current.startOfDay(for: .now)) ?? .distantPast
        _events = Query(
            filter: #Predicate<ActivityEvent> { $0.timestamp > cutoff },
            sort: \ActivityEvent.timestamp, order: .forward)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // Same clock as HomeView: everyMinute keeps the open nap's
            // ribbon growing and rolls the window at midnight; logging
            // updates through @Query.
            TimelineView(.everyMinute) { timeline in
                let days = DayLog.build(events: dayLogEvents(),
                                        now: timeline.date,
                                        daysBack: Self.daysBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        pageToggle

                        if page == .today {
                            todayPage(days: days, now: timeline.date)
                        } else {
                            monthPage(days: days)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                // Same pinned brand bar as the home tab, in place of a
                // "History" title.
                .safeAreaInset(edge: .top, spacing: 0) { BabyHeaderBar(baby: baby) }
                #if DEBUG
                .onAppear { debugDump(days) }
                #endif
            }
        }
    }

    // MARK: - Toggle

    private var pageToggle: some View {
        HStack(spacing: 0) {
            segment("Today", .today)
            segment("Month", .month)
        }
        .padding(4)
        .background(Theme.softInk.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 18))
    }

    private func segment(_ title: String, _ target: Page) -> some View {
        let selected = page == target
        return Button {
            withAnimation(.snappy(duration: 0.2)) { page = target }
        } label: {
            Text(title)
                .font(Theme.display(16, relativeTo: .headline))
                .foregroundStyle(selected ? Theme.ink : Theme.softInk)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white)
                            .cardShadow()
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Today page

    @ViewBuilder
    private func todayPage(days: [DaySummary], now: Date) -> some View {
        if let today = days.last {
            todaySleepCard(today, now: now)
            aggregateCard(.feed, headline: "\(today.feedCount)",
                          unit: "today", subline: lastLine(.feed, now: now))
            aggregateCard(.poop, headline: "\(today.poopCount)",
                          unit: "today", subline: lastLine(.poop, now: now))
            aggregateCard(.pee, headline: "\(today.peeCount)",
                          unit: "today", subline: lastLine(.pee, now: now))
        }
    }

    /// Sleep leads: the total so far and the day drawn as one 24h strip.
    private func todaySleepCard(_ today: DaySummary, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SLEEP")
                .font(Theme.text(12, .black, relativeTo: .caption))
                .tracking(1.5)
                .foregroundStyle(Theme.sleepInk)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(today.sleepSegments.isEmpty
                    ? "—" : Format.duration(today.sleepTotal))
                    .font(Theme.display(34, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.sleepInk)
                Text(today.sleepSegments.contains(where: \.isOpen)
                    ? "so far — still napping" : "slept today")
                    .font(Theme.text(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.softInk)
            }

            dayStrip(today)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .cardShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(today.sleepSegments.isEmpty
            ? "Sleep. Nothing logged yet today."
            : "Slept \(Format.duration(today.sleepTotal)) today.")
    }

    /// Today as a horizontal 24h bar — the actogram column, laid down.
    private func dayStrip(_ day: DaySummary) -> some View {
        let dayLength = Self.dayLength(of: day.day)
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Theme.chartTrack)
                    ForEach(day.sleepSegments) { segment in
                        let from = geo.size.width
                            * segment.start.timeIntervalSince(day.day) / dayLength
                        let width = geo.size.width
                            * segment.duration / dayLength
                        RoundedRectangle(cornerRadius: 5)
                            .fill(segment.isOpen
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [Theme.sleepInk,
                                             Theme.sleepInk.opacity(0.35)],
                                    startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Theme.sleepInk))
                            .frame(width: max(4, width), height: 16)
                            .offset(x: from)
                    }
                }
            }
            .frame(height: 20)

            // fixedSize for the same reason as the actogram's labels:
            // chart marks must never wrap at big text sizes.
            HStack {
                mark("12a"); Spacer(); mark("6a"); Spacer()
                mark("12p"); Spacer(); mark("6p"); Spacer(); mark("12a")
            }
            .foregroundStyle(Theme.softInk.opacity(0.8))
        }
        .accessibilityHidden(true)
    }

    private func mark(_ label: String) -> some View {
        Text(label)
            .font(Theme.text(9, relativeTo: .caption2))
            .fixedSize()
    }

    /// "last 2:30 pm" — or an honest blank early in the day.
    private func lastLine(_ type: ActivityType, now: Date) -> String {
        let last = events.last {
            $0.typeRaw == type.rawValue
                && Calendar.current.isDate($0.timestamp, inSameDayAs: now)
        }
        guard let last else { return "not yet today" }
        return "last \(Format.time(last.timestamp))"
    }

    /// Real length of a day — 23h/25h on DST days.
    private static func dayLength(of dayStart: Date) -> TimeInterval {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 3_600)
        return next.timeIntervalSince(dayStart)
    }

    // MARK: - Month page

    @ViewBuilder
    private func monthPage(days: [DaySummary]) -> some View {
        PatternChartView(days: days)
        statGrid(days: days)
    }

    // MARK: - Stat squares

    /// The month in four squares — sleep average, then feeds, poops
    /// and pees per day. Averages only, no monthly totals; sleep and
    /// naps deliberately one number (Joanne's call: don't split them).
    private func statGrid(days: [DaySummary]) -> some View {
        // Today is still being written — a half-day would drag the
        // sleep average down, so the trend reads completed days only.
        let trends = DayLog.trends(days: Array(days.dropLast()))
        let tracked = max(days.filter { !$0.isEmpty }.count, 1)
        let feeds = days.reduce(0) { $0 + $1.feedCount }
        let poops = days.reduce(0) { $0 + $1.poopCount }
        let pees = days.reduce(0) { $0 + $1.peeCount }

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                   GridItem(.flexible(), spacing: 14)],
                         spacing: 14) {
            squareCard(.sleep,
                       value: (trends?.avgSleepPerDay ?? 0) > 0
                          ? Format.duration(trends!.avgSleepPerDay) : "—",
                       unit: "sleep / day",
                       a11y: sleepAccessibilityLabel(trends)) {
                if let trends { deltaBadge(trends) }
            }
            squareCard(.feed, value: perDay(feeds, over: tracked),
                       unit: "feeds / day")
            squareCard(.poop, value: perDay(poops, over: tracked),
                       unit: "poops / day")
            squareCard(.pee, value: perDay(pees, over: tracked),
                       unit: "pees / day")
        }
    }

    /// One square: icon chip, the average, what it counts.
    private func squareCard(_ type: ActivityType, value: String,
                            unit: String, a11y: String? = nil,
                            @ViewBuilder badge: () -> some View = { EmptyView() }
    ) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 14)
                .fill(chipColor(type))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(iconAsset(type))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 27, height: 27)
                )

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(Theme.display(24, relativeTo: .title2))
                    .foregroundStyle(type.countColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                badge()
            }

            Text(unit)
                .font(Theme.text(12, relativeTo: .caption))
                .foregroundStyle(Theme.softInk)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .cardShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y ?? "\(type.label), \(value) \(unit)")
    }

    /// "▲ 40m" week over week — only when the direction is earned.
    @ViewBuilder
    private func deltaBadge(_ trends: TrendSummary) -> some View {
        if trends.weeks.count >= 2,
           trends.direction == .up || trends.direction == .down {
            let delta = trends.weeks[trends.weeks.count - 1].avgSleep
                - trends.weeks[trends.weeks.count - 2].avgSleep
            HStack(spacing: 3) {
                Image(systemName: delta > 0
                    ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(Format.duration(abs(delta)))
                    .font(Theme.text(13, .extraBold, relativeTo: .footnote))
            }
            .foregroundStyle(delta > 0 ? Theme.emerald : Theme.softInk)
        }
    }

    // MARK: - Aggregate cards

    /// One activity, one number — Joanne's call: everything that isn't
    /// sleep is just an aggregate. Icon chip, name, context line, and
    /// the number on the right.
    private func aggregateCard(_ type: ActivityType, headline: String,
                               unit: String, subline: String) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(chipColor(type))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(iconAsset(type))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(type.label)
                    .font(Theme.display(16, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
                Text(subline)
                    .font(Theme.text(12, relativeTo: .caption))
                    .foregroundStyle(Theme.softInk)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text(headline)
                    .font(Theme.display(24, relativeTo: .title2))
                    .foregroundStyle(type.countColor)
                Text(unit)
                    .font(Theme.text(11, relativeTo: .caption2))
                    .foregroundStyle(Theme.softInk)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .cardShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(type.label), \(headline) \(unit), \(subline)")
    }

    private func chipColor(_ type: ActivityType) -> Color {
        switch type {
        case .feed:  Theme.feedBadge
        case .sleep: Theme.sleepBadge
        case .poop:  Theme.poopBorder.opacity(0.3)
        case .pee:   Theme.peeBorder.opacity(0.3)
        }
    }

    private func iconAsset(_ type: ActivityType) -> String {
        switch type {
        case .feed, .sleep: type.mascot
        case .poop, .pee:   type.icon
        }
    }

    // MARK: - Copy

    /// The interpretation line — descriptive and hedged, never a
    /// verdict. Same voice as "her sleepy cues beat the clock".
    private func narrative(for trends: TrendSummary) -> String {
        switch trends.direction {
        case .up where trends.napsConsolidating:
            "Sleep is lengthening and naps are consolidating."
        case .up:
            "\(baby.gender.subject.capitalized)'s sleeping a little more than last week."
        case .steady where trends.napsConsolidating:
            "Naps are consolidating into fewer, longer stretches."
        case .steady:
            "\(baby.gender.possessive.capitalized) rhythm is holding steady."
        case .down:
            "A little less sleep than last week — spurts and leaps do this."
        case .unknown:
            "Still learning \(baby.gender.possessive) weekly rhythm."
        }
    }

    /// "5.3" — always one decimal, matching the averages cards.
    private func perDay(_ total: Int, over days: Int) -> String {
        String(format: "%.1f", Double(total) / Double(days))
    }

    private func sleepAccessibilityLabel(_ trends: TrendSummary?) -> String {
        guard let trends, trends.avgSleepPerDay > 0 else {
            return "Sleep. Not enough data yet."
        }
        return "\(baby.gender.subject.capitalized) sleeps \(Format.duration(trends.avgSleepPerDay)) a day this week. "
            + narrative(for: trends)
    }

    // MARK: - Data

    private func dayLogEvents() -> [DayLog.Event] {
        events.compactMap { event in
            guard let kind = DayLog.Kind(rawValue: event.typeRaw) else { return nil }
            return DayLog.Event(id: event.id, kind: kind,
                                timestamp: event.timestamp,
                                durationSeconds: event.durationSeconds)
        }
    }

    #if DEBUG
    private func debugDump(_ days: [DaySummary]) {
        print("📊 [Jayla] history — \(days.count) days:")
        for day in days where !day.isEmpty {
            let label = day.day.formatted(date: .abbreviated, time: .omitted)
            print("  \(label): sleep \(Format.duration(day.sleepTotal)), "
                + "\(day.feedCount) feeds, \(day.peeCount) pee, \(day.poopCount) poop")
        }
    }
    #endif
}

#Preview {
    HistoryView(baby: BabyProfile(name: "Jayla",
                                  birthdate: Calendar.current.date(
                                      byAdding: .month, value: -5, to: .now)!))
        .modelContainer(for: [ActivityEvent.self, BabyProfile.self], inMemory: true)
}
