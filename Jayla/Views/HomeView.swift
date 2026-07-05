//
//  HomeView.swift
//  Jayla
//
//  The main dashboard: greeting + baby photo hero + the four log cards.
//  Shown by ContentView once a BabyProfile exists. Tapping the hero photo
//  or the header avatar opens the photo picker to replace the picture.
//

import SwiftUI
import SwiftData
import PhotosUI

struct HomeView: View {
    let baby: BabyProfile

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    hero
                    trackers
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await applyPickedPhoto(item) }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hello,")
                    .font(.system(size: 18, design: .rounded))
                    .foregroundStyle(Theme.softInk)
                Text("\(baby.name)!")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(baby.ageDescription)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Theme.softInk)
            }

            Spacer()

            HStack(spacing: 12) {
                avatar

                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 10, height: 10)
                        .offset(x: -4, y: 4)
                }
            }
        }
        .padding(.top, 8)
    }

    // Tapping the avatar opens the picker to replace the photo.
    private var avatar: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Group {
                if let data = baby.photoData, let image = Image(photoData: data) {
                    image.resizable().scaledToFill()
                } else {
                    Circle()
                        .fill(Theme.sleepBadge)
                        .overlay(
                            Text(String(baby.name.prefix(1)))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.sleepInk)
                        )
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottom) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                photoBlock
            }
            .buttonStyle(.plain)

            statusCard
                .padding(.horizontal, 16)
                .offset(y: 28)
        }
        .padding(.bottom, 28) // reserve space for the offset overhang
    }

    private var photoBlock: some View {
        Group {
            if let data = baby.photoData, let image = Image(photoData: data) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 34))
            } else {
                RoundedRectangle(cornerRadius: 34)
                    .fill(Theme.sleepBadge)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "figure.child")
                                .font(.system(size: 60))
                            Text("Tap to add a photo")
                                .font(.system(size: 14, design: .rounded))
                        }
                        .foregroundStyle(Theme.sleepInk)
                    )
            }
        }
    }

    // Shows the most recent feed. In Phase 2 this becomes the prediction
    // ("Next feed in 1h 0m") driven by the PredictionEngine.
    private var statusCard: some View {
        let lastFeed = lastEvent(.feed)
        return HStack(spacing: 14) {
            Circle()
                .fill(Theme.feedBadge)
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Theme.feedInk)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Last feed")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(lastFeed.map(relativeText) ?? "Not logged yet")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.softInk)
            }

            Spacer()

            if let lastFeed {
                Text(timeText(lastFeed.timestamp))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.feedInk)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.08), radius: 15, y: 6)
    }

    // MARK: - Trackers

    private var trackers: some View {
        VStack(spacing: 14) {
            ForEach(ActivityType.allCases) { type in
                TrackerCard(
                    icon: type.icon,
                    badgeColor: type.badgeColor,
                    inkColor: type.inkColor,
                    title: type.label,
                    prediction: subtitle(for: type),
                    confidence: "",
                    buttonLabel: type.logButtonLabel,
                    onLog: { log(type) }
                )
            }
        }
    }

    // MARK: - Data helpers

    private func lastEvent(_ type: ActivityType) -> ActivityEvent? {
        events.first { $0.type == type }
    }

    private func subtitle(for type: ActivityType) -> String {
        guard let last = lastEvent(type) else { return "Tap to log the first one" }
        return "Last \(relativeText(last))"
    }

    private func log(_ type: ActivityType) {
        ActivityRepository(context: modelContext).log(type)
    }

    private func applyPickedPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = PhotoProcessing.downscaledJPEG(from: data) else { return }
        baby.photoData = jpeg
        try? modelContext.save()
    }

    // MARK: - Formatting

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func relativeText(_ event: ActivityEvent) -> String {
        event.timestamp.formatted(.relative(presentation: .named))
    }
}
