//
//  ProfileView.swift
//  Jayla
//
//  The third tab: Jayla herself, as a keepsake — a cream card holding
//  a taped-down polaroid (tap the photo to change it), a handwritten
//  caption, her birth date and age. Tapping the caption or the date
//  opens one small sheet to edit name and birthday. Changes autosave;
//  there is no Save button to forget at 3am. Birthday edits reschedule
//  reminders, because the age band drives the prediction priors.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Bindable var baby: BabyProfile

    @Environment(\.modelContext) private var modelContext
    @State private var pickerItem: PhotosPickerItem?
    @State private var isEditing = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                keepsakeCard
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await applyPickedPhoto(item) }
        }
        .onChange(of: baby.name) {
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
                .padding(.top, 40)
                .padding(.bottom, 30)

            // The date and age read as one keepsake line; tapping either
            // opens the same edit sheet as the caption.
            Button {
                isEditing = true
            } label: {
                VStack(spacing: 2) {
                    Text("born \(baby.birthdate.formatted(.dateTime.day().month(.wide).year()))")
                        .font(Theme.handwritten(30, relativeTo: .title2))
                        .foregroundStyle(Theme.keepsakeDate)
                    Text(baby.keepsakeAge)
                        .font(Theme.text(15, .extraBold, relativeTo: .subheadline))
                        .foregroundStyle(Theme.softInk)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Born \(baby.birthdate.formatted(date: .long, time: .omitted)). \(baby.keepsakeAge)")
            .accessibilityHint("Edits her name and birthday")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 34)
        .background(Theme.keepsakeCard, in: RoundedRectangle(cornerRadius: 32))
        .cardShadow()
    }

    // MARK: - Polaroid

    private var polaroid: some View {
        VStack(spacing: 8) {
            photoArea

            // The chin caption — tap to edit her name.
            Button {
                isEditing = true
            } label: {
                Text("our \(baby.name) 💛")
                    .font(Theme.handwritten(30, relativeTo: .title2))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Our \(baby.name)")
            .accessibilityHint("Edits her name and birthday")
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
            Text("⭐️").font(.system(size: 34)).offset(x: 30, y: 16)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottomLeading) {
            Text("🌙").font(.system(size: 30)).offset(x: -32, y: -40)
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
            .frame(width: 224, height: 224)
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

    private func applyPickedPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = PhotoProcessing.downscaledJPEG(from: data) else { return }
        baby.photoData = jpeg
        try? modelContext.save()
    }
}

// MARK: - Edit sheet

/// Name + birthday in one small sheet — the fields autosave through the
/// parent's onChange handlers, so Done just closes it.
private struct EditDetailsSheet: View {
    @Bindable var baby: BabyProfile

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("Her details")
                .font(Theme.display(20, relativeTo: .title3))
                .foregroundStyle(Theme.ink)
                .padding(.top, 24)

            VStack(spacing: 0) {
                HStack {
                    Text("Name")
                        .font(Theme.text(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.softInk)
                    TextField("Her name", text: $baby.name)
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
        .presentationDetents([.height(300)])
        .presentationBackground(Theme.background)
    }
}

#Preview {
    ProfileView(baby: BabyProfile(name: "Jayla",
                                  birthdate: Calendar.current.date(
                                      byAdding: .day, value: -2, to: .now)!))
        .modelContainer(for: [ActivityEvent.self, BabyProfile.self], inMemory: true)
}
