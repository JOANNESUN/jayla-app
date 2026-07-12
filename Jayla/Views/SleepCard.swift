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
    /// When she last woke (awake state) — end of the most recent nap.
    /// Drives the "awake for …" headline and the awake-window bar.
    let awakeSince: Date?
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

            pill("tap when she wakes", color: Theme.sleepInk, action: onWakeUp)
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
            VStack(alignment: .leading, spacing: 6) {
                Text("AWAKE ☀️")
                    .font(Theme.text(12, .black, relativeTo: .caption))
                    .tracking(1.5)
                    .foregroundStyle(Theme.awakeAccent)

                awakeHeadline
                    .font(Theme.display(28, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(awakeAccessibilityLabel)

            if let awakeSince, let nextNap {
                awakeWindowBar(awakeSince: awakeSince, nextNap: nextNap)
                    .padding(.top, 18)
            } else if nextNap == nil {
                Text("Log the first nap to start predictions")
                    .font(Theme.text(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.softInk)
                    .padding(.top, 12)
            }

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
        return "likely until \(Format.time(wake))" + caveat(estimate.confidence)
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

    /// "awake for 1h 02m and likely tired by 5:46 PM", with the duration
    /// and the time picked out in gold. Falls back gracefully before the
    /// first nap gives us a wake to measure from or a prediction to show.
    private var awakeHeadline: Text {
        guard let awakeSince else { return Text("she's awake") }
        // Gold picks out the numbers against the ink base set in the body.
        let duration = Text(Format.durationPadded(now.timeIntervalSince(awakeSince)))
            .foregroundStyle(Theme.awakeAccent)
        guard let nextNap else { return Text("awake for \(duration)") }
        let tired = nextNap.nextTime > now
            ? Text("by \(Format.time(nextNap.nextTime))").foregroundStyle(Theme.awakeAccent)
            : Text("now").foregroundStyle(Theme.awakeAccent)
        return Text("awake for \(duration) and likely tired \(tired)")
    }

    /// The awake-window progress bar: how far through the stretch between
    /// waking and the next predicted nap. Fills green → gold as she nears
    /// tiredness. A range would over-promise here, so the point estimate
    /// leads and the bar carries the "still filling" hedge.
    private func awakeWindowBar(awakeSince: Date, nextNap: Prediction) -> some View {
        let total = nextNap.nextTime.timeIntervalSince(awakeSince)
        let elapsed = now.timeIntervalSince(awakeSince)
        let fraction = total > 0 ? min(max(elapsed / total, 0.02), 1) : 1
        let tiredLabel = nextNap.nextTime > now
            ? "likely tired by \(Format.time(nextNap.nextTime))"
            : "likely tired now"
        return VStack(spacing: 7) {
            HStack {
                Text("awake window")
                Spacer()
                Text(tiredLabel)
            }
            .font(Theme.text(12, relativeTo: .caption))
            .foregroundStyle(Theme.softInk)

            GeometryReader { geo in
                Capsule()
                    // Warm track so the pale bar doesn't vanish on white.
                    .fill(Color(hex: "EFEADD"))
                    .overlay(alignment: .leading) {
                        // Gradient spans the FULL track and is revealed up
                        // to `fraction`, so the fill reads green early and
                        // only warms to gold as the window runs out.
                        LinearGradient(colors: [Theme.emerald, Theme.awakeButton],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width)
                            .mask(alignment: .leading) {
                                Capsule().frame(width: geo.size.width * fraction)
                            }
                    }
            }
            .frame(height: 9)
        }
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
        guard let awakeSince else {
            return "She's awake. Log the first nap to start predictions."
        }
        var label = "Awake for \(Format.duration(now.timeIntervalSince(awakeSince)))."
        if let nextNap {
            label += nextNap.nextTime > now
                ? " Likely tired by \(Format.time(nextNap.nextTime)). Jayla will remind you."
                : " Likely tired now."
        } else {
            label += " Log the first nap to start predictions."
        }
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
              awakeSince: .now.addingTimeInterval(-62 * 60),
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
              awakeSince: .now.addingTimeInterval(-2 * 60),
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
              awakeSince: nil,
              justWokeDuration: nil)
        .padding()
        .background(Theme.background)
}
