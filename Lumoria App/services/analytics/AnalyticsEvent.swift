//
//  AnalyticsEvent.swift
//  Lumoria App
//
//  Single source of truth for every event the app tracks. Each case maps
//  1:1 to a row in the Notion Events DB. When adding a case here, add the
//  matching Notion row in the same PR.
//

import Foundation

enum AnalyticsEvent {

    // MARK: — Acquisition

    case sessionStarted(isFirstSession: Bool)
    case appOpened(source: AppOpenSourceProp)
    case deepLinkOpened(scheme: String, host: String?, kind: DeepLinkKindProp)
    case inviteLinkOpened(inviteTokenHash: String, wasAuthenticated: Bool)
    case signupStarted
    case signupSubmitted(emailDomain: String, hasName: Bool)
    case signupFailed(errorType: AuthErrorTypeProp)
    case signupVerificationSent(emailDomain: String)
    case loginSubmitted(emailDomain: String)
    case loginFailed(errorType: AuthErrorTypeProp)
    case loginSucceeded(emailDomain: String, wasFromInvite: Bool)
    case passwordResetRequested(emailDomain: String)
    case sessionRestored(hadCache: Bool)
    case logout

    // MARK: — Activation

    case newTicketStarted(entryPoint: TicketEntryPointProp)
    case ticketCategorySelected(category: TicketCategoryProp)
    case ticketTemplateSelected(category: TicketCategoryProp, template: TicketTemplateProp)
    case ticketOrientationSelected(template: TicketTemplateProp, orientation: OrientationProp)
    case ticketFormStarted(template: TicketTemplateProp)
    case ticketFormSubmitted(template: TicketTemplateProp, fieldFillCount: Int,
                             hasOriginLocation: Bool, hasDestinationLocation: Bool)
    case ticketStyleSelected(template: TicketTemplateProp, styleId: String)
    case ticketCreated(category: TicketCategoryProp, template: TicketTemplateProp,
                       orientation: OrientationProp, styleId: String?,
                       fieldFillCount: Int, hasOriginLocation: Bool,
                       hasDestinationLocation: Bool, ticketsLifetime: Int)
    case firstTicketCreated(category: TicketCategoryProp, template: TicketTemplateProp)
    case ticketCreationFailed(stepReached: FunnelStepProp, errorType: String)
    case ticketFunnelAbandoned(stepReached: FunnelStepProp, timeInFunnelMs: Int)
    case memoryCreationStarted
    case memoryCreated(colorFamily: MemoryColorFamilyProp, hasEmoji: Bool, nameLength: Int)
    case firstMemoryCreated(colorFamily: MemoryColorFamilyProp)
    case profileEditStarted
    case profileSaved(nameChanged: Bool, avatarChanged: Bool)
    case avatarUploaded(source: AvatarSourceProp)

    // MARK: — Retention

    case ticketOpened(category: TicketCategoryProp, template: TicketTemplateProp,
                      source: TicketSourceProp)
    case ticketEdited(category: TicketCategoryProp, template: TicketTemplateProp,
                      fieldsChangedCount: Int)
    case ticketDeleted(category: TicketCategoryProp, template: TicketTemplateProp,
                       wasInMemory: Bool)
    case ticketDuplicated(category: TicketCategoryProp)
    case gallerySortApplied(sortType: GallerySortProp)
    case galleryRefreshed(ticketCount: Int)
    case memoryOpened(source: TicketSourceProp, ticketCount: Int, memoryIdHash: String)
    case memoryEdited(nameChanged: Bool, emojiChanged: Bool, colorChanged: Bool,
                      memoryIdHash: String)
    case memoryDeleted(ticketCount: Int, memoryIdHash: String)
    case ticketAddedToMemory(memoryIdHash: String, newTicketCount: Int)
    case ticketRemovedFromMemory(memoryIdHash: String)
    case exportSheetOpened(category: TicketCategoryProp, template: TicketTemplateProp)
    case exportDestinationSelected(destination: ExportDestinationProp)
    case cameraRollExportConfigured(includeBackground: Bool, includeWatermark: Bool,
                                     resolution: ExportResolutionProp,
                                     crop: ExportCropProp, format: ExportFormatProp)
    case ticketExported(destination: ExportDestinationProp,
                         resolution: ExportResolutionProp?,
                         crop: ExportCropProp?, format: ExportFormatProp?,
                         includeBackground: Bool?, includeWatermark: Bool?,
                         durationMs: Int)
    case ticketExportFailed(destination: ExportDestinationProp, errorType: String)
    case ticketSharedViaIM(platform: IMPlatformProp)
    case settingsOpened
    case appearanceModeChanged(mode: AppearanceModeProp)
    case appIconChanged(iconName: String)
    case highContrastToggled(enabled: Bool)
    case notificationPrefsChanged(notificationType: String, enabled: Bool)

