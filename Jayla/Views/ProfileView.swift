//
//  ProfileView.swift
//  Jayla
//
//  The third tab: Jayla herself. Minimal on purpose — the photo (tap
//  to change, same flow as the home header), her name and age, and
//  one card to edit name and birthday. Changes autosave; there is no
//  Save button to forget at 3am. Birthday edits reschedule reminders,
//  because the age band drives the prediction priors.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Bindable var baby: BabyProfile

    @Environment(\.modelContext) private var modelContext
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 6) {
                    photoCircle
                        .padding(.top, 24)

                    Text(baby.name)
                        .font(Theme.display(26, relativeTo: .title))
                        .foregroundStyle(Theme.ink)
                    Text(baby.ageDescription)
                        .font(Theme.text(14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.softInk)

                    detailsCard
                        .padding(.top, 18)
                }
                .padding(.horizontal, 20)
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
    }

    private var photoCircle: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Group {
                if let data = baby.photoData, let image = Image(photoData: data) {
                    image.resizable().scaledToFill()
                } else {
                    Circle()
                        .fill(Theme.sleepBadge)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 36))
                                .foregroundStyle(Theme.sleepInk)
                        )
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 4))
            .cardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(baby.photoData == nil
            ? "Add a photo of \(baby.name)" : "\(baby.name)'s photo")
        .accessibilityHint("Chooses a new photo")
    }

    private var detailsCard: some View {
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
    }

    private func applyPickedPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = PhotoProcessing.downscaledJPEG(from: data) else { return }
        baby.photoData = jpeg
        try? modelContext.save()
    }
}

#Preview {
    ProfileView(baby: BabyProfile(name: "Jayla",
                                  birthdate: Calendar.current.date(
                                      byAdding: .month, value: -5, to: .now)!))
        .modelContainer(for: [ActivityEvent.self, BabyProfile.self], inMemory: true)
}
