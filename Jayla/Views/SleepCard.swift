//
//  SleepCard.swift
//  Jayla
//
//  The sleep hero: sleep is one of the two "live" activities (with
//  feed), so it gets a full-width card instead of a quick-log tile.
//  Two states, driven by whether a nap is open:
//
//  awake  → "SLEEPY IN…" + bell (a reminder is pending), the nap
//           window, and a Start nap pill ("WIDE AWAKE" right after
//           a wake)
//  asleep → "DO NOT DISTURB": a progress ring (elapsed vs predicted
//           duration), the wake estimate, a backdate row, and a Wake
//           up pill. NO bell — the wake estimate is display-only by
//           design; Jayla never pings during a nap.
//
//  Takes plain values + closures; HomeView owns the data and actions.
//

import SwiftUI

struct SleepCard: View {
    let now: Date
    /// Widens the nap window and softens the copy for young babies.
    let ageBand: AgeBand
    /// nil = awake.
    let openNapStart: Date?
    /// How long the current nap is expected to run (asleep state).
    let durationEstimate: IntervalEstimate?
    /// Next predicted nap start (awake state).
    let nextNap: Prediction?
    /// The past fact for the awake state, e.g. "Slept 2h ago".
    let lastSleptText: String?
    /// Set for a short while after "Wake up": the duration of the nap
    /// that just ended. Wake pays the loop off with a summary — shown
    /// in place on this card, never as a modal (taps are the currency
    /// at 3am; nothing here should need dismissing).
    let justWokeDuration: TimeInterval?

    var onStartNap: () -> Void = {}
    var onWakeUp: () -> Void = {}
    var onAdjust: () -> Void = {}
    var onUndoWake: () -> Void = {}

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
                        Text("DO NOT DISTURB")
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
                        Text("since \(Format.time(napStart)) · adjust")
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
                    Text(justWokeDuration == nil ? "SLEEPY IN…" : "WIDE AWAKE ☀️")
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

                if let justWokeDuration {
                    Text("slept \(Format.duration(justWokeDuration))")
                        .font(Theme.display(24, relativeTo: .title2))
                        .foregroundStyle(Theme.ink)
                }

