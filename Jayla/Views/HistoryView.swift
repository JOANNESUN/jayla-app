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
//  Month → the 30-day rhythm actogram (WHEN she sleeps), the 4-week
//          trend card (avg/day, delta, daily line over completed days,
//          hedged narrative chip), then per-day average cards. Wet
//          diapers per day is the number the pediatrician asks for.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
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

    init() {
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
                        Text("History")
                            .font(Theme.display(22, relativeTo: .title2))
                            .foregroundStyle(Theme.ink)
                            .padding(.top, 8)

                        pageToggle

                        if page == .today {
                            todayPage(days: days, now: timeline.date)
                        } else {
                            monthPage(days: days)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
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
                        .fill(Theme.background)
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

            HStack {
                Text("12a"); Spacer(); Text("6a"); Spacer()
                Text("12p"); Spacer(); Text("6p"); Spacer(); Text("12a")
            }
            .font(Theme.text(9, relativeTo: .caption2))
            .foregroundStyle(Theme.softInk.opacity(0.8))
        }
        .accessibilityHidden(true)
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

        // Today is still being written — a half-day would drag the
        // line and the average down, so the trend reads completed
        // days only.
        let complete = Array(days.dropLast())
        if let trends = DayLog.trends(days: complete) {
            trendCard(trends, days: complete)
        }

        aggregates(days: days)
    }

    // MARK: - Trend card

    /// The 4-week sleep trend: average, week-over-week delta, the
    /// daily line, and the interpretation chip.
    private func trendCard(_ trends: TrendSummary, days: [DaySummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SLEEP TREND · LAST 4 WEEKS")
                .font(Theme.text(12, .black, relativeTo: .caption))
                .tracking(1.5)
                .foregroundStyle(Theme.softInk)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(trends.avgSleepPerDay > 0
                    ? Format.duration(trends.avgSleepPerDay) : "—")
                    .font(Theme.display(30, relativeTo: .title))
                    .foregroundStyle(Theme.sleepInk)
                deltaBadge(trends)
                Text("avg / day\(trendWord(trends.direction))")
                    .font(Theme.text(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.softInk)
            }

            sleepLine(days: days)

            Text(narrative(for: trends))
                .font(Theme.text(13, .extraBold, relativeTo: .footnote))
                .foregroundStyle(Theme.cobalt)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.sleepBadge,
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .cardShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trendAccessibilityLabel(trends))
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

    private func trendWord(_ direction: TrendSummary.Direction) -> String {
        switch direction {
        case .up:      " · trending up"
        case .down:    " · easing off"
        case .steady:  " · steady"
        case .unknown: ""
        }
    }

    /// Daily sleep totals as one line across the month, days without
    /// sleep data skipped rather than drawn as false zeros.
    private func sleepLine(days: [DaySummary]) -> some View {
        let points: [(index: Int, total: TimeInterval)] = days.enumerated()
            .filter { !$0.element.sleepSegments.isEmpty }
            .map { ($0.offset, $0.element.sleepTotal) }
        let maxTotal = max(points.map(\.total).max() ?? 1, 1)
        let span = Double(max(days.count - 1, 1))

        return VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let at = { (p: (index: Int, total: TimeInterval)) in
                    CGPoint(x: w * Double(p.index) / span,
                            y: h * (1 - 0.9 * p.total / maxTotal))
                }
                if points.count >= 2 {
                    Path { path in
                        path.move(to: at(points[0]))
                        for point in points.dropFirst() {
                            path.addLine(to: at(point))
                        }
                        path.addLine(to: CGPoint(x: at(points[points.count - 1]).x, y: h))
                        path.addLine(to: CGPoint(x: at(points[0]).x, y: h))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [Theme.sleepBadge, Theme.sleepBadge.opacity(0)],
                        startPoint: .top, endPoint: .bottom))

                    Path { path in
                        path.move(to: at(points[0]))
                        for point in points.dropFirst() {
                            path.addLine(to: at(point))
                        }
                    }
                    .stroke(Theme.sleepInk,
                            style: StrokeStyle(lineWidth: 2.5,
                                               lineCap: .round,
                                               lineJoin: .round))

                    let last = at(points[points.count - 1])
                    Circle()
                        .fill(.white)
                        .stroke(Theme.sleepInk, lineWidth: 2.5)
                        .frame(width: 9, height: 9)
                        .position(last)
                } else {
                    Text("a few more days of naps will draw the trend here")
                        .font(Theme.text(12, relativeTo: .caption))
                        .foregroundStyle(Theme.softInk)
                        .frame(width: w, height: h)
                }
            }
            .frame(height: 88)

            HStack {
                Text("Wk 1"); Spacer(); Text("Wk 2"); Spacer()
                Text("Wk 3"); Spacer(); Text("Wk 4")
            }
            .font(Theme.text(10, relativeTo: .caption2))
            .foregroundStyle(Theme.softInk.opacity(0.8))
        }
        .accessibilityHidden(true)
    }

    // MARK: - Aggregate cards

    @ViewBuilder
    private func aggregates(days: [DaySummary]) -> some View {
        let tracked = max(days.filter { !$0.isEmpty }.count, 1)
        let feeds = days.reduce(0) { $0 + $1.feedCount }
        let poops = days.reduce(0) { $0 + $1.poopCount }
        let pees = days.reduce(0) { $0 + $1.peeCount }
        aggregateCard(.feed, headline: perDay(feeds, over: tracked),
                      unit: "/ day", subline: "\(feeds) this month")
        aggregateCard(.poop, headline: perDay(poops, over: tracked),
                      unit: "/ day", subline: "\(poops) this month")
        aggregateCard(.pee, headline: perDay(pees, over: tracked),
                      unit: "/ day", subline: "\(pees) this month")
    }

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
            "She's sleeping a little more than last week."
        case .steady where trends.napsConsolidating:
            "Naps are consolidating into fewer, longer stretches."
        case .steady:
            "Her rhythm is holding steady."
        case .down:
            "A little less sleep than last week — spurts and leaps do this."
        case .unknown:
            "Still learning her weekly rhythm."
        }
    }

    /// "5.3" — always one decimal, matching the averages cards.
    private func perDay(_ total: Int, over days: Int) -> String {
        String(format: "%.1f", Double(total) / Double(days))
    }

    private func trendAccessibilityLabel(_ trends: TrendSummary) -> String {
        let avg = trends.avgSleepPerDay > 0
            ? "She sleeps \(Format.duration(trends.avgSleepPerDay)) a day this week. "
            : ""
        return avg + narrative(for: trends)
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
    HistoryView()
        .modelContainer(for: [ActivityEvent.self, BabyProfile.self], inMemory: true)
}
