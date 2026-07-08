//
//  HistoryView.swift
//  Jayla
//
//  The history page: the pattern chart on top (30 days of columns),
//  then whatever day is selected spelled out below — a totals row and
//  the day's events in order. One page answers the three questions
//  parents actually bring to history: is a rhythm forming (chart),
//  what exactly happened (list), how much/how many (totals — wet
//  diapers per day is the number the pediatrician asks for).
//
//  The list is also the correction surface: swipe a row to delete a
//  mis-log. Deleting a feed or sleep reschedules notifications, same
//  contract as logging one.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [ActivityEvent]
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    /// The chart shows this many days.
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
            // and deleting update through @Query.
            TimelineView(.everyMinute) { timeline in
                let now = timeline.date
                let days = DayLog.build(events: dayLogEvents(),
                                        now: now, daysBack: Self.daysBack)
                let summary = days.first { $0.day == selectedDay }
                let dayEvents = events.filter {
                    Calendar.current.isDate($0.timestamp, inSameDayAs: selectedDay)
                }

                List {
                    Group {
                        Text("History")
                            .font(Theme.display(22, relativeTo: .title2))
                            .foregroundStyle(Theme.ink)
                            .padding(.top, 8)

                        PatternChartView(days: days, selectedDay: $selectedDay)
                            .padding(.bottom, 6)

                        Text(dayTitle(now: now))
                            .font(Theme.display(18, relativeTo: .title3))
                            .foregroundStyle(Theme.ink)

                        if let summary, !summary.isEmpty {
                            totalsRow(summary)
                        }

                        if dayEvents.isEmpty {
                            Text("nothing logged this day")
                                .font(Theme.text(14, relativeTo: .subheadline))
                                .foregroundStyle(Theme.softInk)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(dayEvents) { event in
                                eventRow(event, now: now)
                            }
                            .onDelete { delete(at: $0, in: dayEvents) }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20,
                                              bottom: 4, trailing: 20))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                #if DEBUG
                .onAppear { debugDump(days) }
                #endif
            }
        }
    }

    // MARK: - Day detail

    private func dayTitle(now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(selectedDay, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1,
                                         to: calendar.startOfDay(for: now)),
           selectedDay == yesterday { return "Yesterday" }
        return selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// "12h 40m · 8 · 6 · 2" behind the day's four icons — the numbers
    /// a pediatrician visit runs on.
    private func totalsRow(_ summary: DaySummary) -> some View {
        HStack(spacing: 18) {
            stat(icon: ActivityType.sleep.mascot,
                 value: summary.sleepSegments.isEmpty
                     ? "—" : Format.duration(summary.sleepTotal),
                 color: Theme.sleepInk)
            stat(icon: ActivityType.feed.mascot,
                 value: "\(summary.feedCount)", color: Theme.feedInk)
            stat(icon: ActivityType.pee.icon,
                 value: "\(summary.peeCount)", color: Theme.peeCount)
            stat(icon: ActivityType.poop.icon,
                 value: "\(summary.poopCount)", color: Theme.poopInk)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .cardShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(totalsAccessibilityLabel(summary))
    }

    private func stat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
            Text(value)
                .font(Theme.display(16, relativeTo: .headline))
                .foregroundStyle(color)
        }
    }

    private func totalsAccessibilityLabel(_ summary: DaySummary) -> String {
        let slept = summary.sleepSegments.isEmpty
            ? "no sleep logged" : "slept \(Format.duration(summary.sleepTotal))"
        return "\(slept), \(summary.feedCount) feeds, "
            + "\(summary.peeCount) pee, \(summary.poopCount) poop"
    }

    private func eventRow(_ event: ActivityEvent, now: Date) -> some View {
        let open = isOpenNap(event, now: now)
        return HStack(spacing: 12) {
            Image(iconAsset(event.type))
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)

            Text(open ? "Sleeping" : event.type.pastTense)
                .font(Theme.text(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.ink)

            if let detail = sleepDetail(event, open: open) {
                Text(detail)
                    .font(Theme.text(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.softInk)
            }

            Spacer()

            Text(Format.time(event.timestamp))
                .font(Theme.text(13, relativeTo: .footnote))
                .foregroundStyle(Theme.softInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    /// "1h 5m" on completed sleeps, "still going" on the open nap,
    /// nothing on moments (and on legacy sleeps that never got one).
    private func sleepDetail(_ event: ActivityEvent, open: Bool) -> String? {
        guard event.type == .sleep else { return nil }
        if open { return "still going" }
        return event.durationSeconds.map { Format.duration($0) }
    }

    private func isOpenNap(_ event: ActivityEvent, now: Date) -> Bool {
        event.type == .sleep && event.durationSeconds == nil
            && now.timeIntervalSince(event.timestamp) < DayLog.openNapGuard
            && event.timestamp <= now
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

    private func delete(at offsets: IndexSet, in dayEvents: [ActivityEvent]) {
        let repo = ActivityRepository(context: modelContext)
        var needsReschedule = false
        for index in offsets {
            let event = dayEvents[index]
            needsReschedule = needsReschedule
                || event.type == .feed || event.type == .sleep
            repo.delete(event)
        }
        // Same choke point as logging: feed/sleep changes move the
        // predictions, so the pending reminders must move too.
        if needsReschedule {
            Task { await Rescheduler.recomputeAndReschedule() }
        }
    }

    private func iconAsset(_ type: ActivityType) -> String {
        switch type {
        case .feed, .sleep: type.mascot
        case .poop, .pee:   type.icon
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
