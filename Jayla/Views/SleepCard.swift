//
//  SleepCard.swift
//  Jayla
//
//  The sleep hero: sleep is one of the two "live" activities (with
//  feed), so it gets a full-width card instead of a quick-log tile.
//  Two states, driven by whether a nap is open:
//
//  awake  → "NEXT NAP" + bell (a reminder is pending), the prediction,
//           and a Start nap pill
//  asleep → a progress ring (elapsed vs predicted duration), the wake
//           estimate, a backdate row, and a Wake up pill. NO bell —
//           the wake estimate is display-only by design; Jayla never
//           pings during a nap.
//
//  Takes plain values + closures; HomeView owns the data and actions.
//

import SwiftUI

struct SleepCard: View {
    let now: Date
    /// nil = awake.
    let openNapStart: Date?
    /// How long the current nap is expected to run (asleep state).
    let durationEstimate: IntervalEstimate?
    /// Next predicted nap start (awake state).
    let nextNap: Prediction?
    /// The past fact for the awake state, e.g. "Slept 2h ago".
    let lastSleptText: String?

    var onStartNap: () -> Void = {}
    var onWakeUp: () -> Void = {}
    var onAdjust: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var ringSize = 104.0

    var body: some View {
        if let napStart = openNapStart {
            asleepCard(napStart: napStart)
        } else {
            awakeCard
        }
    }

    // MARK: - Asleep

    private func asleepCard(napStart: Date) -> some View {
        // Ring beside the text normally; at accessibility sizes the
        // text column gets crushed, so the ring stacks on top instead.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 18))
        return VStack(spacing: 16) {
            layout {
                progressRing(napStart: napStart)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("SLEEPING")
                            .font(Theme.text(12, .black, relativeTo: .caption))
                            .tracking(1.5)
                            .foregroundStyle(Theme.sleepInk)
                        Image(systemName: "moon.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.sleepInk)
                    }
                    if let wakeText = wakeText(napStart: napStart) {
                        Text(wakeText)
                            .font(Theme.text(14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.ink)
                    }
                    Button(action: onAdjust) {
                        Text("since \(timeText(napStart)) · adjust")
                            .font(Theme.text(12, relativeTo: .caption))
                            .foregroundStyle(Theme.softInk)
                            .underline()
                            .frame(minHeight: 32, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(asleepAccessibilityLabel(napStart: napStart))

            pill("Wake up", color: Theme.sleepInk, action: onWakeUp)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(Theme.sleepBadge)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Theme.sleepInk.opacity(0.45), lineWidth: 1.5)
        )
        .cardShadow()
    }

    /// Elapsed ÷ predicted duration. Full = she should wake any time.
    private func progressRing(napStart: Date) -> some View {
        let elapsed = now.timeIntervalSince(napStart)
        let fraction: Double
        if let expected = durationEstimate?.expected, expected > 0 {
            fraction = min(max(elapsed / expected, 0.02), 1)
        } else {
            fraction = 0.02
        }
        return ZStack {
            Circle()
                .stroke(.white, lineWidth: 10)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.sleepInk,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(elapsedText(since: napStart))
                    .font(Theme.display(20, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                if let remaining = remainingText(napStart: napStart) {
                    Text(remaining)
                        .font(Theme.text(10, relativeTo: .caption2))
                        .foregroundStyle(Theme.softInk)
                }
            }
            .padding(10)
        }
        .frame(width: ringSize, height: ringSize)
    }

    // MARK: - Awake

    private var awakeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("NEXT NAP")
                        .font(Theme.text(12, .black, relativeTo: .caption))
                        .tracking(1.5)
                        .foregroundStyle(Theme.sleepInk)
                    if nextNap != nil {
                        // The honest contract, same as the feed hero:
                        // a bell means this prediction will remind you.
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.sleepInk)
                    }
                }

                if let nextNap {
                    Text(nextNapText(nextNap))
                        .font(Theme.text(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.ink)
                } else {
                    Text("Log the first nap to start predictions")
                        .font(Theme.text(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.softInk)
                }
                if let lastSleptText {
                    Text(lastSleptText)
                        .font(Theme.text(12, relativeTo: .caption))
                        .foregroundStyle(Theme.softInk)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(awakeAccessibilityLabel)

            pill("Start nap", color: Theme.sleepInk, action: onStartNap)
                .padding(.top, 16)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            Circle()
                .fill(Theme.sleepBadge)
                .frame(width: 120, height: 120)
                .offset(x: 20, y: -30)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .cardShadow()
    }

    // MARK: - Pieces

    private func pill(_ title: String, color: Color,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.display(17, relativeTo: .headline))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(color, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Formatting

    private func wakeText(napStart: Date) -> String? {
        guard let estimate = durationEstimate else { return nil }
        let wake = napStart.addingTimeInterval(estimate.expected)
        guard wake > now else { return "could wake any time now" }
        return "likely wakes around \(timeText(wake))" + caveat(estimate.confidence)
    }

    private func remainingText(napStart: Date) -> String? {
        guard let estimate = durationEstimate else { return nil }
        let remaining = napStart.addingTimeInterval(estimate.expected)
            .timeIntervalSince(now)
        guard remaining > 60 else { return "any time now" }
        let minutes = Int(remaining / 60)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 {
            return rest == 0 ? "~\(hours)h left" : "~\(hours)h \(rest)m left"
        }
        return "~\(minutes)m left"
    }

    private func nextNapText(_ prediction: Prediction) -> String {
        guard prediction.nextTime > now else { return "could start any time now" }
        return "around \(timeText(prediction.nextTime))" + caveat(prediction.confidence)
    }

    /// Elapsed nap time: "42m" / "1h 5m".
    private func elapsedText(since date: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 {
            return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
        }
        return "\(minutes)m"
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func caveat(_ confidence: PredictionConfidence) -> String {
        switch confidence {
        case .confident: ""
        case .roughly:   " · rough guess"
        case .learning:  " · still learning"
        }
    }

    // MARK: - Accessibility

    private func asleepAccessibilityLabel(napStart: Date) -> String {
        var label = "Sleeping, \(elapsedText(since: napStart)) so far, since \(timeText(napStart))."
        if let wakeText = wakeText(napStart: napStart) {
            label += " \(wakeText)."
        }
        return label
    }

    private var awakeAccessibilityLabel: String {
        guard let nextNap else {
            return "Next nap. Log the first nap to start predictions."
        }
        var label = "Next nap \(nextNapText(nextNap)). Jayla will remind you."
        if let lastSleptText { label += " \(lastSleptText)." }
        return label
    }
}

#Preview("Awake") {
    SleepCard(now: .now,
              openNapStart: nil,
              durationEstimate: nil,
              nextNap: Prediction(nextTime: .now.addingTimeInterval(45 * 60),
                                  expectedInterval: 2.5 * 3_600,
                                  confidence: .roughly,
                                  sampleCount: 4,
                                  priorBlend: 1),
              lastSleptText: "Slept 2h ago")
        .padding()
        .background(Theme.background)
}

#Preview("Asleep") {
    SleepCard(now: .now,
              openNapStart: .now.addingTimeInterval(-72 * 60),
              durationEstimate: IntervalEstimate(expected: 107 * 60,
                                                 confidence: .roughly,
                                                 sampleCount: 3,
                                                 priorBlend: 0.75),
              nextNap: nil,
              lastSleptText: nil)
        .padding()
        .background(Theme.background)
}