                if let nextNap {
                    napTimeView(nextNap)
                        .padding(.top, justWokeDuration == nil ? 2 : 0)
                } else {
                    Text("Log the first nap to start predictions")
                        .font(Theme.text(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.softInk)
                }
                if justWokeDuration == nil, let lastSleptText {
                    Text(lastSleptText)
                        .font(Theme.text(12, relativeTo: .caption))
                        .foregroundStyle(Theme.softInk)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(awakeAccessibilityLabel)

            if justWokeDuration != nil {
                // Mis-stopped timers are the top timer complaint in the
                // market — recovery stays one tap away.
                Button(action: onUndoWake) {
                    Text("still asleep? undo")
                        .font(Theme.text(12, relativeTo: .caption))
                        .foregroundStyle(Theme.softInk)
                        .underline()
                        .frame(minHeight: 32, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            // Gold pill with dark-ink text — the sunny counterpart to the
            // blue "Wake up" pill, and readable where white-on-gold isn't.
            pill("Start nap", color: Theme.awakeButton, textColor: Theme.ink,
                 action: onStartNap)
                .padding(.top, 16)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        // White fill — the yellow blended into the cream page, so the card
        // is white (like the feed hero) and the gold Start-nap pill carries
        // the sunny cue that sets awake apart from the blue asleep card.
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .cardShadow()
    }

    // MARK: - Pieces

    private func pill(_ title: String, color: Color, textColor: Color = .white,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.display(17, relativeTo: .headline))
                .foregroundStyle(textColor)
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
        return "likely wakes around \(Format.time(wake))" + caveat(estimate.confidence)
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

    /// The awake next-nap display. Right after a wake it stays a compact
    /// one-liner under the big "slept …" summary; the rest of the time the
    /// time range leads (e.g. "3:20 PM ~ 3:50 PM"), with "between" and the
    /// learning caveat as small captions around it.
    @ViewBuilder
    private func napTimeView(_ prediction: Prediction) -> some View {
        if justWokeDuration != nil {
            Text("next nap " + nextNapText(prediction))
                .font(Theme.text(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.ink)
        } else if prediction.nextTime <= now {
            Text("could start any time now")
                .font(Theme.display(20, relativeTo: .title3))
                .foregroundStyle(Theme.ink)
        } else {
            let window = prediction.napWindow(ageBand: ageBand)
            let range = window.lowerBound <= now
                ? "now ~ \(Format.time(window.upperBound))"
                : "\(Format.time(window.lowerBound)) ~ \(Format.time(window.upperBound))"
            VStack(alignment: .leading, spacing: 1) {
                Text("between")
                    .font(Theme.text(11, relativeTo: .caption))
                    .foregroundStyle(Theme.softInk)
                Text(range)
                    .font(Theme.display(20, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                if prediction.confidence == .learning {
                    Text("still learning")
                        .font(Theme.text(10, relativeTo: .caption2))
                        .foregroundStyle(Theme.softInk)
                }
            }
        }
    }

    // A range, not a point: the window IS the hedge, so the caveat
    // suffix only stays while the engine is still learning. Still backs
    // the just-woke line and the VoiceOver label ("and" reads better
    // than the visual "~").
    private func nextNapText(_ prediction: Prediction) -> String {
        guard prediction.nextTime > now else { return "could start any time now" }
        let window = prediction.napWindow(ageBand: ageBand)
        let suffix = prediction.confidence == .learning ? " · still learning" : ""
        if window.lowerBound <= now {
            return "between now and \(Format.time(window.upperBound))" + suffix
        }
        return "between \(Format.time(window.lowerBound)) and \(Format.time(window.upperBound))"
            + suffix
    }

    /// Elapsed nap time: "42m" / "1h 5m".
    private func elapsedText(since date: Date) -> String {
        Format.duration(now.timeIntervalSince(date))
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
        var label = "Sleeping, \(elapsedText(since: napStart)) so far, since \(Format.time(napStart))."
        if let wakeText = wakeText(napStart: napStart) {
            label += " \(wakeText)."
        }
        return label
    }

    private var awakeAccessibilityLabel: String {
        var label = ""
        if let justWokeDuration {
            label += "She's awake, slept \(Format.duration(justWokeDuration)). "
        }
        guard let nextNap else {
            return label + "Next nap. Log the first nap to start predictions."
        }
        label += "Next nap \(nextNapText(nextNap)). Jayla will remind you."
        if justWokeDuration == nil, let lastSleptText { label += " \(lastSleptText)." }
        return label
    }
}

#Preview("Awake") {
    SleepCard(now: .now,
              ageBand: .infant,
              openNapStart: nil,
              durationEstimate: nil,
              nextNap: Prediction(nextTime: .now.addingTimeInterval(45 * 60),
                                  expectedInterval: 2.5 * 3_600,
                                  confidence: .roughly,
                                  sampleCount: 4,
                                  priorBlend: 1),
              lastSleptText: "Slept 2h ago",
              justWokeDuration: nil)
        .padding()
        .background(Theme.background)
}

#Preview("Just woke — short nap") {
    SleepCard(now: .now,
              ageBand: .infant,
              openNapStart: nil,
              durationEstimate: nil,
              nextNap: Prediction(nextTime: .now.addingTimeInterval(100 * 60),
                                  expectedInterval: 2.5 * 3_600,
                                  confidence: .roughly,
                                  sampleCount: 4,
                                  priorBlend: 1),
              lastSleptText: nil,
              justWokeDuration: 28 * 60)
        .padding()
        .background(Theme.background)
}

#Preview("Asleep") {
    SleepCard(now: .now,
              ageBand: .infant,
              openNapStart: .now.addingTimeInterval(-72 * 60),
              durationEstimate: IntervalEstimate(expected: 107 * 60,
                                                 confidence: .roughly,
                                                 sampleCount: 3,
                                                 priorBlend: 0.75),
              nextNap: nil,
              lastSleptText: nil,
              justWokeDuration: nil)
        .padding()
        .background(Theme.background)
}
