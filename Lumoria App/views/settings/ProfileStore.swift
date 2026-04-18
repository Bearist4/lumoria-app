//
//  ProfileStore.swift
//  Lumoria App
//
//  Shared source of truth for the signed-in user's display name and
//  avatar. Both `ProfileView` and `SettingsView` observe this store so
//  an edit made in one surfaces instantly in the other.
//
//  Avatar bytes live in the private `avatars` Storage bucket as AES-GCM
//  ciphertext; this store handles the download → decrypt → `UIImage`
//  pipeline so views just render `avatarImage`.
//

import Combine
import Foundation
import Supabase
import SwiftUI
import UIKit

@MainActor
final class ProfileStore: ObservableObject {

    @Published private(set) var name: String = ""
    @Published private(set) var avatarImage: UIImage? = nil
    /// Random-UUID path of the encrypted avatar in Storage. Surfaced so
    /// `ProfileView` can delete the previous file when a new one uploads.
    @Published private(set) var avatarPath: String? = nil

    // MARK: - Load

    func load() async {
        let user = supabase.auth.currentUser
        let metadata = user?.userMetadata ?? [:]

        // Name
        var resolvedName = ""
        if case .string(let value) = metadata["full_name"] {
            resolvedName = value
        }
        if resolvedName.isEmpty,
           let email = user?.email,
           let local = email.split(separator: "@").first {
            resolvedName = String(local).capitalized
        }
        if resolvedName.isEmpty {
            resolvedName = "Your profile"
        }
        name = resolvedName

        // Avatar
        var resolvedPath: String? = nil
        if case .string(let value) = metadata["avatar_path"], !value.isEmpty {
            resolvedPath = value
        }
        avatarPath = resolvedPath

        if let path = resolvedPath {
            await downloadAvatar(path: path)
        } else {
            avatarImage = nil
        }
    }

    /// Downloads the ciphertext blob at `path`, decrypts with the user's
    /// device key, and publishes the resulting image. Silent on failure —
    /// the UI falls back to the initial-letter avatar.
    private func downloadAvatar(path: String) async {
        do {
            let encrypted = try await supabase.storage
                .from("avatars")
                .download(path: path)
            let plain = try EncryptionService.decrypt(encrypted)
            avatarImage = UIImage(data: plain)
        } catch {
            print("[ProfileStore] avatar load failed:", error)
            avatarImage = nil
        }
    }
}
