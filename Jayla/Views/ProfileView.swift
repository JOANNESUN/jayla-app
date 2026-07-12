//
//  ProfileView.swift
//  Jayla
//
//  The third tab: Jayla herself, as a keepsake — a cream card holding
//  a taped-down polaroid (tap the photo to change it, ♡ for a chin),
//  her name big underneath with an age pill and a born · zodiac line.
//  Tapping any of it opens one small sheet to edit name, birthday and
//  gender (a girl/boy pill tab that drives the app's pronouns).
//  Changes autosave; there is no Save button to forget at 3am. Birthday
//  edits reschedule reminders, because the age band drives the
//  prediction priors. Below the keepsake sits the forecast card — the
//  prediction engine wearing its weather-channel costume.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Bindable var baby: BabyProfile

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    @State private var pickerItem: PhotosPickerItem?
    @State private var isEditing = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // everyMinute keeps the forecast's "now" honest while the
            // page is open; logging elsewhere refreshes via @Query.
            // Both cards are sized to share one screen — the ScrollView
            // only earns its keep at accessibility text sizes.
            TimelineView(.everyMinute) { timeline in
                ScrollView {
                    VStack(spacing: 12) {
                        keepsakeCard
                        ForecastCard(babyName: baby.name,
                                     gender: baby.gender,
                                     forecast: forecast(now: timeline.date),
                                     now: timeline.date)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await applyPickedPhoto(item) }
        }
        .onChange(of: baby.name) {
            try? modelContext.save()
        }
        .onChange(of: baby.genderRaw) {
            try? modelContext.save()
        }
        .onChange(of: baby.birthdate) {
            try? modelContext.save()
            // Age band feeds the prediction priors, so a corrected
            // birthday should move the pending reminders too.
            Task { await Rescheduler.recomputeAndReschedule() }
        }
        .sheet(isPresented: $isEditing) {
            EditDetailsSheet(baby: baby)
        }
    }

    // MARK: - Keepsake card

    private var keepsakeCard: some View {
        VStack(spacing: 4) {
            polaroid
                .padding(.top, 22)
                .padding(.bottom, 18)

            // Name front and center, magazine-cover style: big name
            // (with a little pencil so editing is discoverable), age
            // pill, then one small born · zodiac line. All of it is one
            // tap target for the same edit sheet.
            Button {
                isEditing = true
            } label: {
                VStack(spacing: 8) {
                    HStack(spacing: 7) {
                        Text(baby.name)
                            .font(Theme.display(30, relativeTo: .largeTitle))
                            .foregroundStyle(Theme.ink)
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.softInk.opacity(0.55))
                            .accessibilityHidden(true)
                    }
                    HStack(spacing: 6) {
                        Text("🎂")
                        Text(baby.keepsakeAge)
                            .font(Theme.text(14, .extraBold, relativeTo: .subheadline))
                            .foregroundStyle(Theme.keepsakeDate)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Theme.background, in: Capsule())
                    Text("born \(baby.birthdate.formatted(.dateTime.day().month(.wide).year())) · \(baby.zodiacSign)")
                        .font(Theme.text(12, relativeTo: .footnote))
                        .foregroundStyle(Theme.softInk)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(baby.name). \(baby.keepsakeAge). Born \(baby.birthdate.formatted(date: .long, time: .omitted)), \(baby.zodiacSign)")
            .accessibilityHint("Edits \(baby.gender.possessive) details")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 18)
        .background(Theme.keepsakeCard, in: RoundedRectangle(cornerRadius: 28))
        .cardShadow()
    }

    // MARK: - Polaroid

    private var polaroid: some View {
        VStack(spacing: 8) {
            photoArea

            // The chin keeps just a handwritten heart — the name moved
            // below the polaroid, big. Still a tap target for the sheet.
            Button {
                isEditing = true
            } label: {
                Text("♡")
                    .font(Theme.handwritten(24, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Our \(baby.name)")
            .accessibilityHint("Edits \(baby.gender.possessive) details")
        }
        .padding(12)
        .padding(.bottom, 6)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .cardShadow()
        .overlay(alignment: .top) { tape.offset(y: -13) }
        .rotationEffect(.degrees(-2))
        // Star and moon floating beside the polaroid, like stickers on
        // the keepsake card.
        .overlay(alignment: .topTrailing) {
            Text("⭐️").font(.system(size: 28)).offset(x: 24, y: 12)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottomLeading) {
            Text("🌙").font(.system(size: 24)).offset(x: -26, y: -32)
                .accessibilityHidden(true)
        }
    }

    /// A strip of washi tape holding the polaroid to the card.
    private var tape: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Theme.keepsakeTape.opacity(0.75))
            .frame(width: 92, height: 26)
            .rotationEffect(.degrees(-3))
    }

    // The photo is the one place to change the picture. Fixed size on
    // purpose: it's an image, not text — Dynamic Type shouldn't inflate it.
    private var photoArea: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Group {
                if let data = baby.photoData, let image = Image(photoData: data) {
                    image.resizable().scaledToFill()
                } else {
                    photoPlaceholder
                }
            }
            .frame(width: 170, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(baby.photoData == nil
            ? "Add a photo of \(baby.name)" : "\(baby.name)'s photo")
        .accessibilityHint("Chooses a new photo")
    }

    private var photoPlaceholder: some View {
        ZStack {
            Rectangle().fill(Color(hex: "F3F1EC"))
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(hex: "B9B4AB"))
                Text("add a photo")
                    .font(Theme.text(14, relativeTo: .footnote))
                    .foregroundStyle(Color(hex: "8F897E"))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color(hex: "C9C3B8"),
                              style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .padding(7)
        )
    }

    // MARK: - Forecast

    /// Same event plumbing as HomeView, funnelled through the adapter —
    /// the forecast card shows the home screen's predictions, restyled.
    private func forecast(now: Date) -> ForecastEngine.Forecast? {
        ForecastEngine.forecast(.build(
            feedTimestamps: events
                .filter { $0.typeRaw == ActivityType.feed.rawValue }
                .map(\.timestamp),
            sleeps: events
                .filter { $0.typeRaw == ActivityType.sleep.rawValue }
                .map { (start: $0.timestamp, duration: $0.durationSeconds) },
            ageBand: baby.ageBand,
            now: now))
    }

    private func applyPickedPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = PhotoProcessing.downscaledJPEG(from: data) else { return }
        baby.photoData = jpeg
        try? modelContext.save()
    }
}

