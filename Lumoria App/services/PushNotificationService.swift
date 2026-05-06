//
//  PushNotificationService.swift
//  Lumoria App
//
//  APNs glue. Requests authorization, uploads the device token to
//  Supabase, and turns a tapped notification into a deep-link the rest
//  of the app can route on.
//
//  Setup checklist (once, in Xcode):
//    1. Signing & Capabilities → + Capability → Push Notifications.
//       This creates `Lumoria App.entitlements` with `aps-environment`.
//    2. Background Modes → tick "Remote notifications" if you want
//       silent pushes later (not required for alerts).
//

import Combine
import Foundation
import Supabase
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class PushNotificationService: NSObject, ObservableObject {

    /// Singleton — the AppDelegate needs a stable reference to forward
    /// device-token callbacks into.
    static let shared = PushNotificationService()

    /// Notification the user tapped from the lock screen / banner.
    /// MemoriesView watches this and opens the right destination.
    @Published var pendingDeepLink: DeepLink? = nil

    /// Hex device token; kept in memory so we can re-upload once the
    /// user signs in if the token arrived before auth.
    private var cachedToken: String? = nil

    /// Whether the current user session has already received a token
    /// upload for this launch — avoids duplicate inserts on token
    /// refresh.
    private var hasUploadedForCurrentSession = false

    // MARK: - Authorization

    /// Ask iOS for permission. Safe to call repeatedly — the system
    /// only prompts the user once.
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        Analytics.track(.pushPermissionRequested)
        var granted = false
        do {
            granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
        } catch {
            print("[Push] authorization request failed:", error)
        }
        Analytics.track(.pushPermissionResponded(granted: granted))
        Analytics.updateUserProperties(["push_enabled": granted])

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
        else { return }

        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Device token plumbing (called from AppDelegate)

    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        cachedToken = hex
        Task { await uploadTokenIfPossible() }
    }

    func didFailToRegister(error: Error) {
        print("[Push] didFailToRegister:", error)
    }

    /// Call this after sign-in so a token captured before auth gets
    /// uploaded against the freshly-authenticated user.
    func authDidChange() {
        hasUploadedForCurrentSession = false
        Task { await uploadTokenIfPossible() }
    }

    private func uploadTokenIfPossible() async {
        guard let token = cachedToken,
              supabase.auth.currentUser != nil,
              !hasUploadedForCurrentSession
        else { return }

        #if DEBUG
        let env = "sandbox"
        #else
        let env = "production"
        #endif

        // Registration goes through the `register_device_token` RPC
        // (SECURITY DEFINER) instead of a direct upsert. A plain upsert
        // hits `device_tokens.token` — the primary key — and if the row
        // already belongs to a previous user (sign-out then sign-in on
        // the same device) the UPDATE policy's USING clause rejects the
        // call with 42501. The RPC rewrites `user_id = auth.uid()`
        // server-side so the blessed "this is my device now" flow
        // works without loosening RLS.
        struct Args: Encodable {
            let p_token: String
            let p_environment: String
            let p_platform: String
        }

        do {
            try await supabase
                .rpc(
                    "register_device_token",
                    params: Args(
                        p_token: token,
                        p_environment: env,
                        p_platform: "ios"
                    )
                )
                .execute()
            hasUploadedForCurrentSession = true
        } catch {
            print("[Push] token upload failed:", error)
        }
    }

    /// Call when the user signs out — removes the token on this device
    /// so the ex-user stops receiving pushes here.
    func signedOut() async {
        guard let token = cachedToken else { return }
        do {
            try await supabase
                .from("device_tokens")
                .delete()
                .eq("token", value: token)
                .execute()
        } catch {
            print("[Push] token delete failed:", error)
        }
        hasUploadedForCurrentSession = false
    }

    // MARK: - Badge

    func setBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { err in
            if let err { print("[Push] setBadgeCount failed:", err) }
        }
    }

    // MARK: - Deep link

    struct DeepLink: Equatable {
        let notificationId: UUID?
        let kind: LumoriaNotification.Kind
        let memoryId: UUID?
        let templateKind: TicketTemplateKind?
    }

    fileprivate func ingestTappedPayload(_ userInfo: [AnyHashable: Any]) {
        guard
            let kindRaw = userInfo["kind"] as? String,
            let kind = LumoriaNotification.Kind(rawValue: kindRaw)
        else { return }

        let notificationId = (userInfo["notification_id"] as? String)
            .flatMap(UUID.init(uuidString:))
        let memoryId = (userInfo["memory_id"] as? String)
            .flatMap(UUID.init(uuidString:))
        let templateKind = (userInfo["template_kind"] as? String)
            .flatMap(TicketTemplateKind.init(rawValue:))

        pendingDeepLink = DeepLink(
            notificationId: notificationId,
            kind: kind,
            memoryId: memoryId,
            templateKind: templateKind
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {

    /// Foreground presentation — show the banner anyway, so users who
    /// are already in the app aren't confused when nothing visible
    /// happens.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let kindRaw = userInfo["kind"] as? String
        let kindProp: NotificationKindProp = {
            switch kindRaw {
            case "throwback":  return .throwback
            case "onboarding": return .onboarding
            case "news":       return .news
            case "link":       return .link
            default:           return .news
            }
        }()
        let isLink = (kindRaw == "link")
        Task { @MainActor in
            Analytics.track(.pushReceived(notificationKind: kindProp, inForeground: true))
            // Live trigger for the inviter's reward sheet — fires
            // before the banner so by the time the user dismisses
            // the banner, evaluate() has settled and the sheet is
            // ready to present.
            if isLink {
                NotificationCenter.default.post(
                    name: .lumoriaInviteRewardSignal,
                    object: nil
                )
            }
        }
        completionHandler([.banner, .sound, .badge])
    }

    /// Tap from the lock screen / banner. Hand the payload off to the
    /// published deep-link; MemoriesView routes.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let kindRaw = userInfo["kind"] as? String
        let kindProp: NotificationKindProp = {
            switch kindRaw {
            case "throwback":  return .throwback
            case "onboarding": return .onboarding
            case "news":       return .news
            case "link":       return .link
            default:           return .news
            }
        }()
        let target = userInfo["deep_link"] as? String
            ?? userInfo["memory_id"] as? String
        let isLink = (kindRaw == "link")
        Task { @MainActor in
            Analytics.track(.pushOpened(notificationKind: kindProp, deepLinkTarget: target))
            PushNotificationService.shared.ingestTappedPayload(userInfo)
            // Same live trigger on tap — covers the cold-launch /
            // background-tap path that doesn't go through willPresent.
            if isLink {
                NotificationCenter.default.post(
                    name: .lumoriaInviteRewardSignal,
                    object: nil
                )
            }
            completionHandler()
        }
    }
}

// MARK: - AppDelegate shim

/// Hooked into SwiftUI via `@UIApplicationDelegateAdaptor`. The only job
/// here is forwarding the device-token callbacks into the singleton —
/// SwiftUI doesn't expose them through the App lifecycle yet.
final class LumoriaAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared

        // If the app was cold-launched via a tapped push, the payload
        // arrives here. Forward it.
        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Task { @MainActor in
                PushNotificationService.shared.ingestTappedPayload(remote)
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationService.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationService.shared.didFailToRegister(error: error)
        }
    }
}