    // MARK: — Referral

    case invitePageViewed(state: InvitePageStateProp)
    case inviteGenerated(isFirstTime: Bool)
    case inviteShared(channel: InviteChannelProp, inviteTokenHash: String)
    case inviteLinkReceived(inviteTokenHash: String, wasAuthenticated: Bool)
    case inviteClaimed(inviteTokenHash: String, role: InviteRoleProp, timeToClaimMs: Int?)
    case inviteAutoClaimed(inviteTokenHash: String)
    case notificationCenterOpened(unreadCount: Int)
    case pushOpened(notificationKind: NotificationKindProp, deepLinkTarget: String?)

    // MARK: — Revenue (stubs; no call sites yet)

    case planViewed
    case paywallViewed(source: String)
    case planSelected(planId: String, priceCents: Int, currency: String)
    case checkoutStarted(planId: String)
    case subscriptionStarted(planId: String, priceCents: Int, currency: String, trialDays: Int)
    case subscriptionCancelled(planId: String, reason: String)

    // MARK: — System

    case sdkInitialized
    case pushPermissionRequested
    case pushPermissionResponded(granted: Bool)
    case pushReceived(notificationKind: NotificationKindProp, inForeground: Bool)
    case notificationTapped(notificationKind: NotificationKindProp,
                             source: PushNotificationSourceProp)
    case notificationMarkedRead(notificationKind: NotificationKindProp)
    case legalLinkOpened(linkType: LegalLinkTypeProp)
    case profileViewed

    // MARK: — Error

    case appError(domain: AppErrorDomainProp, code: String, viewContext: String?)
    case networkError(endpointCategory: String, statusCode: Int?, errorType: String)
    case dataSyncFailed(resourceType: String, reason: String)
}

// MARK: - Name + Properties

extension AnalyticsEvent {

