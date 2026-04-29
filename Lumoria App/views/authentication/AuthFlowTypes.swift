//
//  AuthFlowTypes.swift
//  Lumoria App
//
//  Step enum + result/error types for the email-first landing auth flow.
//  Spec: docs/superpowers/specs/2026-04-28-auth-email-morph-flow-design.md
//

import Foundation

enum AuthFlowStep: Equatable {
    case chooser
    case email
    case login(email: String)
    case signup(email: String)
}

enum CheckEmailResult: Equatable {
    case exists
    case doesNotExist
    case rateLimited
}

enum AuthFlowError: Error, LocalizedError, Equatable {
    case invalidCredentials
    case emailNotConfirmed(email: String)
    case rateLimited
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return String(localized: "Email or password is incorrect")
        case .emailNotConfirmed:
            return String(localized: "Please confirm your email before logging in")
        case .rateLimited:
            return String(localized: "Too many tries — try again in a moment")
        case .transport(let detail):
            return detail
        }
    }
}
