//
//  EditProfileView.swift
//  Lumoria App
//
//  Modal sheet presented from `ProfileView` for editing the signed-in
//  user's name, username, and avatar.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2058-20895
//

import SwiftUI
import Auth
import PhotosUI
import Supabase

struct EditProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var draftName: String = ""
    @State private var draftUsername: String = ""
    /// JPEG bytes of the (cropped) image waiting for save.
    @State private var draftAvatarData: Data? = nil
    @State private var avatarPickerItem: PhotosPickerItem? = nil
    /// Raw image pulled from PhotosPicker, waiting for the user to crop.
    @State private var pendingCropImage: UIImage? = nil

    @State private var isSaving = false
    @State private var saveError: String? = nil

    private var isNameDirty: Bool     { draftName != profileStore.name }
    private var isUsernameDirty: Bool { draftUsername != profileStore.username }
    private var isAvatarDirty: Bool   { draftAvatarData != nil }
    private var hasChanges: Bool      { isNameDirty || isUsernameDirty || isAvatarDirty }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s6) {
                    Text("Edit your profile")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.Text.primary)

                    avatar
                        .frame(width: 192, height: 192)
                        .frame(maxWidth: .infinity)

                    aboutYouSection

                    saveButton
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.top, 72)
                .padding(.bottom, Spacing.s8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.Background.default)

            LumoriaIconButton(
                systemImage: "xmark",
                size: .large,
                action: { dismiss() }
            )
            .padding(.horizontal, Spacing.s4)
            .padding(.top, Spacing.s4)
        }
        .onAppear {
            draftName = profileStore.name
            draftUsername = profileStore.username
            Analytics.track(.profileEditStarted)
        }
        .sheet(isPresented: Binding(
            get: { pendingCropImage != nil },
            set: { if !$0 { pendingCropImage = nil } }
        )) {
            if let raw = pendingCropImage {
                AvatarCropSheet(
                    image: raw,
                    onCommit: { cropped in
                        draftAvatarData = cropped.jpegData(compressionQuality: 0.85)
                        pendingCropImage = nil
                    },
                    onCancel: {
                        pendingCropImage = nil
                        avatarPickerItem = nil
                    }
                )
            }
        }
    }

    // MARK: - About you

    private var aboutYouSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("About you")
                .font(.title3.bold())
                .foregroundStyle(Color.Text.primary)

            LumoriaInputField(
                label: "Name",
                placeholder: "Your name",
                text: $draftName,
                isRequired: false,
                state: isNameDirty ? .warning : .default,
                assistiveText: isNameDirty
                    ? "You edited this field but it has not been saved yet."
                    : nil
            )

            LumoriaInputField(
                label: "Username",
                placeholder: "@username",
                text: $draftUsername,
                isRequired: false,
                state: isUsernameDirty ? .warning : .default,
                assistiveText: isUsernameDirty
                    ? "You edited this field but it has not been saved yet."
                    : nil
            )

            if let saveError {
                Text(saveError)
                    .font(.footnote)
                    .foregroundStyle(Color.Feedback.Danger.text)
            }
        }
    }

    // MARK: - Avatar

    private var avatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color("Colors/Blue/50"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.Border.default, lineWidth: 1)
                )

            avatarContent

            PhotosPicker(
                selection: $avatarPickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Color.black.opacity(0.07)
                    .overlay {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundStyle(Color.Text.primary)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(Color.Background.default))
                    }
            }
            .buttonStyle(.plain)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: avatarPickerItem) { _, new in
            guard let new else { return }
            Task { await loadPickedAvatar(new) }
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let data = draftAvatarData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 192, height: 192)
                .clipped()
        } else if let ui = profileStore.avatarImage {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 192, height: 192)
                .clipped()
        } else {
            Text(avatarInitial)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(Color.Text.secondary)
        }
    }

    private var avatarInitial: String {
        guard let first = draftName.first else { return "?" }
        return String(first).uppercased()
    }

    private func loadPickedAvatar(_ item: PhotosPickerItem) async {
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: raw)
        else { return }
        await MainActor.run {
            pendingCropImage = ui
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button(action: { Task { await save() } }) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .tint(Color.Text.OnColor.white)
                }
                Text("Save changes")
            }
        }
        .buttonStyle(LumoriaButtonStyle(hierarchy: .primary, size: .large))
        .disabled(!hasChanges || isSaving)
    }

    /// Pushes name + username + avatar changes to Supabase. Mirrors the
    /// previous in-place save flow on `ProfileView` — encrypted-blob
    /// upload to the private `avatars` bucket plus best-effort deletion
    /// of the prior file.
    private func save() async {
        guard hasChanges, !isSaving else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            var updates: [String: AnyJSON] = [:]
            var oldPathToDelete: String? = nil

            if let data = draftAvatarData {
                let encrypted = try EncryptionService.encrypt(data)
                let newPath = "\(UUID().uuidString).bin"
                _ = try await supabase.storage
                    .from("avatars")
                    .upload(
                        newPath,
                        data: encrypted,
                        options: FileOptions(
                            cacheControl: "3600",
                            contentType: "application/octet-stream",
                            upsert: false
                        )
                    )
                updates["avatar_path"] = .string(newPath)
                updates["avatar_url"] = .null
                oldPathToDelete = profileStore.avatarPath
            }

            if isNameDirty {
                updates["full_name"] = .string(
                    draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            if isUsernameDirty {
                updates["username"] = .string(
                    sanitizedUsername(draftUsername)
                )
            }

            if !updates.isEmpty {
                _ = try await supabase.auth.update(
                    user: UserAttributes(data: updates)
                )
            }

            if let oldPath = oldPathToDelete {
                _ = try? await supabase.storage
                    .from("avatars")
                    .remove(paths: [oldPath])
            }

            await profileStore.load()
            if isAvatarDirty {
                Analytics.track(.avatarUploaded(source: .library))
            }
            Analytics.track(.profileSaved(
                nameChanged: isNameDirty,
                avatarChanged: isAvatarDirty
            ))
            dismiss()
        } catch {
            saveError = String(localized: "Couldn’t save changes. \(error.localizedDescription)")
            print("[EditProfileView] save failed:", error)
            Analytics.track(.appError(
                domain: .auth,
                code: (error as NSError).code.description,
                viewContext: "EditProfileView.save"
            ))
        }
    }

    /// Strip a leading "@" the user might type, trim whitespace.
    /// Keeps the stored value canonical so the display layer can prepend
    /// "@" without doubling it.
    private func sanitizedUsername(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            trimmed.removeFirst()
        }
        return trimmed
    }
}

// MARK: - Preview

#Preview {
    EditProfileView()
        .environmentObject(ProfileStore())
}
