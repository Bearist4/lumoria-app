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
import Supabase

struct ProfileView: View {

    @Environment(\.dismiss) private var dismiss

    // Persisted values (source of truth after save — will be swapped for a
    // real Supabase `profiles` row once that table exists).
    @State private var savedName: String = ""
    @State private var savedUsername: String = ""

    // Draft values while editing.
    @State private var draftName: String = ""
    @State private var draftUsername: String = ""

    @State private var isEditing = false
    @State private var showMenu = false
    @State private var isSaving = false

    private var isNameDirty: Bool     { isEditing && draftName != savedName }
    private var isUsernameDirty: Bool { isEditing && draftUsername != savedUsername }
    private var hasChanges: Bool      { isNameDirty || isUsernameDirty }

    var body: some View {
        ZStack(alignment: .top) {
            Color.Background.default.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profile")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color.Text.primary)
                        .padding(.top, 64)

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

            topBar
                .padding(.horizontal, 16)
                .padding(.top, 6)

            if showMenu {
                menuOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadProfile() }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
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
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.Text.OnColor.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(Color("Colors/Green/500"))
                )
                .overlay {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
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

                LumoriaInputField(
                    label: "Username",
                    placeholder: "username",
                    text: $draftUsername,
                    isRequired: false,
                    state: isUsernameDirty ? .warning : .default,
                    assistiveText: isUsernameDirty
                        ? "You edited this field but it has not been saved yet."
                        : nil
                )
            } else {
                ProfileDisplayField(label: "Name",     value: savedName)
                ProfileDisplayField(label: "Username", value: savedUsername)
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
                    content: .value("0", caption: "collections created"),
                    accentColorFamily: "Orange"
                )
                LumoriaDataCard(
                    content: .value("0", caption: "tickets created this month"),
                    accentColorFamily: "Blue"
                )
                LumoriaDataCard(
                    content: .value("0", caption: "tickets created this year"),
                    accentColorFamily: "Pink"
                )
                LumoriaDataCard(
                    content: .valueWithSuffix(
                        "0",
                        suffix: "months",
                        caption: "Longest gap between tickets"
                    ),
                    accentColorFamily: "Yellow"
                )
                LumoriaDataCard(
                    content: .value("—", caption: "Most used category"),
                    accentColorFamily: "Lime"
                )
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold))
            .tracking(-0.45)
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

            Text(avatarInitial)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(Color.Text.secondary)

            if isEditing {
                Button {
                    // TODO: photo picker
                } label: {
                    Color.black.opacity(0.07)
                        .overlay {
                            Image(systemName: "pencil")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.Text.primary)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(Color.Background.default))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var avatarInitial: String {
        let source = isEditing ? draftName : savedName
        guard let first = source.first else { return "?" }
        return String(first).uppercased()
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
        draftName = savedName
        draftUsername = savedUsername
        withAnimation(.easeInOut(duration: 0.2)) { isEditing = true }
    }

    private func cancelEdit() {
        withAnimation(.easeInOut(duration: 0.2)) { isEditing = false }
    }

    // MARK: - Load / save

    private func loadProfile() async {
        // TODO: replace with a real `profiles` row fetch once the table exists.
        let fallbackName: String
        let fallbackUsername: String
        if let email = supabase.auth.currentUser?.email,
           let local = email.split(separator: "@").first {
            fallbackName = String(local).capitalized
            fallbackUsername = String(local)
        } else {
            fallbackName = "Your profile"
            fallbackUsername = "username"
        }

        savedName = fallbackName
        savedUsername = fallbackUsername
    }

    private func save() async {
        guard hasChanges, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        // TODO: upsert into Supabase `profiles` table once schema lands:
        //   try await supabase
        //     .from("profiles")
        //     .upsert(["id": userId, "name": draftName, "username": draftUsername])
        //     .execute()

        savedName = draftName
        savedUsername = draftUsername

        withAnimation(.easeInOut(duration: 0.2)) { isEditing = false }
    }
}

// MARK: - Display field (read-only)

struct ProfileDisplayField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.23)
                .foregroundStyle(Color.Text.primary)

            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 17, weight: .regular))
                    .tracking(-0.43)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProfileView()
    }
}
