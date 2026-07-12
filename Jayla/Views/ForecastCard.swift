//
//  ForecastCard.swift
//  Jayla
//
//  The keepsake page's nursery weather channel — the fun face of the
//  prediction engine. Current "conditions", a five-hour outlook strip,
//  and a fuss warning when a rough patch (hunger or tiredness building
//  toward predicted relief) is on the radar. Display-only: it never
//  logs, never notifies — that's the home screen's job.
//

import SwiftUI

struct ForecastCard: View {
    let babyName: String
    let forecast: ForecastEngine.Forecast?
    let now: Date

    var body: some View {
        // Compact on purpose: the profile page fits the keepsake card
        // and this one on a single screen, no scrolling.
        VStack(alignment: .leading, spacing: 12) {
            header

            if let forecast {
                moodRow(forecast)
                hourStrip(forecast.slots)
                if let warning = forecast.fussWarning {
                    warningLine(at: warning)
                }
            } else {
                Text("her forecast rolls in with the first feed or nap ☁️")
                    .font(Theme.text(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.softInk)
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .cardShadow()
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Text("\(babyName.uppercased()) FORECAST")
                .font(Theme.text(12, .black, relativeTo: .caption))
                .tracking(1.5)
                .foregroundStyle(Theme.sleepInk)
            Spacer()
            Text(now.formatted(.dateTime.weekday(.abbreviated).hour().minute()).uppercased())
                .font(Theme.text(11, relativeTo: .caption2))
                .foregroundStyle(Theme.softInk)
        }
        .accessibilityElement(children: .combine)
    }

    private func moodRow(_ forecast: ForecastEngine.Forecast) -> some View {
        HStack(spacing: 12) {
            Text(emoji(for: forecast.mood))
                .font(.system(size: 34))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(label(for: forecast.mood))
                    .font(Theme.display(21, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                // Same gentle caveat suffix the home hero uses.
                Text(feelsLike(forecast.mood)
                     + (forecast.isLearning ? " · still learning" : ""))
                    .font(Theme.text(12, relativeTo: .caption))
                    .foregroundStyle(Theme.softInk)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func hourStrip(_ slots: [ForecastEngine.Slot]) -> some View {
        HStack(spacing: 0) {
            ForEach(slots, id: \.hour) { slot in
                VStack(spacing: 4) {
                    Text(hourLabel(slot.hour))
                        .font(Theme.text(11, relativeTo: .caption2))
                        .foregroundStyle(Theme.softInk)
                    Text(emoji(for: slot.state))
                        .font(.system(size: 18))
                        .accessibilityHidden(true)
                    Text(label(for: slot.state))
                        .font(Theme.text(11, .extraBold, relativeTo: .caption2))
                        .foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(hourLabel(slot.hour)): \(label(for: slot.state))")
            }
        }
        .padding(.vertical, 10)
        .background(Theme.sleepBadge, in: RoundedRectangle(cornerRadius: 14))
    }

    /// One slim line, not a box — the compact page has no room for a
    /// two-row banner and the message survives the squeeze.
    private func warningLine(at hour: Date) -> some View {
        HStack(spacing: 6) {
            Text("⚠️")
                .font(.system(size: 12))
                .accessibilityHidden(true)
            Text("cranky front around \(hourLabel(hour)) — feed and cuddle ready")
                .font(Theme.text(12, .extraBold, relativeTo: .caption))
                .foregroundStyle(Theme.peeCount)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.peach.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fuss warning: cranky front around \(hourLabel(hour)). Have a feed and a cuddle ready.")
    }

    // MARK: - Copy

    private func emoji(for mood: ForecastEngine.Mood) -> String {
        switch mood {
        case .snoozing:      "😴"
        case .content:       "😊"
        case .gettingHungry: "🥺"
        case .hungry:        "😫"
        case .sleepy:        "🥱"
        case .learning:      "🔮"
        }
    }

    private func label(for mood: ForecastEngine.Mood) -> String {
        switch mood {
        case .snoozing:      "Snoozing"
        case .content:       "Content"
        case .gettingHungry: "Peckish"
        case .hungry:        "Hangry"
        case .sleepy:        "Sleepy"
        case .learning:      "Fair-ish"
        }
    }

    private func feelsLike(_ mood: ForecastEngine.Mood) -> String {
        switch mood {
        case .snoozing:      "feels like: dreamland"
        case .content:       "feels like: recently fed"
        case .gettingHungry: "feels like: milk o'clock soon"
        case .hungry:        "feels like: milk overdue"
        case .sleepy:        "feels like: nap window open"
        case .learning:      "feels like: getting to know her"
        }
    }

    private func emoji(for state: ForecastEngine.SlotState) -> String {
        switch state {
        case .nap:   "😴"
        case .feed:  "🍼"
        case .fussy: "🌧️"
        case .chill: "☀️"
        case .bed:   "🌙"
        }
    }

    private func label(for state: ForecastEngine.SlotState) -> String {
        switch state {
        case .nap:   "nap"
        case .feed:  "feed"
        case .fussy: "fussy"
        case .chill: "chill"
        case .bed:   "bed"
        }
    }

    /// "3pm" — the outlook strip's compact hour label.
    private func hourLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour()).lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{202f}", with: "")
    }
}

#Preview {
    let now = Date.now
    let cal = Calendar.current
    let hour = cal.dateInterval(of: .hour, for: now)!.end
    return ZStack {
        Theme.background.ignoresSafeArea()
        ForecastCard(
            babyName: "Jayla",
            forecast: ForecastEngine.Forecast(
                mood: .content,
                slots: [
                    .init(hour: hour, state: .nap),
                    .init(hour: hour.addingTimeInterval(3_600), state: .fussy),
                    .init(hour: hour.addingTimeInterval(7_200), state: .feed),
                    .init(hour: hour.addingTimeInterval(10_800), state: .chill),
                    .init(hour: hour.addingTimeInterval(14_400), state: .bed),
                ],
                fussWarning: hour.addingTimeInterval(3_600),
                isLearning: true),
            now: now)
            .padding(20)
    }
}