    /// Title-case "Object Action" event name sent to Amplitude. Must match
    /// the Notion Events DB `Name` column 1:1.
    var name: String {
        switch self {
        // Acquisition
        case .sessionStarted: return "Session Started"
        case .appOpened: return "App Opened"
        case .deepLinkOpened: return "Deep Link Opened"
        case .inviteLinkOpened: return "Invite Link Opened"
        case .signupStarted: return "Signup Started"
        case .signupSubmitted: return "Signup Submitted"
        case .signupFailed: return "Signup Failed"
        case .signupVerificationSent: return "Signup Verification Sent"
        case .loginSubmitted: return "Login Submitted"
        case .loginFailed: return "Login Failed"
        case .loginSucceeded: return "Login Succeeded"
        case .passwordResetRequested: return "Password Reset Requested"
        case .sessionRestored: return "Session Restored"
        case .logout: return "Logout"

        // Activation
        case .newTicketStarted: return "New Ticket Started"
        case .ticketCategorySelected: return "Ticket Category Selected"
        case .ticketTemplateSelected: return "Ticket Template Selected"
        case .ticketOrientationSelected: return "Ticket Orientation Selected"
        case .ticketFormStarted: return "Ticket Form Started"
        case .ticketFormSubmitted: return "Ticket Form Submitted"
        case .ticketStyleSelected: return "Ticket Style Selected"
        case .ticketCreated: return "Ticket Created"
        case .firstTicketCreated: return "First Ticket Created"
        case .ticketCreationFailed: return "Ticket Creation Failed"
        case .ticketFunnelAbandoned: return "Ticket Funnel Abandoned"
        case .memoryCreationStarted: return "Memory Creation Started"
        case .memoryCreated: return "Memory Created"
        case .firstMemoryCreated: return "First Memory Created"
        case .profileEditStarted: return "Profile Edit Started"
        case .profileSaved: return "Profile Saved"
        case .avatarUploaded: return "Avatar Uploaded"

        // Retention
        case .ticketOpened: return "Ticket Opened"
        case .ticketEdited: return "Ticket Edited"
        case .ticketDeleted: return "Ticket Deleted"
        case .ticketDuplicated: return "Ticket Duplicated"
        case .gallerySortApplied: return "Gallery Sort Applied"
        case .galleryRefreshed: return "Gallery Refreshed"
        case .memoryOpened: return "Memory Opened"
        case .memoryEdited: return "Memory Edited"
        case .memoryDeleted: return "Memory Deleted"
        case .ticketAddedToMemory: return "Ticket Added To Memory"
        case .ticketRemovedFromMemory: return "Ticket Removed From Memory"
        case .exportSheetOpened: return "Export Sheet Opened"
        case .exportDestinationSelected: return "Export Destination Selected"
        case .cameraRollExportConfigured: return "Camera Roll Export Configured"
        case .ticketExported: return "Ticket Exported"
        case .ticketExportFailed: return "Ticket Export Failed"
        case .ticketSharedViaIM: return "Ticket Shared Via IM"
        case .settingsOpened: return "Settings Opened"
        case .appearanceModeChanged: return "Appearance Mode Changed"
        case .appIconChanged: return "App Icon Changed"
        case .highContrastToggled: return "High Contrast Toggled"
        case .notificationPrefsChanged: return "Notification Prefs Changed"

        // Referral
        case .invitePageViewed: return "Invite Page Viewed"
        case .inviteGenerated: return "Invite Generated"
        case .inviteShared: return "Invite Shared"
        case .inviteLinkReceived: return "Invite Link Received"
        case .inviteClaimed: return "Invite Claimed"
        case .inviteAutoClaimed: return "Invite Auto Claimed"
        case .notificationCenterOpened: return "Notification Center Opened"
        case .pushOpened: return "Push Opened"

        // Revenue
        case .planViewed: return "Plan Viewed"
        case .paywallViewed: return "Paywall Viewed"
        case .planSelected: return "Plan Selected"
        case .checkoutStarted: return "Checkout Started"
        case .subscriptionStarted: return "Subscription Started"
        case .subscriptionCancelled: return "Subscription Cancelled"

        // System
        case .sdkInitialized: return "SDK Initialized"
        case .pushPermissionRequested: return "Push Permission Requested"
        case .pushPermissionResponded: return "Push Permission Responded"
        case .pushReceived: return "Push Received"
        case .notificationTapped: return "Notification Tapped"
        case .notificationMarkedRead: return "Notification Marked Read"
        case .legalLinkOpened: return "Legal Link Opened"
        case .profileViewed: return "Profile Viewed"

        // Error
        case .appError: return "App Error"
        case .networkError: return "Network Error"
        case .dataSyncFailed: return "Data Sync Failed"
        }
    }

