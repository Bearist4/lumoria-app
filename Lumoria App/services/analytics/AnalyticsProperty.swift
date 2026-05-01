//
//  AnalyticsProperty.swift
//  Lumoria App
//
//  Typed enums for every bounded property value. String rawValues are the
//  exact wire format sent to Amplitude — never rename without updating the
//  Notion tracking plan first.
//

import Foundation

enum TicketCategoryProp: String, CaseIterable {
    case plane, train, concert, event, food, movie, museum, sport, garden, public_transit
}

enum TicketTemplateProp: String, CaseIterable {
    case afterglow, studio, terminal, heritage, prism
    case express, orient, night, post, glow
    case concert
    case eurovision
    case underground, sign, infoscreen, grid
}

enum OrientationProp: String, CaseIterable {
    case horizontal, vertical
}

enum ExportDestinationProp: String, CaseIterable {
    case camera_roll, whatsapp, messenger, discord
    case instagram, twitter, threads, snapchat, facebook
    case social_square, social_story, social_facebook, social_instagram, social_x
}

enum ExportFormatProp: String, CaseIterable {
    case png, jpg
}

enum ExportCropProp: String, CaseIterable {
    case full, square
}

enum ExportResolutionProp: String, CaseIterable {
    case x1 = "1x"
    case x2 = "2x"
    case x3 = "3x"
}

enum IMPlatformProp: String, CaseIterable {
    case whatsapp, messenger, discord, other
}

enum NotificationKindProp: String, CaseIterable {
    case throwback, onboarding, news, link
}

enum MemoryColorFamilyProp: String, CaseIterable {
    case orange, blue, pink, red, yellow, green, purple, teal, gray
}

enum AppearanceModeProp: String, CaseIterable {
    case system, light, dark
}

enum AuthErrorTypeProp: String, CaseIterable {
    case invalid_credentials
    case email_in_use
    case weak_password
    case network
    case cancelled
    case unknown
}

enum AuthFlowEmailOutcomeProp: String, CaseIterable {
    case exists, does_not_exist, rate_limited, error
}

enum AuthFlowStepProp: String, CaseIterable {
    case chooser, email, login, signup
}

enum FunnelStepProp: String, CaseIterable {
    case category, template, orientation, form, style, success
}

enum TicketSourceProp: String, CaseIterable {
    case gallery, memory, notification, deep_link, wallet, share
}

enum TicketEntryPointProp: String, CaseIterable {
    case gallery, memory, notification, deep_link, onboarding
}

enum AppOpenSourceProp: String, CaseIterable {
    case cold, warm, deep_link
}

enum DeepLinkKindProp: String, CaseIterable {
    case invite, push, other
}

enum InviteChannelProp: String, CaseIterable {
    case system_share, copy_link
}

enum InviteRoleProp: String, CaseIterable {
    case inviter, invitee
}

enum InvitePageStateProp: String, CaseIterable {
    case not_sent, sent, redeemed
}

enum LegalLinkTypeProp: String, CaseIterable {
    case tos, privacy, support
}

enum GallerySortProp: String, CaseIterable {
    case date, category, none
}

enum AvatarSourceProp: String, CaseIterable {
    case camera, library
}

enum PushNotificationSourceProp: String, CaseIterable {
    case center, system_banner
}

enum AppErrorDomainProp: String, CaseIterable {
    case auth, ticket, memory, invite, export, notification, network, supabase, unknown
}

enum MapPinTypeProp: String, CaseIterable {
    case origin, destination
}

enum OnboardingStepProp: String, CaseIterable {
    case welcome
    case createMemory      = "create_memory"
    case memoryCreated     = "memory_created"
    case enterMemory       = "enter_memory"
    case pickCategory      = "pick_category"
    case pickTemplate      = "pick_template"
    case fillInfo          = "fill_info"
    case pickStyle         = "pick_style"
    case allDone           = "all_done"
    case exportOrAddMemory = "export_or_add_memory"
    case endCover          = "end_cover"
    case done
}

/// Environment tag applied to every event as a universal property.
enum AnalyticsEnvironment: String {
    case dev, prod
}
