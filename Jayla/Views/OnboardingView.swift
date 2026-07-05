//
//  OnboardingView.swift
//  Jayla
//
//  First-run setup: collect the baby's name, birthday, and an optional
//  photo, then create the BabyProfile. Shown by ContentView whenever no
//  profile exists yet.
//

import SwiftUI
import SwiftData
import PhotosUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
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
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("Let's set up your baby's profile")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(Theme.softInk)
                }

                photoPicker

                VStack(spacing: 14) {
                    nameField
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22))
                        .cardShadow()

                    HStack {
                        Text("Birthday")
                            .font(.system(size: 17, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        DatePicker("",
                                   selection: $birthdate,
                                   in: ...Date.now,
                                   displayedComponents: .date)
                            .labelsHidden()
                            .tint(Theme.accent)
                    }
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))
                    .cardShadow()
                }

                Spacer()

                Button(action: save) {
                    Text("Get started")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
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
            .font(.system(size: 17, design: .rounded))
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
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24))
                                Text("Add photo")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(Theme.sleepInk)
                        )
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.08), radius: 15, y: 6)
        }
    }

    private func save() {
        let baby = BabyProfile(name: trimmedName,
                               birthdate: birthdate,
                               photoData: photoData)
        modelContext.insert(baby)
        try? modelContext.save()
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [ActivityEvent.self, BabyProfile.self], inMemory: true)
}