    /// Property dictionary sent alongside the event. All keys are snake_case.
    /// Never include PII — see design spec §5.
    var properties: [String: Any] {
        switch self {
        // Acquisition
        case .sessionStarted(let isFirst):
            return ["is_first_session": isFirst]
        case .appOpened(let source):
            return ["source": source.rawValue]
        case .deepLinkOpened(let scheme, let host, let kind):
            var p: [String: Any] = ["scheme": scheme, "kind": kind.rawValue]
            if let host { p["host"] = host }
            return p
        case .inviteLinkOpened(let hash, let wasAuth):
            return ["invite_token_hash": hash, "was_authenticated": wasAuth]
        case .signupStarted:
            return [:]
        case .signupSubmitted(let domain, let hasName):
            return ["email_domain": domain, "has_name": hasName]
        case .signupFailed(let err):
            return ["auth_error_type": err.rawValue]
        case .signupVerificationSent(let domain):
            return ["email_domain": domain]
        case .loginSubmitted(let domain):
            return ["email_domain": domain]
        case .loginFailed(let err):
            return ["auth_error_type": err.rawValue]
        case .loginSucceeded(let domain, let fromInvite):
            return ["email_domain": domain, "was_from_invite": fromInvite]
        case .passwordResetRequested(let domain):
            return ["email_domain": domain]
        case .sessionRestored(let hadCache):
            return ["had_cache": hadCache]
        case .logout:
            return [:]

        // Activation
        case .newTicketStarted(let entry):
            return ["entry_point": entry.rawValue]
        case .ticketCategorySelected(let cat):
            return ["ticket_category": cat.rawValue]
        case .ticketTemplateSelected(let cat, let tmpl):
            return ["ticket_category": cat.rawValue, "ticket_template": tmpl.rawValue]
        case .ticketOrientationSelected(let tmpl, let orient):
            return ["ticket_template": tmpl.rawValue, "ticket_orientation": orient.rawValue]
        case .ticketFormStarted(let tmpl):
            return ["ticket_template": tmpl.rawValue]
        case .ticketFormSubmitted(let tmpl, let count, let hasOrigin, let hasDest):
            return [
                "ticket_template": tmpl.rawValue,
                "field_fill_count": count,
                "has_origin_location": hasOrigin,
                "has_destination_location": hasDest,
            ]
        case .ticketStyleSelected(let tmpl, let styleId):
            return ["ticket_template": tmpl.rawValue, "style_id": styleId]
        case .ticketCreated(let cat, let tmpl, let orient, let styleId, let count,
                            let hasOrigin, let hasDest, let lifetime):
            var p: [String: Any] = [
                "ticket_category": cat.rawValue,
                "ticket_template": tmpl.rawValue,
                "ticket_orientation": orient.rawValue,
                "field_fill_count": count,
                "has_origin_location": hasOrigin,
                "has_destination_location": hasDest,
                "tickets_lifetime": lifetime,
            ]
            if let styleId { p["style_id"] = styleId }
            return p
        case .firstTicketCreated(let cat, let tmpl):
            return ["ticket_category": cat.rawValue, "ticket_template": tmpl.rawValue]
        case .ticketCreationFailed(let step, let err):
            return ["funnel_step_reached": step.rawValue, "error_type": err]
        case .ticketFunnelAbandoned(let step, let ms):
            return ["funnel_step_reached": step.rawValue, "time_in_funnel_ms": ms]
        case .memoryCreationStarted:
            return [:]
        case .memoryCreated(let color, let hasEmoji, let nameLen):
            return ["memory_color_family": color.rawValue,
                    "has_emoji": hasEmoji,
                    "name_length": nameLen]
        case .firstMemoryCreated(let color):
            return ["memory_color_family": color.rawValue]
        case .profileEditStarted:
            return [:]
        case .profileSaved(let nameChanged, let avatarChanged):
            return ["name_changed": nameChanged, "avatar_changed": avatarChanged]
        case .avatarUploaded(let source):
            return ["source": source.rawValue]

        // Retention
        case .ticketOpened(let cat, let tmpl, let source):
            return ["ticket_category": cat.rawValue,
                    "ticket_template": tmpl.rawValue,
                    "source": source.rawValue]
        case .ticketEdited(let cat, let tmpl, let count):
            return ["ticket_category": cat.rawValue,
                    "ticket_template": tmpl.rawValue,
                    "fields_changed_count": count]
        case .ticketDeleted(let cat, let tmpl, let wasInMem):
            return ["ticket_category": cat.rawValue,
                    "ticket_template": tmpl.rawValue,
                    "was_in_memory": wasInMem]
        case .ticketDuplicated(let cat):
            return ["ticket_category": cat.rawValue]
        case .gallerySortApplied(let sort):
            return ["sort_type": sort.rawValue]
        case .galleryRefreshed(let count):
            return ["ticket_count": count]
        case .memoryOpened(let source, let count, let hash):
            return ["source": source.rawValue,
                    "ticket_count": count,
                    "memory_id_hash": hash]
        case .memoryEdited(let nameChanged, let emojiChanged, let colorChanged, let hash):
            return ["name_changed": nameChanged,
                    "emoji_changed": emojiChanged,
                    "color_changed": colorChanged,
                    "memory_id_hash": hash]
        case .memoryDeleted(let count, let hash):
            return ["ticket_count": count, "memory_id_hash": hash]
        case .ticketAddedToMemory(let hash, let newCount):
            return ["memory_id_hash": hash, "new_ticket_count": newCount]
        case .ticketRemovedFromMemory(let hash):
            return ["memory_id_hash": hash]
        case .exportSheetOpened(let cat, let tmpl):
            return ["ticket_category": cat.rawValue, "ticket_template": tmpl.rawValue]
        case .exportDestinationSelected(let dest):
            return ["export_destination": dest.rawValue]
        case .cameraRollExportConfigured(let bg, let wm, let res, let crop, let fmt):
            return ["include_background": bg,
                    "include_watermark": wm,
                    "export_resolution": res.rawValue,
                    "export_crop": crop.rawValue,
                    "export_format": fmt.rawValue]
        case .ticketExported(let dest, let res, let crop, let fmt,
                             let bg, let wm, let ms):
            var p: [String: Any] = [
                "export_destination": dest.rawValue,
                "duration_ms": ms,
            ]
            if let res { p["export_resolution"] = res.rawValue }
            if let crop { p["export_crop"] = crop.rawValue }
            if let fmt { p["export_format"] = fmt.rawValue }
            if let bg { p["include_background"] = bg }
            if let wm { p["include_watermark"] = wm }
            return p
        case .ticketExportFailed(let dest, let err):
            return ["export_destination": dest.rawValue, "error_type": err]
        case .ticketSharedViaIM(let platform):
            return ["platform": platform.rawValue]
        case .settingsOpened:
            return [:]
        case .appearanceModeChanged(let mode):
            return ["appearance_mode": mode.rawValue]
        case .appIconChanged(let icon):
            return ["icon_name": icon]
        case .highContrastToggled(let on):
            return ["enabled": on]
        case .notificationPrefsChanged(let type, let on):
            return ["notification_type": type, "enabled": on]

        // Referral
        case .invitePageViewed(let state):
            return ["state": state.rawValue]
        case .inviteGenerated(let first):
            return ["is_first_time": first]
        case .inviteShared(let ch, let hash):
            return ["channel": ch.rawValue, "invite_token_hash": hash]
        case .inviteLinkReceived(let hash, let wasAuth):
            return ["invite_token_hash": hash, "was_authenticated": wasAuth]
        case .inviteClaimed(let hash, let role, let ms):
            var p: [String: Any] = ["invite_token_hash": hash, "role": role.rawValue]
            if let ms { p["time_to_claim_ms"] = ms }
            return p
        case .inviteAutoClaimed(let hash):
            return ["invite_token_hash": hash]
        case .notificationCenterOpened(let unread):
            return ["unread_count": unread]
        case .pushOpened(let kind, let target):
            var p: [String: Any] = ["notification_kind": kind.rawValue]
            if let target { p["deep_link_target"] = target }
            return p

        // Revenue
        case .planViewed:
            return [:]
        case .paywallViewed(let src):
            return ["source": src]
        case .planSelected(let id, let cents, let cur):
            return ["plan_id": id, "price_cents": cents, "currency": cur]
        case .checkoutStarted(let id):
            return ["plan_id": id]
        case .subscriptionStarted(let id, let cents, let cur, let trial):
            return ["plan_id": id,
                    "price_cents": cents,
                    "currency": cur,
                    "trial_days": trial]
        case .subscriptionCancelled(let id, let reason):
            return ["plan_id": id, "reason": reason]

        // System
        case .sdkInitialized:
            return [:]
        case .pushPermissionRequested:
            return [:]
        case .pushPermissionResponded(let granted):
            return ["granted": granted]
        case .pushReceived(let kind, let fg):
            return ["notification_kind": kind.rawValue, "in_foreground": fg]
        case .notificationTapped(let kind, let source):
            return ["notification_kind": kind.rawValue, "source": source.rawValue]
        case .notificationMarkedRead(let kind):
            return ["notification_kind": kind.rawValue]
        case .legalLinkOpened(let type):
            return ["link_type": type.rawValue]
        case .profileViewed:
            return [:]

        // Error
        case .appError(let domain, let code, let ctx):
            var p: [String: Any] = ["domain": domain.rawValue, "code": code]
            if let ctx { p["view_context"] = ctx }
            return p
        case .networkError(let endpoint, let status, let err):
            var p: [String: Any] = ["endpoint_category": endpoint, "error_type": err]
            if let status { p["status_code"] = status }
            return p
        case .dataSyncFailed(let resource, let reason):
            return ["resource_type": resource, "reason": reason]
        }
    }
}
