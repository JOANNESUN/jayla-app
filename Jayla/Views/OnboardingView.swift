//
//  OnboardingView.swift
//  Jayla
//
//  First-run setup: collect the baby's name, gender, birthday, and an
//  optional photo, then create the BabyProfile. Shown by ContentView
//  whenever no profile exists yet.
//

import SwiftUI
import SwiftData
import PhotosUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var gender = Gender.girl
    @State private var birthdate = Date.now
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoData: Data?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var canSave: Bool { !trimmedName.isEmpty }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 12)

                VStack(spacing: 6) {
                    Text("Welcome to Jayla")
                        .font(Theme.display(28, relativeTo: .title))
                        .foregroundStyle(Theme.ink)
                    Text("Let's set up your baby's profile")
                        .font(Theme.text(16, relativeTo: .callout))
                        .foregroundStyle(Theme.softInk)
                }

                VStack(spacing: 10) {
                    photoPicker
                    Text("Optional — you can change it any time")
                        .font(Theme.text(13, relativeTo: .footnote))
                        .foregroundStyle(Theme.softInk)
                }

                VStack(spacing: 14) {
                    nameField
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22))
                        .cardShadow()

                    HStack {
                        Text("Gender")
                            .font(Theme.text(17, relativeTo: .body))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        GenderPills(gender: $gender)
                    }
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))
                    .cardShadow()

                    HStack {
                        // Visible label; hidden from VoiceOver because the
                        // DatePicker below speaks its own "Birthday".
                        Text("Birthday")
                            .font(Theme.text(17, relativeTo: .body))
                            .foregroundStyle(Theme.ink)
                            .accessibilityHidden(true)
                        Spacer()
                        DatePicker("Birthday",
                                   selection: $birthdate,
                                   in: ...Date.now,
                                   displayedComponents: .date)
                            .labelsHidden()
                            .tint(Theme.accent)
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))
                    .cardShadow()
                }

                Spacer()

                Button(action: save) {
                    Text("Get started")
                        .font(Theme.display(17, relativeTo: .headline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSave ? Theme.accent : Theme.softInk, in: Capsule())
                        .shadow(color: Theme.accent.opacity(canSave ? 0.25 : 0), radius: 12, y: 6)
                }
                .disabled(!canSave)
            }
            .padding(24)
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photoData = PhotoProcessing.downscaledJPEG(from: data)
                }
            }
        }
    }

    private var nameField: some View {
        let field = TextField("Baby's name", text: $name)
            .font(Theme.text(17, relativeTo: .body))
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
        #if os(iOS)
        return field.textInputAutocapitalization(.words)
        #else
        return field
        #endif
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Group {
                if let photoData, let image = Image(photoData: photoData) {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(Theme.sleepBadge)
                        .overlay(
                            VStack(spacing: 6) {
                                // Fixed icon size: decorative, inside a
                                // fixed 120pt circle.
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24))
                                Text("Add photo")
                                    .font(Theme.text(13, relativeTo: .footnote))
                            }
                            .foregroundStyle(Theme.sleepInk)
                        )
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.08), radius: 15, y: 6)
        }
        .accessibilityLabel(photoData == nil ? "Add photo" : "Baby photo")
        .accessibilityHint("Chooses a photo")
    }

    private func save() {
        let baby = BabyProfile(name: trimmedName,
                               birthdate: birthdate,
                               gender: gender,
                               photoData: photoData)
        modelContext.insert(baby)
        try? modelContext.save()
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [ActivityEvent.self, BabyProfile.self], inMemory: true)
}
