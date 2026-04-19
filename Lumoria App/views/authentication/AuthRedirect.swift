//
//  AuthRedirect.swift
//  Lumoria App
//
//  Single source of truth for the URL Supabase embeds in confirmation /
//  password-reset emails. Must be allowlisted in Supabase Dashboard →
//  Auth → URL Configuration, and resolved by the AASA file at
//  https://getlumoria.app/.well-known/apple-app-site-association.
//

import Foundation

enum AuthRedirect {
    static let emailConfirmed = URL(string: "https://getlumoria.app/auth/confirmed")!
}
