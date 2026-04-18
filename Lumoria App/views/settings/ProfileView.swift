//
//  ProfileView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=970-22520
//          figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1127-267138
//          figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1127-267408
//

import SwiftUI
import Auth
import PhotosUI
import ProgressiveBlurHeader
import Supabase

struct ProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var memoriesStore: MemoriesStore
    @EnvironmentObject private var profileStore: ProfileStore

    // Draft values while editing.
    @State private var draftName: String = ""
    /// JPEG bytes of the (cropped) image waiting for save.
    @State private var draftAvatarData: Data? = nil
    @State private var avatarPickerItem: PhotosPickerItem? = nil
    /// Raw image pulled from PhotosPicker, waiting for the user to crop.
    @State private var pendingCropImage: UIImage? = nil

    @State private var isEditing = false
    @State private var showMenu = false
    @State private var isSaving = false
    @State private var saveError: String? = nil

    private var isNameDirty: Bool   { isEditing && draftName != profileStore.name }
    private var isAvatarDirty: Bool { isEditing && draftAvatarData != nil }
    private var hasChanges: Bool    { isNameDirty || isAvatarDirty }

    var body: some View {
        ZStack(alignment: .top) {
            StickyBlurHeader(maxBlurRadius: 8, fadeExtension: 48) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            } content: {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profile")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.Text.primary)
                        .padding(.top, 8)

                    ZStack(alignment: .top) {
                        card
                            .padding(.top, 96)

                        avatar
                            .frame(width: 192, height: 192)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .background(Color.Background.default.ignoresSafeArea())

            if showMenu {
                menuOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.2), value: isEditing)
        .onAppear { Analytics.track(.profileViewed) }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            LumoriaIconButton(
                systemImage: "chevron.left",
                position: .onBackground
            ) {
                if isEditing {
                    cancelEdit()
                } else {
                    dismiss()
                }
            }

            Spacer(minLength: 0)

            if isEditing {
                saveButton
            } else {
                LumoriaIconButton(
                    systemImage: "ellipsis",
                    position: .onBackground,
                    isActive: showMenu
                ) {
                    withAnimation(.easeOut(duration: 0.15)) { showMenu.toggle() }
                }
            }
        }
    }

    private var saveButton: some View {
        Button(action: { Task { await save() } }) {
            Image(systemName: "checkmark")
                .font(.title3)
                .foregroundStyle(Color.Text.OnColor.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(Color("Colors/Green/500"))
                )
                .overlay {
                    if isSaving {
                        ProgressView()
                            .tint(Color.Text.OnColor.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!hasChanges || isSaving)
        .opacity((hasChanges && !isSaving) ? 1 : 0.4)
    }

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 24) {
            aboutYouSection

            if !isEditing {
                sinceYouJoinedSection
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 112)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }

    private var aboutYouSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("About you")

            if isEditing {
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
            } else {
                ProfileDisplayField(label: "Name", value: profileStore.name)
            }

            if let saveError {
                Text(saveError)
                    .font(.footnote)
                    .foregroundStyle(Color.Feedback.Danger.text)
            }
        }
    }

    private var sinceYouJoinedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Since you joined")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 16
            ) {
                LumoriaDataCard(
                    content: .value(
                        "\(memoriesStore.memories.count)",
                        caption: "memories created"
                    ),
                    accentColorFamily: "Orange"
                )
                LumoriaDataCard(
                    content: .value(
                        "\(ticketsThisMonth)",
                        caption: "tickets created this month"
                    ),
                    accentColorFamily: "Blue"
                )
                LumoriaDataCard(
                    content: .value(
                        "\(ticketsThisYear)",
                        caption: "tickets created this year"
                    ),
                    accentColorFamily: "Pink"
                )
                LumoriaDataCard(
                    content: longestGapContent,
                    accentColorFamily: "Yellow"
                )
                LumoriaDataCard(
                    content: .value(
                        mostUsedCategoryName,
                        caption: "Most used category"
                    ),
                    accentColorFamily: "Lime"
                )
            }
        }
    }

    // MARK: - Stats

    private var ticketsThisMonth: Int {
        ticketsStore.tickets
            .filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }
            .count
    }

    private var ticketsThisYear: Int {
        ticketsStore.tickets
            .filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .year) }
            .count
    }

    /// Largest interval between two consecutive tickets' creation dates.
    /// Returns `.valueWithSuffix` in months if the gap is ≥ 1 month, else
    /// in days. `.value("—", …)` when fewer than 2 tickets exist.
    private var longestGapContent: LumoriaDataCardContent {
        let sorted = ticketsStore.tickets
            .map(\.createdAt)
            .sorted()
        guard sorted.count >= 2 else {
            return .value("—", caption: "Longest gap between tickets")
        }
        let intervals = zip(sorted.dropFirst(), sorted)
            .map { $0.timeIntervalSince($1) }
        guard let maxSeconds = intervals.max(), maxSeconds > 0 else {
            return .value("—", caption: "Longest gap between tickets")
        }
        let days = Int(maxSeconds / 86_400)
        if days >= 30 {
            let months = days / 30
            return .valueWithSuffix(
                "\(months)",
                suffix: months == 1 ? "month" : "months",
                caption: "Longest gap between tickets"
            )
        }
        return .valueWithSuffix(
            "\(days)",
            suffix: days == 1 ? "day" : "days",
            caption: "Longest gap between tickets"
        )
    }

    /// Category the user has created the most tickets in. Returns "—"
    /// when the user has no tickets yet.
    private var mostUsedCategoryName: String {
        let counts = Dictionary(
            grouping: ticketsStore.tickets,
            by: { $0.kind.categoryStyle }
        )
        .mapValues(\.count)
        guard let winner = counts.max(by: { $0.value < $1.value })?.key else {
            return "—"
        }
        return winner.displayName
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
            .foregroundStyle(Color.Text.primary)
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

            if isEditing {
                PhotosPicker(
                    selection: $avatarPickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Color.Border.hairline
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
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: avatarPickerItem) { _, new in
            guard let new else { return }
            Task { await loadPickedAvatar(new) }
        }
        .fullScreenCover(isPresented: Binding(
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
            avatarInitialView
        }
    }

    private var avatarInitialView: some View {
        Text(avatarInitial)
            .font(.system(size: 72, weight: .semibold))
            .foregroundStyle(Color.Text.secondary)
    }

    private var avatarInitial: String {
        let source = isEditing ? draftName : profileStore.name
        guard let first = source.first else { return "?" }
        return String(first).uppercased()
    }

    // MARK: - Photo picker → crop → draft data

    /// Routes the picked image through the crop sheet. The sheet's
    /// `onCommit` writes a 512×512 square `UIImage` back to
    /// `draftAvatarData` as JPEG bytes.
    private func loadPickedAvatar(_ item: PhotosPickerItem) async {
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: raw)
        else { return }
        await MainActor.run {
            pendingCropImage = ui
        }
    }

    // MARK: - Menu overlay

    private var menuOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.12)) { showMenu = false }
                }

            LumoriaContextualMenu(items: [
                LumoriaMenuItem(title: "Edit") {
                    showMenu = false
                    beginEdit()
                },
                LumoriaMenuItem(title: "Delete my account", kind: .destructive) {
                    showMenu = false
                    // TODO: confirm + call auth.deleteUser
                },
            ])
            .padding(.top, 62)
            .padding(.trailing, 16)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
        }
    }

    // MARK: - Edit lifecycle

    private func beginEdit() {
        draftName = profileStore.name
        draftAvatarData = nil
        avatarPickerItem = nil
        saveError = nil
        Analytics.track(.profileEditStarted)
        withAnimation(.easeInOut(duration: 0.2)) { isEditing = true }
    }

    private func cancelEdit() {
        draftAvatarData = nil
        avatarPickerItem = nil
        saveError = nil
        withAnimation(.easeInOut(duration: 0.2)) { isEditing = false }
    }

    // MARK: - Save

    /// Pushes name + avatar changes to Supabase.
    ///
    /// Avatar flow:
    /// 1. Encrypt JPEG bytes with the user's device key so the bucket only
    ///    ever holds ciphertext.
    /// 2. Upload to `<random-uuid>.bin` in the private `avatars` bucket —
    ///    the path is opaque and doesn't encode user identity.
    /// 3. Write the new path into `user_metadata.avatar_path` alongside
    ///    `full_name`, and null out any legacy `avatar_url` pointer.
    /// 4. Best-effort delete the previous file so the bucket doesn't
    ///    accumulate stale avatars.
    ///
    /// NOTE: requires a PRIVATE `avatars` bucket in Supabase Storage.
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
                // Null the legacy public-URL pointer so old clients don't
                // try to load a stale public file.
                updates["avatar_url"] = .null
                oldPathToDelete = profileStore.avatarPath
            }

            if isNameDirty {
                updates["full_name"] = .string(
                    draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            if !updates.isEmpty {
                _ = try await supabase.auth.update(
                    user: UserAttributes(data: updates)
                )
            }

            // Best-effort cleanup of the old ciphertext; ignore errors so a
            // failed delete doesn't block the save.
            if let oldPath = oldPathToDelete {
                _ = try? await supabase.storage
                    .from("avatars")
                    .remove(paths: [oldPath])
            }

            await profileStore.load()
            let nameChanged = isNameDirty
            let avatarChanged = isAvatarDirty
            if avatarChanged {
                Analytics.track(.avatarUploaded(source: .library))
            }
            Analytics.track(.profileSaved(nameChanged: nameChanged, avatarChanged: avatarChanged))
            draftAvatarData = nil
            avatarPickerItem = nil
            withAnimation(.easeInOut(duration: 0.2)) { isEditing = false }
        } catch {
            saveError = String(localized: "Couldn’t save changes. \(error.localizedDescription)")
            print("[ProfileView] save failed:", error)
            Analytics.track(.appError(
                domain: .auth,
                code: (error as NSError).code.description,
                viewContext: "ProfileView.save"
            ))
        }
    }
}

// MARK: - Display field (read-only)

struct ProfileDisplayField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)

            HStack(spacing: 8) {
                Text(value)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.Background.fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.Border.hairline, lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environmentObject(TicketsStore())
    .environmentObject(MemoriesStore())
    .environmentObject(ProfileStore())
}
