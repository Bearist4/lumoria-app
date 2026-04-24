//
//  OnboardingStep.swift
//  Lumoria App
//
//  Linear state machine for the first-run tutorial. Stored as a text
//  column in public.profiles (see 20260424000000_profiles.sql).
//

import Foundation

enum OnboardingStep: String, Codable, CaseIterable, Sendable {
    case welcome
    case createMemory
    case memoryCreated
    case enterMemory
    case pickCategory
    case pickTemplate
    case fillInfo
    case pickStyle
    case allDone
    case exportOrAddMemory
    case endCover
    case done
}
