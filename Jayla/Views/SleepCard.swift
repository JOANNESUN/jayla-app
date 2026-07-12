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
    /// Picks she/he in the card's copy.
    var gender: Gender = .girl
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
    var onUndoNap: () -> Void = {}
    var onUndoWake: () -> Void = {}

    var body: some View {
        if let napStart = openNapStart {
            asleepCard(napStart: napStart)
        } else {
            awakeCard
        }
    }

    // MARK: - Asleep

    private func asleepCard(napStart: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("DO NOT DISTURB 🌙")
                    .font(Theme.text(12, .black, relativeTo: .caption))
                    .tracking(1.5)
                    .foregroundStyle(Theme.sleepAccent)

                asleepHeadline(napStart: napStart)
                    .font(Theme.display(28, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(asleepAccessibilityLabel(napStart: napStart))

            if let wake = wakeTarget(napStart: napStart) {
                asleepWindowBar(napStart: napStart, wake: wake)
                    .padding(.top, 18)
            } else {
                Text("still learning nap lengths")
                    .font(Theme.text(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.softInk)
                    .padding(.top, 12)
            }

            // She's not actually asleep — cancel the mis-started nap.
            Button(action: onUndoNap) {
                Text("not asleep? undo")
                    .font(Theme.text(12, relativeTo: .caption))
                    .foregroundStyle(Theme.softInk)
                    .underline()
                    .frame(minHeight: 32, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            pill("tap when \(gender.subject) wakes", color: Theme.sleepInk,
                 action: onWakeUp)
                .padding(.top, 16)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sleepBadge)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Theme.sleepInk.opacity(0.45), lineWidth: 1.5)
        )
        .cardShadow()
    }

    /// "asleep for 42m and likely wakes by 5:59 PM", blue on the numbers.
    private func asleepHeadline(napStart: Date) -> Text {
        sentenceHeadline(verb: "asleep for", since: napStart,
                         connector: "and likely wakes",
                         target: wakeTarget(napStart: napStart), accent: Theme.sleepAccent)
    }

    /// Predicted wake = nap start + expected nap length; nil until we have
    /// enough naps to estimate one.
    private func wakeTarget(napStart: Date) -> Date? {
        guard let expected = durationEstimate?.expected else { return nil }
        return napStart.addingTimeInterval(expected)
    }

    /// Blue "nap so far" bar: elapsed ÷ the expected nap length.
    private func asleepWindowBar(napStart: Date, wake: Date) -> some View {
        let expected = wake.timeIntervalSince(napStart)
        let elapsed = now.timeIntervalSince(napStart)
        let fraction = expected > 0 ? min(max(elapsed / expected, 0.02), 1) : 1
        let right = wake > now
            ? "likely wakes \(Format.time(wake))"
            : "likely waking now"
        return windowBar(fraction: fraction, leftLabel: "nap so far",
                         rightLabel: right,
                         gradient: [Theme.sleepInk, Theme.cobalt],
                         track: .white)   // white track on the blue card
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

    /// Shared by both live states so they read the same: "<verb> <duration>
    /// <connector> by <time>" — "awake for 1h 02m and likely tired by 5:46 PM"
    /// / "asleep for 42m and likely wakes by 5:59 PM". The duration and the
    /// "by <time>"/"now" tail are picked out in `accent` against the ink base
    /// the caller sets; `target == nil` drops the tail.
    private func sentenceHeadline(verb: String, since: Date, connector: String,
                                  target: Date?, accent: Color) -> Text {
        let duration = Text(Format.durationPadded(now.timeIntervalSince(since)))
            .foregroundStyle(accent)
        guard let target else { return Text("\(verb) \(duration)") }
        let tail = target > now
            ? Text("by \(Format.time(target))").foregroundStyle(accent)
            : Text("now").foregroundStyle(accent)
        return Text("\(verb) \(duration) \(connector) \(tail)")
    }

    /// Shared progress bar. The gradient spans the FULL track and is revealed
    /// up to `fraction`, so the fill reads its start color early and only
    /// reaches its end color as the window runs out.
    private func windowBar(fraction: Double, leftLabel: String, rightLabel: String,
                           gradient: [Color], track: Color) -> some View {
        VStack(spacing: 7) {
            HStack {
                Text(leftLabel)
                Spacer()
                Text(rightLabel)
            }
            .font(Theme.text(12, relativeTo: .caption))
            .foregroundStyle(Theme.softInk)

            GeometryReader { geo in
                Capsule()
                    .fill(track)
                    .overlay(alignment: .leading) {
                        LinearGradient(colors: gradient,
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

    /// "awake for 1h 02m and likely tired by 5:46 PM", gold on the numbers.
    /// Falls back before the first nap gives us a wake to measure from.
    private var awakeHeadline: Text {
        guard let awakeSince else { return Text("\(gender.subject)'s awake") }
        return sentenceHeadline(verb: "awake for", since: awakeSince,
                                connector: "and likely tired",
                                target: nextNap?.nextTime, accent: Theme.awakeAccent)
    }

    /// Green → gold bar: how far through the stretch from waking to the next
    /// predicted nap. A range would over-promise, so the point estimate leads
    /// and the bar carries the "still filling" hedge.
    private func awakeWindowBar(awakeSince: Date, nextNap: Prediction) -> some View {
        let total = nextNap.nextTime.timeIntervalSince(awakeSince)
        let elapsed = now.timeIntervalSince(awakeSince)
        let fraction = total > 0 ? min(max(elapsed / total, 0.02), 1) : 1
        let right = nextNap.nextTime > now
            ? "likely tired by \(Format.time(nextNap.nextTime))"
            : "likely tired now"
        return windowBar(fraction: fraction, leftLabel: "awake window",
                         rightLabel: right,
                         gradient: [Theme.emerald, Theme.awakeButton],
                         track: Color(hex: "EFEADD"))   // warm track vs the white card
    }

    // MARK: - Accessibility

    private func asleepAccessibilityLabel(napStart: Date) -> String {
        var label = "Asleep for \(Format.duration(now.timeIntervalSince(napStart)))."
        if let wake = wakeTarget(napStart: napStart) {
            label += wake > now
                ? " Likely wakes by \(Format.time(wake))."
                : " Likely waking now."
        }
        return label
    }

    private var awakeAccessibilityLabel: String {
        guard let awakeSince else {
            return "\(gender.subject.capitalized)'s awake. Log the first nap to start predictions."
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
