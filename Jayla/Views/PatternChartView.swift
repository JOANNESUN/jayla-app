//
//  PatternChartView.swift
//  Jayla
//
//  The history page's sleep chart (an actogram): one column per day,
//  midnight at the top, midnight at the bottom, sleep drawn as blue
//  ribbons. Sleep only, by Joanne's call — everything else is just a
//  number in the day card below. Rhythm is the payoff: as naps
//  consolidate, the ribbons line up across columns and you can *see*
//  the schedule forming.
//
//  Custom-drawn (not Swift Charts): the whole thing is one y-mapping —
//  y = height · seconds-since-midnight / day-length — and columns need
//  tap-to-select, footer badges and open-at-today scrolling that charts
//  APIs fight.
//

import SwiftUI

struct PatternChartView: View {
    /// One per calendar day, oldest first (DayLog.build's output).
    let days: [DaySummary]

    /// Height of the 24h track.
    private static let trackHeight: CGFloat = 220
    private static let columnWidth: CGFloat = 34
    private static let rulerWidth: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SLEEP RHYTHM · LAST 30 DAYS")
                .font(Theme.text(12, .black, relativeTo: .caption))
                .tracking(1.5)
                .foregroundStyle(Theme.softInk)

            HStack(alignment: .top, spacing: 8) {
                hourRuler
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(days) { day in
                            DayColumn(summary: day,
                                      isToday: day.id == days.last?.id,
                                      trackHeight: Self.trackHeight,
                                      width: Self.columnWidth)
                        }
                    }
                }
                // Today lives at the right edge; start there.
                .defaultScrollAnchor(.trailing)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .cardShadow()
    }

    /// 6a / 12p / 6p marks along the 24h track, pinned outside the
    /// scroll so they hold while the days slide. fixedSize: these are
    /// part of the drawing — at big Dynamic Type sizes they'd wrap
    /// inside the ruler ("12p" stacking) instead of staying marks.
    private var hourRuler: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear.frame(width: Self.rulerWidth, height: Self.trackHeight)
            ForEach([(6, "6a"), (12, "12p"), (18, "6p")], id: \.0) { hour, label in
                Text(label)
                    .font(Theme.text(9, relativeTo: .caption2))
                    .foregroundStyle(Theme.softInk.opacity(0.8))
                    .fixedSize()
                    .frame(width: Self.rulerWidth, alignment: .trailing)
                    .offset(y: Self.trackHeight * CGFloat(hour) / 24 - 6)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - One day's column

private struct DayColumn: View {
    let summary: DaySummary
    let isToday: Bool
    let trackHeight: CGFloat
    let width: CGFloat

    private var dayStart: Date { summary.day }
    /// Real length of THIS day — 23h/25h on DST days, so ribbons still
    /// land on the wall-clock times a parent remembers.
    private var dayLength: TimeInterval {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 3_600)
        return next.timeIntervalSince(dayStart)
    }

    var body: some View {
        VStack(spacing: 5) {
            track
            labels
        }
        .frame(width: width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var track: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.chartTrack)

            ForEach(summary.sleepSegments) { segment in
                ribbon(for: segment)
            }
        }
        .frame(width: width, height: trackHeight)
    }

    private func ribbon(for segment: SleepSegment) -> some View {
        let top = y(segment.start)
        let height = max(4, y(segment.end) - top)
        return RoundedRectangle(cornerRadius: 5)
            .fill(segment.isOpen
                ? AnyShapeStyle(LinearGradient(
                    colors: [Theme.sleepInk, Theme.sleepInk.opacity(0.35)],
                    startPoint: .top, endPoint: .bottom))
                : AnyShapeStyle(Theme.sleepInk))
            .frame(width: 16, height: height)
            .offset(y: top)
    }

    /// The one mapping everything hangs off: seconds since this day's
    /// midnight, as a fraction of this day's real length.
    private func y(_ date: Date) -> CGFloat {
        let fraction = date.timeIntervalSince(dayStart) / dayLength
        return trackHeight * CGFloat(min(max(fraction, 0), 1))
    }

    // fixedSize keeps "Wed" one word — in a 30pt column it wrapped to
    // "We / d" on narrower phones with bigger text.
    private var labels: some View {
        VStack(spacing: 0) {
            Text(dayStart.formatted(.dateTime.weekday(.abbreviated)))
                .font(Theme.text(9, relativeTo: .caption2))
                .foregroundStyle(Theme.softInk)
                .fixedSize()
            Text(dayStart.formatted(.dateTime.day()))
                .font(Theme.display(13, relativeTo: .caption))
                .foregroundStyle(isToday ? Theme.accent : Theme.ink)
                .fixedSize()
        }
    }

    private var accessibilityText: String {
        let slept = summary.sleepSegments.isEmpty
            ? "no sleep logged"
            : "slept \(Format.duration(summary.sleepTotal))"
        return "\(dayStart.formatted(date: .abbreviated, time: .omitted)), \(slept)"
    }
}

// MARK: - Preview

#Preview {
    struct ChartPreview: View {
        var body: some View {
            let now = Date.now
            let cal = Calendar.current
            let events: [DayLog.Event] = (1...9).flatMap { back -> [DayLog.Event] in
                let day = cal.date(byAdding: .day, value: -back, to: now)!
                let morning = cal.startOfDay(for: day)
                return [
                    // night sleep crossing INTO this day
                    DayLog.Event(id: UUID(), kind: .sleep,
                                 timestamp: morning.addingTimeInterval(-1.5 * 3_600),
                                 durationSeconds: 7 * 3_600),
                    DayLog.Event(id: UUID(), kind: .sleep,
                                 timestamp: morning.addingTimeInterval(13 * 3_600),
                                 durationSeconds: Double.random(in: 0.8...2) * 3_600),
                    DayLog.Event(id: UUID(), kind: .feed,
                                 timestamp: morning.addingTimeInterval(7 * 3_600),
                                 durationSeconds: nil),
                    DayLog.Event(id: UUID(), kind: .feed,
                                 timestamp: morning.addingTimeInterval(11 * 3_600),
                                 durationSeconds: nil),
                    DayLog.Event(id: UUID(), kind: .feed,
                                 timestamp: morning.addingTimeInterval(17.5 * 3_600),
                                 durationSeconds: nil),
                    DayLog.Event(id: UUID(), kind: .pee,
                                 timestamp: morning.addingTimeInterval(9 * 3_600),
                                 durationSeconds: nil),
                    DayLog.Event(id: UUID(), kind: .poop,
                                 timestamp: morning.addingTimeInterval(10 * 3_600),
                                 durationSeconds: nil),
                ]
            } + [
                // open nap today
                DayLog.Event(id: UUID(), kind: .sleep,
                             timestamp: now.addingTimeInterval(-40 * 60),
                             durationSeconds: nil),
            ]
            PatternChartView(days: DayLog.build(events: events, now: now,
                                                daysBack: 14))
                .padding()
                .background(Theme.background)
        }
    }
    return ChartPreview()
}