// MARK: - Edit sheet

/// Name + birthday + gender in one small sheet — the fields autosave
/// through the parent's onChange handlers, so Done just closes it.
private struct EditDetailsSheet: View {
    @Bindable var baby: BabyProfile

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("\(baby.gender.possessive.capitalized) details")
                .font(Theme.display(20, relativeTo: .title3))
                .foregroundStyle(Theme.ink)
                .padding(.top, 24)

            VStack(spacing: 0) {
                HStack {
                    Text("Name")
                        .font(Theme.text(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.softInk)
                    TextField("Baby's name", text: $baby.name)
                        .font(Theme.text(15, .extraBold, relativeTo: .subheadline))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.trailing)
                        // macOS has no autocapitalization, and the fast
                        // type-check build compiles for it.
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                }
                .padding(.vertical, 14)

                Rectangle()
                    .fill(Theme.background)
                    .frame(height: 2)

                HStack {
                    Text("Birthday")
                        .font(Theme.text(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.softInk)
                    Spacer()
                    DatePicker("Birthday",
                               selection: $baby.birthdate,
                               in: ...Date.now,
                               displayedComponents: .date)
                        .labelsHidden()
                        .tint(Theme.accent)
                }
                .padding(.vertical, 8)

                Rectangle()
                    .fill(Theme.background)
                    .frame(height: 2)

                HStack {
                    Text("Gender")
                        .font(Theme.text(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.softInk)
                    Spacer()
                    genderPill(.girl)
                    genderPill(.boy)
                }
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 18)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .cardShadow()
            .padding(.horizontal, 24)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(Theme.display(17, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(360)])
        .presentationBackground(Theme.background)
    }

    /// The gender tab: two pills, girl fills blossom pink and boy fills
    /// sky blue — the feed and sleep palettes moonlighting.
    private func genderPill(_ gender: Gender) -> some View {
        let selected = baby.gender == gender
        let ink = gender == .girl ? Theme.feedInk : Theme.sleepInk
        let badge = gender == .girl ? Theme.feedBadge : Theme.sleepBadge
        return Button {
            guard baby.gender != gender else { return }
            baby.gender = gender
            Haptics.tap()
        } label: {
            Text(gender == .girl ? "Girl" : "Boy")
                .font(Theme.text(14, .extraBold, relativeTo: .subheadline))
                .foregroundStyle(selected ? ink : Theme.softInk)
                .padding(.horizontal, 18)
                .frame(minHeight: 34)
                .background(selected ? badge : .white, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        selected ? ink : Theme.softInk.opacity(0.35),
                        lineWidth: selected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    ProfileView(baby: BabyProfile(name: "Jayla",
                                  birthdate: Calendar.current.date(
                                      byAdding: .day, value: -2, to: .now)!))
        .modelContainer(for: [ActivityEvent.self, BabyProfile.self], inMemory: true)
}
