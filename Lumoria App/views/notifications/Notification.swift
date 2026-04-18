//
//  Notification.swift
//  Lumoria App
//
//  In-app notification model. Four flavors (throwback / onboarding / news /
//  link) drive card colour, eyebrow label, and the action that fires when
//  the user taps the row in the notification center.
//

import Foundation
import SwiftUI

struct LumoriaNotification: Identifiable, Hashable {
    let id: UUID
    let kind: Kind
    let title: String
    let message: String
    let createdAt: Date
    var isRead: Bool

    enum Kind: String, Hashable {
        case throwback
        case onboarding
        case news
        case link

        var eyebrow: String {
            switch self {
            case .throwback:  return "THROWBACK"
            case .onboarding: return "GET STARTED"
            case .news:       return "BRAND NEW"
            case .link:       return "INVITE A FRIEND"
            }
        }

        /// Card background — from the Figma palette (yellow/50, purple/50,
        /// pink/50, blue/50).
        var backgroundColor: Color {
            switch self {
            case .throwback:  return Color(hex: "FFF6D1")
            case .onboarding: return Color(hex: "F8F1FF")
            case .news:       return Color(hex: "FFF0F7")
            case .link:       return Color(hex: "EBF7FF")
            }
        }
    }

    /// Context payload — used to route the tap to the right destination.
    var memoryId: UUID? = nil
    var templateKind: TicketTemplateKind? = nil

    init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        message: String,
        createdAt: Date = Date(),
        isRead: Bool = false,
        memoryId: UUID? = nil,
        templateKind: TicketTemplateKind? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.isRead = isRead
        self.memoryId = memoryId
        self.templateKind = templateKind
    }
}
