# Amplitude Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a type-safe, PII-safe Amplitude analytics integration covering ~78 events mapped to AARRR, plus a fully-populated Notion tracking plan.

**Architecture:** A thin `AnalyticsService` protocol wraps `amplitude-swift`. All events modeled as a single `AnalyticsEvent` enum with associated values, so misnamed properties fail at compile time. The API key is loaded from a gitignored `Amplitude.xcconfig` via `Info.plist` substitution. All UUIDs (`user_id` excepted) are SHA-256 hashed before leaving the device. Dev vs prod runs are tagged via a universal `environment` property on every event.

**Tech Stack:** SwiftUI, Swift 5.9+, Swift Testing (`@Suite`, `@Test`, `#expect`), `amplitude-swift` via SPM, Supabase auth, xcconfig + Info.plist for secrets.

**Reference spec:** `docs/superpowers/specs/2026-04-18-amplitude-tracking-design.md`

---

## File Structure

**New source files:**
- `Lumoria App/services/analytics/AnalyticsIdentity.swift` — hash + email-domain helpers
- `Lumoria App/services/analytics/AnalyticsProperty.swift` — typed enums for property values
- `Lumoria App/services/analytics/AnalyticsEvent.swift` — `AnalyticsEvent` enum + `name` + `properties`
- `Lumoria App/services/analytics/AnalyticsService.swift` — `AnalyticsService` protocol + `Analytics` singleton
- `Lumoria App/services/analytics/NoopAnalyticsService.swift` — previews/tests impl
- `Lumoria App/services/analytics/AmplitudeAnalyticsService.swift` — production impl

**New infra files:**
- `Amplitude.xcconfig` (gitignored) — holds real key
- `Amplitude.sample.xcconfig` (committed) — template
- `.gitignore` entry for `Amplitude.xcconfig`

**New test files:**
- `Lumoria AppTests/AnalyticsIdentityTests.swift`
- `Lumoria AppTests/AnalyticsEventTests.swift`
- `Lumoria AppTests/AnalyticsPropertyTests.swift`

**Modified files (instrumentation):**
- `Lumoria App/Lumoria_AppApp.swift` — SDK init, session/app open, deep link events
- `Lumoria App/views/authentication/AuthManager.swift` — login/logout/session-restored
- `Lumoria App/views/authentication/SignUpView.swift` — signup events
- `Lumoria App/views/authentication/LogInView.swift` — login submit/fail
- `Lumoria App/views/authentication/ForgotPasswordView.swift` — password reset
- `Lumoria App/views/tickets/new/NewTicketFunnel.swift`
- `Lumoria App/views/tickets/new/NewTicketFunnelView.swift`
- `Lumoria App/views/tickets/new/CategoryStep.swift`
- `Lumoria App/views/tickets/new/TemplateStep.swift`
- `Lumoria App/views/tickets/new/OrientationStep.swift`
- `Lumoria App/views/tickets/new/FormStep.swift`, `NightFormStep.swift`, `TrainFormStep.swift`, `OrientFormStep.swift`
- `Lumoria App/views/tickets/new/StyleStep.swift`
- `Lumoria App/views/tickets/new/SuccessStep.swift`
- `Lumoria App/views/tickets/new/ExportSheet.swift`
- `Lumoria App/views/tickets/AllTicketsView.swift`
- `Lumoria App/views/tickets/TicketDetailView.swift`
- `Lumoria App/views/collections/CollectionsStore.swift` (or wherever MemoriesStore lives; verify in Task)
- `Lumoria App/views/settings/SettingsView.swift`
- `Lumoria App/views/settings/ProfileView.swift`
- `Lumoria App/views/settings/AppearanceView.swift`
- `Lumoria App/views/settings/InviteView.swift`, `InvitesStore.swift`
- `Lumoria App/views/notifications/NotificationCenterView.swift`
- `Lumoria App/services/PushNotificationService.swift`
- `Info.plist` — add `AMPLITUDE_API_KEY` entry
- `Lumoria App.xcodeproj/project.pbxproj` — add `amplitude-swift` SPM dep + xcconfig wiring (via Xcode UI)
- `.gitignore` — add `Amplitude.xcconfig`

**Notion (Phase 5):**
- Extend existing `collection://34610dea-1b05-8071-b23e-000b76646219` (Events DB)
- Create sibling DBs: Event Properties, User Properties

---

# Phase 1 — Infra: SDK + API key

## Task 1: Add Amplitude SDK via SPM

**Files:**
- Modify: `Lumoria App.xcodeproj` (Xcode UI)

- [ ] **Step 1: Open Xcode**

```bash
open "Lumoria App.xcodeproj"
```

- [ ] **Step 2: Add the package**

In Xcode: **File → Add Package Dependencies…** → paste URL: `https://github.com/amplitude/Amplitude-Swift` → Dependency Rule: **Up to Next Major Version** from `1.14.0` → **Add Package** → check the `AmplitudeSwift` product → assign to target **Lumoria App** → **Add Package**.

- [ ] **Step 3: Confirm the package resolved**

In Xcode Project navigator → Package Dependencies → verify `Amplitude-Swift` listed. Run a clean build (Cmd+Shift+K then Cmd+B). Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App.xcodeproj/project.pbxproj" "Lumoria App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
git commit -m "feat(analytics): add Amplitude-Swift SPM dependency"
```

---

## Task 2: Create xcconfig files + wire them into build configs

**Files:**
- Create: `Amplitude.xcconfig` (gitignored)
- Create: `Amplitude.sample.xcconfig`
- Modify: `.gitignore`
- Modify: `Lumoria App.xcodeproj` (Xcode UI)

- [ ] **Step 1: Create `Amplitude.sample.xcconfig`**

Path: repo root (`/Users/bearista/Documents/lumoria/Lumoria App/Amplitude.sample.xcconfig`)

```xcconfig
// Amplitude.sample.xcconfig
// Copy this file to `Amplitude.xcconfig` and fill in your project's Amplitude API key.
// `Amplitude.xcconfig` is gitignored so your real key never lands in history.

AMPLITUDE_API_KEY = YOUR_AMPLITUDE_API_KEY_HERE
```

- [ ] **Step 2: Create `Amplitude.xcconfig` with the real key**

Path: repo root (`/Users/bearista/Documents/lumoria/Lumoria App/Amplitude.xcconfig`)

```xcconfig
// Amplitude.xcconfig
// DO NOT COMMIT. Gitignored.

AMPLITUDE_API_KEY = f4b490c0860c371ec46ed8b90d923de2
```

- [ ] **Step 3: Gitignore the real file**

Append to `.gitignore` (repo root):

```
# Secrets
Amplitude.xcconfig
```

- [ ] **Step 4: Verify gitignore works**

```bash
git check-ignore Amplitude.xcconfig
```

Expected output: `Amplitude.xcconfig`

- [ ] **Step 5: Wire xcconfig into the Xcode project**

In Xcode → select **Lumoria App** project in navigator → select the **Project** (not target) row → **Info** tab → **Configurations** section.

For **Debug**: click the disclosure arrow → set the config file for target **Lumoria App** to `Amplitude` (Xcode autodetects files in repo root).

Repeat for **Release**.

- [ ] **Step 6: Verify substitution in Build Settings**

Target **Lumoria App** → Build Settings → search `AMPLITUDE_API_KEY`. If the setting appears under User-Defined with the real key value for Debug and Release, wiring is correct.

- [ ] **Step 7: Commit the sample + gitignore (not the real key)**

```bash
git add Amplitude.sample.xcconfig .gitignore "Lumoria App.xcodeproj/project.pbxproj"
git status  # verify Amplitude.xcconfig NOT listed
git commit -m "chore(analytics): add xcconfig scaffolding for Amplitude key"
```

---

## Task 3: Add `AMPLITUDE_API_KEY` to Info.plist

**Files:**
- Modify: `Info.plist` (repo root)

- [ ] **Step 1: Add the key**

Open `Info.plist` (repo root — the main app target's Info.plist). Insert this before `</dict>`:

```xml
	<key>AMPLITUDE_API_KEY</key>
	<string>$(AMPLITUDE_API_KEY)</string>
```

Full final `Info.plist` diff adds only those two lines. The `$(AMPLITUDE_API_KEY)` token is substituted at build time from the xcconfig.

- [ ] **Step 2: Verify substitution**

Build the app (Cmd+B). Then inspect the compiled `Info.plist` inside the `.app`:

```bash
/usr/libexec/PlistBuddy -c "Print :AMPLITUDE_API_KEY" ~/Library/Developer/Xcode/DerivedData/Lumoria*/Build/Products/Debug-iphonesimulator/Lumoria\ App.app/Info.plist
```

Expected output: `f4b490c0860c371ec46ed8b90d923de2`

- [ ] **Step 3: Commit**

```bash
git add Info.plist
git commit -m "chore(analytics): add AMPLITUDE_API_KEY Info.plist entry"
```

---

# Phase 2 — Wrapper: type-safe events

## Task 4: `AnalyticsIdentity` + tests (TDD)

Pure, deterministic helpers. Test-first.

**Files:**
- Create: `Lumoria App/services/analytics/AnalyticsIdentity.swift`
- Create: `Lumoria AppTests/AnalyticsIdentityTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Lumoria AppTests/AnalyticsIdentityTests.swift`:

```swift
//
//  AnalyticsIdentityTests.swift
//  Lumoria AppTests
//

import Foundation
import Testing
@testable import Lumoria_App

@Suite("AnalyticsIdentity")
struct AnalyticsIdentityTests {

    @Test("hashUUID returns 16 lowercase hex chars")
    func hashUUIDFormat() {
        let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let hash = AnalyticsIdentity.hashUUID(uuid)
        #expect(hash.count == 16)
        #expect(hash.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    @Test("hashUUID is deterministic")
    func hashUUIDDeterministic() {
        let uuid = UUID()
        #expect(AnalyticsIdentity.hashUUID(uuid) == AnalyticsIdentity.hashUUID(uuid))
    }

    @Test("hashUUID differs per UUID")
    func hashUUIDDistinct() {
        let a = UUID()
        let b = UUID()
        #expect(AnalyticsIdentity.hashUUID(a) != AnalyticsIdentity.hashUUID(b))
    }

    @Test("emailDomain extracts lowercased domain")
    func emailDomainExtracts() {
        #expect(AnalyticsIdentity.emailDomain("Alice@Gmail.COM") == "gmail.com")
        #expect(AnalyticsIdentity.emailDomain("bob@example.co.uk") == "example.co.uk")
    }

    @Test("emailDomain returns nil for malformed input")
    func emailDomainNilForMalformed() {
        #expect(AnalyticsIdentity.emailDomain("no-at-sign") == nil)
        #expect(AnalyticsIdentity.emailDomain("") == nil)
        #expect(AnalyticsIdentity.emailDomain("a@") == nil)
    }

    @Test("hashString is stable across invocations")
    func hashStringStable() {
        #expect(AnalyticsIdentity.hashString("abc") == AnalyticsIdentity.hashString("abc"))
        #expect(AnalyticsIdentity.hashString("abc").count == 16)
    }
}
```

- [ ] **Step 2: Run to confirm it fails**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" test -only-testing:"Lumoria AppTests/AnalyticsIdentityTests" 2>&1 | tail -20
```

Expected: compilation error (`AnalyticsIdentity` not found).

- [ ] **Step 3: Implement `AnalyticsIdentity`**

Create `Lumoria App/services/analytics/AnalyticsIdentity.swift`:

```swift
//
//  AnalyticsIdentity.swift
//  Lumoria App
//
//  Deterministic hash + email-domain helpers. Everything here must be
//  side-effect-free and trivially testable — we use these to strip PII
//  from UUIDs and emails before they reach Amplitude.
//

import CryptoKit
import Foundation

enum AnalyticsIdentity {

    /// SHA-256(UUID) truncated to 16 hex chars. Preserves joinability of
    /// related events (e.g. Invite Shared ↔ Invite Claimed) without
    /// leaking the original primary key.
    static func hashUUID(_ uuid: UUID) -> String {
        hashString(uuid.uuidString)
    }

    static func hashString(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }

    /// Extracts the domain portion of an email address, lowercased.
    /// Returns nil when the input has no `@` or no domain part.
    static func emailDomain(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let atIndex = trimmed.firstIndex(of: "@") else { return nil }
        let domain = trimmed[trimmed.index(after: atIndex)...]
        guard !domain.isEmpty else { return nil }
        return domain.lowercased()
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" test -only-testing:"Lumoria AppTests/AnalyticsIdentityTests" 2>&1 | tail -20
```

Expected: `Test Suite 'AnalyticsIdentity' passed`.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/services/analytics/AnalyticsIdentity.swift" "Lumoria AppTests/AnalyticsIdentityTests.swift"
git commit -m "feat(analytics): add AnalyticsIdentity hash + email-domain helpers"
```

---

## Task 5: `AnalyticsProperty` typed enums

Enum values MUST match the `Enum Values` column of the Notion Event Properties DB 1:1. This file is the canonical source.

**Files:**
- Create: `Lumoria App/services/analytics/AnalyticsProperty.swift`

- [ ] **Step 1: Create the enums file**

```swift
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
    case plane, train, parks_gardens, public_transit, concert
}

enum TicketTemplateProp: String, CaseIterable {
    case afterglow, studio, terminal, heritage, prism
    case express, orient, night
}

enum OrientationProp: String, CaseIterable {
    case horizontal, vertical
}

enum ExportDestinationProp: String, CaseIterable {
    case camera_roll, whatsapp, messenger, discord
    case instagram, twitter, threads, snapchat, facebook
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

enum FunnelStepProp: String, CaseIterable {
    case category, template, orientation, form, style, success
}

enum TicketSourceProp: String, CaseIterable {
    case gallery, memory, notification, deep_link
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

/// Environment tag applied to every event as a universal property.
enum AnalyticsEnvironment: String {
    case dev, prod
}
```

- [ ] **Step 2: Build to verify compiles**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/services/analytics/AnalyticsProperty.swift"
git commit -m "feat(analytics): add AnalyticsProperty typed enums"
```

---

## Task 6: `AnalyticsEvent` enum (all 78 cases)

**Files:**
- Create: `Lumoria App/services/analytics/AnalyticsEvent.swift`
- Create: `Lumoria AppTests/AnalyticsEventTests.swift`

- [ ] **Step 1: Write a baseline test first**

Create `Lumoria AppTests/AnalyticsEventTests.swift`:

```swift
//
//  AnalyticsEventTests.swift
//  Lumoria AppTests
//

import Foundation
import Testing
@testable import Lumoria_App

@Suite("AnalyticsEvent")
struct AnalyticsEventTests {

    @Test("ticketCreated has the right name and core properties")
    func ticketCreatedShape() {
        let event = AnalyticsEvent.ticketCreated(
            category: .plane,
            template: .afterglow,
            orientation: .horizontal,
            styleId: "afterglow.default",
            fieldFillCount: 8,
            hasOriginLocation: true,
            hasDestinationLocation: true,
            ticketsLifetime: 5
        )
        #expect(event.name == "Ticket Created")
        let props = event.properties
        #expect(props["ticket_category"] as? String == "plane")
        #expect(props["ticket_template"] as? String == "afterglow")
        #expect(props["ticket_orientation"] as? String == "horizontal")
        #expect(props["style_id"] as? String == "afterglow.default")
        #expect(props["field_fill_count"] as? Int == 8)
        #expect(props["has_origin_location"] as? Bool == true)
        #expect(props["tickets_lifetime"] as? Int == 5)
    }

    @Test("loginSucceeded carries email domain but never email")
    func loginSucceededShape() {
        let event = AnalyticsEvent.loginSucceeded(emailDomain: "gmail.com", wasFromInvite: false)
        #expect(event.name == "Login Succeeded")
        #expect(event.properties["email_domain"] as? String == "gmail.com")
        #expect(event.properties["was_from_invite"] as? Bool == false)
        #expect(event.properties["email"] == nil)
    }

    @Test("inviteShared uses token hash not raw token")
    func inviteSharedShape() {
        let event = AnalyticsEvent.inviteShared(
            channel: .system_share,
            inviteTokenHash: "abc0123456789def"
        )
        #expect(event.name == "Invite Shared")
        #expect(event.properties["channel"] as? String == "system_share")
        #expect(event.properties["invite_token_hash"] as? String == "abc0123456789def")
        #expect(event.properties["invite_token"] == nil)
    }
}
```

- [ ] **Step 2: Run to confirm it fails**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" test -only-testing:"Lumoria AppTests/AnalyticsEventTests" 2>&1 | tail -20
```

Expected: compilation error (`AnalyticsEvent` not found).

- [ ] **Step 3: Implement `AnalyticsEvent`**

Create `Lumoria App/services/analytics/AnalyticsEvent.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify pass**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" test -only-testing:"Lumoria AppTests/AnalyticsEventTests" 2>&1 | tail -20
```

Expected: `Test Suite 'AnalyticsEvent' passed`.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/services/analytics/AnalyticsEvent.swift" "Lumoria AppTests/AnalyticsEventTests.swift"
git commit -m "feat(analytics): add AnalyticsEvent enum covering all 78 tracked events"
```

---

## Task 7: `AnalyticsService` protocol + `Analytics` singleton + `NoopAnalyticsService`

**Files:**
- Create: `Lumoria App/services/analytics/AnalyticsService.swift`
- Create: `Lumoria App/services/analytics/NoopAnalyticsService.swift`

- [ ] **Step 1: Create the protocol + singleton**

`Lumoria App/services/analytics/AnalyticsService.swift`:

```swift
//
//  AnalyticsService.swift
//  Lumoria App
//
//  Protocol + singleton entry point for analytics. Views call
//  `Analytics.track(.someEvent(...))`. The concrete backend (Amplitude,
//  Noop for previews) is injected once at app launch.
//

import Foundation

protocol AnalyticsService: AnyObject {
    /// Track a single event. Implementations must be non-blocking.
    func track(_ event: AnalyticsEvent)

    /// Associate subsequent events with a user. `userId` is the raw
    /// Supabase UUID (no PII).
    func identify(userId: String, userProperties: [String: Any])

    /// Update user properties without firing an event.
    func updateUserProperties(_ properties: [String: Any])

    /// Clear user id + rotate device id. Called on logout.
    func reset()

    /// Toggle analytics opt-out at runtime (future consent screen).
    func setOptOut(_ optedOut: Bool)
}

/// Thread-safe singleton. `configure(_:)` must be called once at app
/// launch before any `track(_:)` call. Safe to call tracking before
/// configure — events fall through to a no-op until configured.
enum Analytics {

    private static var backend: AnalyticsService = NoopAnalyticsService()

    /// Install the production analytics backend. Call once at app launch.
    static func configure(_ service: AnalyticsService) {
        backend = service
    }

    static func track(_ event: AnalyticsEvent) {
        backend.track(event)
    }

    static func identify(userId: String, userProperties: [String: Any] = [:]) {
        backend.identify(userId: userId, userProperties: userProperties)
    }

    static func updateUserProperties(_ properties: [String: Any]) {
        backend.updateUserProperties(properties)
    }

    static func reset() {
        backend.reset()
    }

    static func setOptOut(_ optedOut: Bool) {
        backend.setOptOut(optedOut)
    }
}
```

- [ ] **Step 2: Create the no-op backend**

`Lumoria App/services/analytics/NoopAnalyticsService.swift`:

```swift
//
//  NoopAnalyticsService.swift
//  Lumoria App
//
//  Default backend used before `Analytics.configure(_:)` runs and in
//  SwiftUI previews / unit tests. Drops every call silently.
//

import Foundation

final class NoopAnalyticsService: AnalyticsService {
    func track(_ event: AnalyticsEvent) { }
    func identify(userId: String, userProperties: [String: Any]) { }
    func updateUserProperties(_ properties: [String: Any]) { }
    func reset() { }
    func setOptOut(_ optedOut: Bool) { }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/services/analytics/AnalyticsService.swift" "Lumoria App/services/analytics/NoopAnalyticsService.swift"
git commit -m "feat(analytics): add AnalyticsService protocol + Noop backend"
```

---

## Task 8: `AmplitudeAnalyticsService` (production backend)

**Files:**
- Create: `Lumoria App/services/analytics/AmplitudeAnalyticsService.swift`

- [ ] **Step 1: Create the Amplitude backend**

```swift
//
//  AmplitudeAnalyticsService.swift
//  Lumoria App
//
//  Production analytics backend. Reads the API key from Info.plist
//  (populated from `Amplitude.xcconfig`) and wires every event through
//  the SDK with a universal property envelope (environment, app version,
//  brand slug, etc.). Session-only autocapture; everything else manual.
//

import AmplitudeSwift
import Foundation
import UIKit

final class AmplitudeAnalyticsService: AnalyticsService {

    private let amplitude: Amplitude
    private var universalProperties: [String: Any] = [:]

    /// Init fails soft: if the API key is missing the caller should fall
    /// back to `NoopAnalyticsService`. We return nil instead of crashing
    /// because a dev without the xcconfig shouldn't be blocked.
    init?() {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "AMPLITUDE_API_KEY") as? String,
            !key.isEmpty,
            key != "YOUR_AMPLITUDE_API_KEY_HERE"
        else {
            print("[Analytics] AMPLITUDE_API_KEY missing — analytics disabled.")
            return nil
        }

        let config = Configuration(
            apiKey: key,
            defaultTracking: DefaultTrackingOptions(sessions: true),
            serverZone: .US,
            trackingOptions: TrackingOptions().disableIPAddress()
        )
        self.amplitude = Amplitude(configuration: config)

        self.universalProperties = Self.buildUniversalProperties()
    }

    // MARK: - AnalyticsService

    func track(_ event: AnalyticsEvent) {
        var merged = universalProperties
        for (k, v) in event.properties { merged[k] = v }
        amplitude.track(eventType: event.name, eventProperties: merged)
    }

    func identify(userId: String, userProperties: [String: Any]) {
        amplitude.setUserId(userId: userId)
        if !userProperties.isEmpty {
            updateUserProperties(userProperties)
        }
    }

    func updateUserProperties(_ properties: [String: Any]) {
        let identify = Identify()
        for (key, value) in properties {
            identify.set(property: key, value: value)
        }
        amplitude.identify(identify: identify)
    }

    func reset() {
        amplitude.reset()
    }

    func setOptOut(_ optedOut: Bool) {
        amplitude.optOut = optedOut
    }

    // MARK: - Universal properties

    private static func buildUniversalProperties() -> [String: Any] {
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"

        #if DEBUG
        let environment = AnalyticsEnvironment.dev.rawValue
        #else
        let environment = AnalyticsEnvironment.prod.rawValue
        #endif

        return [
            "environment": environment,
            "app_version": appVersion,
            "build_number": buildNumber,
        ]
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. If `TrackingOptions().disableIPAddress()` or `Identify()` APIs fail to resolve, the SDK surface has drifted — consult the AmplitudeSwift README and adjust call sites. The imports and method names above match AmplitudeSwift v1.14 at time of plan.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/services/analytics/AmplitudeAnalyticsService.swift"
git commit -m "feat(analytics): add AmplitudeAnalyticsService production backend"
```

---

## Task 9: Boot the SDK in `Lumoria_AppApp.swift`

**Files:**
- Modify: `Lumoria App/Lumoria_AppApp.swift`

- [ ] **Step 1: Add SDK boot + app-open event**

At the top of the file, add `import SwiftUI` and `import SwiftData` already exist. Replace the `init()` of `LumoriaAppDelegate` (or add one if absent) to bootstrap Analytics before any view renders.

Given the existing file uses `@UIApplicationDelegateAdaptor(LumoriaAppDelegate.self)`, find `LumoriaAppDelegate` (search under `Lumoria App/` — likely in `services/PushNotificationService.swift` or alongside). Add this at the **top of `Lumoria_AppApp.swift`**, above `@main`:

```swift
// Analytics bootstrapping. Runs once at process start, before any view
// is constructed. Missing API key falls back to NoopAnalyticsService.
private let analyticsBootstrap: Void = {
    if let service = AmplitudeAnalyticsService() {
        Analytics.configure(service)
    }
    Analytics.track(.sdkInitialized)
}()
```

Then inside `Lumoria_AppApp`, add a `_ = analyticsBootstrap` reference at init to force evaluation:

```swift
init() {
    _ = analyticsBootstrap
}
```

- [ ] **Step 2: Add App Opened + Deep Link events**

In `Lumoria_AppApp.swift`, modify the `.onOpenURL` closure to fire `Deep Link Opened` and `Invite Link Opened`. Locate the existing:

```swift
.onOpenURL { url in
    handleIncomingURL(url)
}
```

And update `handleIncomingURL` at the bottom of the file:

```swift
private func handleIncomingURL(_ url: URL) {
    let host = url.host
    let scheme = url.scheme ?? "unknown"
    let token = InviteLink.token(from: url)
    let kind: DeepLinkKindProp = token != nil ? .invite : .other

    Analytics.track(.deepLinkOpened(scheme: scheme, host: host, kind: kind))

    guard let token else { return }
    let hash = AnalyticsIdentity.hashString(token)
    let wasAuthenticated = authManager.isAuthenticated
    Analytics.track(.inviteLinkOpened(inviteTokenHash: hash, wasAuthenticated: wasAuthenticated))

    PendingInviteTokenStore.save(token)

    if wasAuthenticated {
        Task {
            guard let pending = PendingInviteTokenStore.take() else { return }
            await InvitesStore.claim(token: pending)
            Analytics.track(.inviteAutoClaimed(inviteTokenHash: hash))
        }
    }
}
```

Also in the `.task` modifier block (after `requestAuthorization`), fire `App Opened`:

```swift
.task {
    Analytics.track(.appOpened(source: .cold))
    await pushService.requestAuthorization()
}
```

- [ ] **Step 3: Build + run in simulator**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. Then launch in Simulator and inspect Xcode console — `[Amplitude]` log lines confirming `SDK Initialized` + `App Opened` should print.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/Lumoria_AppApp.swift"
git commit -m "feat(analytics): boot Amplitude SDK + track app open + deep link events"
```

---

# Phase 3 — Instrumentation

Tasks 10-20 each instrument one surface. Pattern per task: read the file, insert `Analytics.track(.event(…))` at the right call sites, rebuild. No TDD for these tasks — they are integration points that would require UI testing to validate deterministically; we rely on the Amplitude User Lookup (Task 21) as the end-to-end verification.

## Task 10: Auth instrumentation

**Files:**
- Modify: `Lumoria App/views/authentication/AuthManager.swift`
- Modify: `Lumoria App/views/authentication/SignUpView.swift`
- Modify: `Lumoria App/views/authentication/LogInView.swift`
- Modify: `Lumoria App/views/authentication/ForgotPasswordView.swift`

- [ ] **Step 1: `AuthManager` — track login/logout + session restore + identify**

In `AuthManager.swift`, extend `listenForAuthChanges()`:

```swift
private func listenForAuthChanges() async {
    for await (event, session) in supabase.auth.authStateChanges {
        switch event {
        case .initialSession:
            let valid = session.map { !$0.isExpired } ?? false
            isAuthenticated = valid
            Analytics.track(.sessionRestored(hadCache: AuthCache.hasCache))
            if valid, let user = session?.user {
                provisionDataKey(for: user.id)
                identifyUser(user)
                await checkBetaStatus()
                await claimPendingInviteIfAny()
            }
        case .signedIn, .tokenRefreshed, .userUpdated:
            isAuthenticated = session != nil
            if let user = session?.user {
                provisionDataKey(for: user.id)
                if event == .signedIn {
                    let domain = AnalyticsIdentity.emailDomain(user.email ?? "") ?? "unknown"
                    let hadPendingInvite = PendingInviteTokenStore.peek() != nil
                    Analytics.track(.loginSucceeded(emailDomain: domain,
                                                    wasFromInvite: hadPendingInvite))
                }
                identifyUser(user)
                await checkBetaStatus()
                await claimPendingInviteIfAny()
            }
        case .signedOut:
            isAuthenticated = false
            isBetaSubscriber = false
            Analytics.track(.logout)
            Analytics.reset()
        default:
            break
        }
    }
}

private func identifyUser(_ user: User) {
    let userId = user.id.uuidString
    let domain = AnalyticsIdentity.emailDomain(user.email ?? "") ?? "unknown"
    Analytics.identify(userId: userId, userProperties: [
        "email_domain": domain,
    ])
}
```

Note: if `PendingInviteTokenStore` has no `peek()` method, add it or inline the check (e.g. mirror `take()` without consuming).

- [ ] **Step 2: `SignUpView` — track submitted + failed + verification sent**

In `SignUpView.swift`, find the submit action (the "Create account" button handler). Before the `supabase.auth.signUp` call, add:

```swift
let domain = AnalyticsIdentity.emailDomain(email) ?? "unknown"
Analytics.track(.signupSubmitted(emailDomain: domain, hasName: !name.isEmpty))
```

In the success branch:

```swift
Analytics.track(.signupVerificationSent(emailDomain: domain))
```

In the error branch:

```swift
let errType: AuthErrorTypeProp = {
    let msg = (error.localizedDescription).lowercased()
    if msg.contains("registered") || msg.contains("exists") { return .email_in_use }
    if msg.contains("password") { return .weak_password }
    if msg.contains("network") || msg.contains("offline") { return .network }
    return .unknown
}()
Analytics.track(.signupFailed(errorType: errType))
```

Also in the view's initial rendering (`onAppear`), fire `Signup Started`:

```swift
.onAppear { Analytics.track(.signupStarted) }
```

- [ ] **Step 3: `LogInView` — track submitted + failed (success handled in AuthManager)**

Before the `supabase.auth.signIn` call:

```swift
let domain = AnalyticsIdentity.emailDomain(email) ?? "unknown"
Analytics.track(.loginSubmitted(emailDomain: domain))
```

In the error branch (mirror of SignUpView's mapping but with `.invalid_credentials` as the default):

```swift
let errType: AuthErrorTypeProp = {
    let msg = error.localizedDescription.lowercased()
    if msg.contains("invalid") || msg.contains("credentials") { return .invalid_credentials }
    if msg.contains("network") || msg.contains("offline") { return .network }
    if msg.contains("cancel") { return .cancelled }
    return .unknown
}()
Analytics.track(.loginFailed(errorType: errType))
```

- [ ] **Step 4: `ForgotPasswordView` — track request**

In the "Send reset link" action:

```swift
let domain = AnalyticsIdentity.emailDomain(email) ?? "unknown"
Analytics.track(.passwordResetRequested(emailDomain: domain))
```

- [ ] **Step 5: Build + commit**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

```bash
git add "Lumoria App/views/authentication/"
git commit -m "feat(analytics): instrument auth flows (signup/login/logout/session)"
```

---

## Task 11: New Ticket funnel instrumentation

**Files:**
- Modify: `Lumoria App/views/tickets/new/NewTicketFunnel.swift` (state holder)
- Modify: `Lumoria App/views/tickets/new/NewTicketFunnelView.swift`
- Modify: `Lumoria App/views/tickets/new/CategoryStep.swift`
- Modify: `Lumoria App/views/tickets/new/TemplateStep.swift`
- Modify: `Lumoria App/views/tickets/new/OrientationStep.swift`
- Modify: `Lumoria App/views/tickets/new/FormStep.swift`
- Modify: `Lumoria App/views/tickets/new/StyleStep.swift`
- Modify: `Lumoria App/views/tickets/new/SuccessStep.swift`

- [ ] **Step 1: Mapping helpers**

Add to `NewTicketFunnel.swift` (or a new file `Lumoria App/services/analytics/AnalyticsMappers.swift` if you prefer):

```swift
import Foundation

extension TicketTemplateKind {
    var analyticsTemplate: TicketTemplateProp {
        switch self {
        case .afterglow: return .afterglow
        case .studio: return .studio
        case .terminal: return .terminal
        case .heritage: return .heritage
        case .prism: return .prism
        case .express: return .express
        case .orient: return .orient
        case .night: return .night
        }
    }

    var analyticsCategory: TicketCategoryProp {
        switch self {
        case .afterglow, .studio, .terminal, .heritage, .prism: return .plane
        case .express, .orient, .night: return .train
        }
    }
}
```

Adjust enum cases to match the actual `TicketTemplateKind` cases in the codebase; compile will flag missing cases.

- [ ] **Step 2: `NewTicketFunnelView` — track entry, abandonment**

At the top of `NewTicketFunnelView`'s body, add `@State private var funnelStartedAt = Date()`. In `.onAppear`:

```swift
.onAppear {
    funnelStartedAt = Date()
    Analytics.track(.newTicketStarted(entryPoint: .gallery))
}
```

The entry-point parameter depends on presentation source. If there are multiple entries (from a memory detail page, from a notification), pass an explicit `TicketEntryPointProp` into `NewTicketFunnelView` and use it here instead of a hardcoded `.gallery`. Default remains `.gallery`.

For abandonment, track on dismissal unless `Ticket Created` fired. Use an observed flag on the funnel state:

```swift
.onDisappear {
    guard !funnel.didCreateTicket else { return }
    let ms = Int(Date().timeIntervalSince(funnelStartedAt) * 1000)
    Analytics.track(.ticketFunnelAbandoned(
        stepReached: funnel.currentStepProp,
        timeInFunnelMs: ms
    ))
}
```

Add `var didCreateTicket: Bool = false` and `var currentStepProp: FunnelStepProp { … }` to `NewTicketFunnel` (the state class). Map the funnel's current step enum to `FunnelStepProp`.

- [ ] **Step 3: Category / Template / Orientation**

In `CategoryStep`'s selection action:

```swift
Analytics.track(.ticketCategorySelected(category: selection.analyticsCategoryProp))
```

Where `selection` is the chosen category and `analyticsCategoryProp` maps to `TicketCategoryProp`. Add that mapping extension to the category enum in the file.

In `TemplateStep`:

```swift
Analytics.track(.ticketTemplateSelected(
    category: template.analyticsCategory,
    template: template.analyticsTemplate
))
```

In `OrientationStep`:

```swift
let orient: OrientationProp = selected == .horizontal ? .horizontal : .vertical
Analytics.track(.ticketOrientationSelected(
    template: funnel.template.analyticsTemplate,
    orientation: orient
))
```

- [ ] **Step 4: Form + Style**

In `FormStep` (and variants) `onAppear`:

```swift
.onAppear {
    Analytics.track(.ticketFormStarted(template: funnel.template.analyticsTemplate))
}
```

On submit (Next button action), compute `field_fill_count` from `Mirror(reflecting: form)` or count non-empty fields explicitly:

```swift
let filled = countFilledFields(form)
let hasOrigin = (form.originLocation != nil)
let hasDest = (form.destinationLocation != nil)
Analytics.track(.ticketFormSubmitted(
    template: funnel.template.analyticsTemplate,
    fieldFillCount: filled,
    hasOriginLocation: hasOrigin,
    hasDestinationLocation: hasDest
))
```

For forms without location fields (train variants without IATA/MapKit lookups), pass `false` for both location bools.

In `StyleStep` selection:

```swift
Analytics.track(.ticketStyleSelected(
    template: funnel.template.analyticsTemplate,
    styleId: selectedVariant.id
))
```

- [ ] **Step 5: `SuccessStep` — `Ticket Created` + first-time**

On `.onAppear` (the step fires `funnel.persist(...)` then sets `createdTicket` on success). Track **after** `createdTicket` is set (watch via `.onChange(of: createdTicket)`):

```swift
.onChange(of: funnel.createdTicket) { _, created in
    guard let created else { return }
    funnel.didCreateTicket = true

    let category = created.kind.analyticsCategory
    let template = created.kind.analyticsTemplate
    let orientation: OrientationProp = created.orientation == .horizontal ? .horizontal : .vertical
    let styleId = created.styleId
    let fieldCount = created.fieldFillCount  // fill this field on the ticket during persist
    let hasOrigin = created.originLocation != nil
    let hasDest = created.destinationLocation != nil
    let lifetime = ticketsStore.tickets.count

    Analytics.track(.ticketCreated(
        category: category, template: template, orientation: orientation,
        styleId: styleId, fieldFillCount: fieldCount,
        hasOriginLocation: hasOrigin, hasDestinationLocation: hasDest,
        ticketsLifetime: lifetime
    ))

    Analytics.updateUserProperties([
        "tickets_created_lifetime": lifetime,
        "last_ticket_category": category.rawValue,
    ])

    if lifetime == 1 {
        Analytics.track(.firstTicketCreated(category: category, template: template))
        Analytics.updateUserProperties(["has_created_first_ticket": true])
    }
}
```

On the error branch (`errorMessage` set):

```swift
.onChange(of: funnel.errorMessage) { _, err in
    guard let err else { return }
    Analytics.track(.ticketCreationFailed(
        stepReached: .success,
        errorType: err
    ))
}
```

If `createdTicket.fieldFillCount` does not already exist as a property on the model, either:
- Compute locally from the form in `funnel.persist(...)` and stash it, or
- Pass it via the `persist` call into the event separately.

- [ ] **Step 6: Build + commit**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

```bash
git add "Lumoria App/views/tickets/new/"
git commit -m "feat(analytics): instrument new ticket funnel (category → success)"
```

---

## Task 12: Ticket gallery + detail instrumentation

**Files:**
- Modify: `Lumoria App/views/tickets/AllTicketsView.swift`
- Modify: `Lumoria App/views/tickets/TicketDetailView.swift`

- [ ] **Step 1: Gallery — refresh + sort**

In `AllTicketsView`'s pull-to-refresh action:

```swift
await store.load()
Analytics.track(.galleryRefreshed(ticketCount: store.tickets.count))
```

In the sort picker / menu action (wherever the sort selection is committed):

```swift
let sort: GallerySortProp = {
    switch selected {
    case .date: return .date
    case .category: return .category
    case .none: return .none
    }
}()
Analytics.track(.gallerySortApplied(sortType: sort))
```

- [ ] **Step 2: Detail — opened / deleted**

`TicketDetailView.onAppear`:

```swift
.onAppear {
    Analytics.track(.ticketOpened(
        category: ticket.kind.analyticsCategory,
        template: ticket.kind.analyticsTemplate,
        source: openedFromSource  // passed in via init; default .gallery
    ))
}
```

Add a `var openedFromSource: TicketSourceProp = .gallery` init parameter to `TicketDetailView` so call sites (memory detail, notification tap) can override.

On delete confirmation:

```swift
Analytics.track(.ticketDeleted(
    category: ticket.kind.analyticsCategory,
    template: ticket.kind.analyticsTemplate,
    wasInMemory: !ticket.memberships.isEmpty
))
```

On add/remove from memory:

```swift
// inside the toggle action
if becomingMember {
    Analytics.track(.ticketAddedToMemory(
        memoryIdHash: AnalyticsIdentity.hashUUID(memory.id),
        newTicketCount: memory.tickets.count + 1
    ))
} else {
    Analytics.track(.ticketRemovedFromMemory(
        memoryIdHash: AnalyticsIdentity.hashUUID(memory.id)
    ))
}
```

- [ ] **Step 3: Build + commit**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

```bash
git add "Lumoria App/views/tickets/AllTicketsView.swift" "Lumoria App/views/tickets/TicketDetailView.swift"
git commit -m "feat(analytics): instrument ticket gallery + detail views"
```

---

## Task 13: Export sheet instrumentation

**Files:**
- Modify: `Lumoria App/views/tickets/new/ExportSheet.swift`

- [ ] **Step 1: Sheet opened**

Find the presenting view that shows `ExportSheet`. In `ExportSheet`'s `.onAppear`:

```swift
.onAppear {
    Analytics.track(.exportSheetOpened(
        category: ticket.kind.analyticsCategory,
        template: ticket.kind.analyticsTemplate
    ))
}
```

- [ ] **Step 2: Destination selected**

In the destination button actions (Phase A — IG/WhatsApp/Messenger/Discord/Camera Roll), before routing:

```swift
let dest: ExportDestinationProp = /* map enum here */
Analytics.track(.exportDestinationSelected(destination: dest))
```

Create a mapping helper in the file:

```swift
private extension ExportSheet.Destination {
    var analyticsProp: ExportDestinationProp {
        switch self {
        case .cameraRoll: return .camera_roll
        case .whatsapp: return .whatsapp
        case .messenger: return .messenger
        case .discord: return .discord
        case .instagram: return .instagram
        case .twitter: return .twitter
        case .threads: return .threads
        case .snapchat: return .snapchat
        case .facebook: return .facebook
        }
    }
}
```

Adjust case names to match the actual enum.

- [ ] **Step 3: Camera-roll configured + exported**

On Phase B commit (Export button):

```swift
Analytics.track(.cameraRollExportConfigured(
    includeBackground: includeBackground,
    includeWatermark: includeWatermark,
    resolution: resolution.analyticsProp,
    crop: crop.analyticsProp,
    format: format.analyticsProp
))

let start = Date()
// … existing render + save logic …
let durationMs = Int(Date().timeIntervalSince(start) * 1000)

Analytics.track(.ticketExported(
    destination: .camera_roll,
    resolution: resolution.analyticsProp,
    crop: crop.analyticsProp,
    format: format.analyticsProp,
    includeBackground: includeBackground,
    includeWatermark: includeWatermark,
    durationMs: durationMs
))
Analytics.updateUserProperties(["last_export_destination": ExportDestinationProp.camera_roll.rawValue])
```

Add `analyticsProp` mapping extensions for the resolution/crop/format enums similarly.

On failure:

```swift
Analytics.track(.ticketExportFailed(destination: .camera_roll, errorType: error.localizedDescription))
```

- [ ] **Step 4: IM share**

After the `UIActivityViewController` completes with a non-cancelled destination:

```swift
// In the activityViewController's completionHandler:
completionWithItemsHandler = { activityType, completed, _, _ in
    guard completed else { return }
    let platform: IMPlatformProp = {
        guard let t = activityType?.rawValue.lowercased() else { return .other }
        if t.contains("whatsapp") { return .whatsapp }
        if t.contains("messenger") || t.contains("fb-messenger") { return .messenger }
        if t.contains("discord") { return .discord }
        return .other
    }()
    Analytics.track(.ticketSharedViaIM(platform: platform))
    Analytics.track(.ticketExported(
        destination: ExportDestinationProp(rawValue: platform.rawValue) ?? .camera_roll,
        resolution: nil, crop: nil, format: nil,
        includeBackground: nil, includeWatermark: nil,
        durationMs: 0
    ))
}
```

- [ ] **Step 5: Build + commit**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

```bash
git add "Lumoria App/views/tickets/new/ExportSheet.swift"
git commit -m "feat(analytics): instrument export sheet + IM share completion"
```

---

## Task 14: Memories instrumentation

**Files:**
- Modify: `Lumoria App/views/collections/CollectionsStore.swift` (or equivalent `MemoriesStore` location — verify path)
- Modify: memory views: `MemoriesView.swift`, `MemoryDetailView.swift`, `NewMemoryView.swift` (or `NewCollectionView.swift`)

- [ ] **Step 1: Locate MemoriesStore**

```bash
grep -rn "class MemoriesStore" "Lumoria App/"
```

Use the returned path in the following steps. The app mixes naming: spec refers to `MemoriesStore`, files may live under `views/collections/`.

- [ ] **Step 2: `Memory Created` in MemoriesStore.create(...)**

After a successful insert:

```swift
let colorFamily = MemoryColorFamilyProp(rawValue: colorFamilyName.lowercased()) ?? .gray
let nameLen = name.count

Analytics.track(.memoryCreated(
    colorFamily: colorFamily,
    hasEmoji: !(emoji?.isEmpty ?? true),
    nameLength: nameLen
))

let lifetime = memories.count
Analytics.updateUserProperties(["memories_created_lifetime": lifetime])

if lifetime == 1 {
    Analytics.track(.firstMemoryCreated(colorFamily: colorFamily))
    Analytics.updateUserProperties(["has_created_first_memory": true])
}
```

- [ ] **Step 3: `MemoryDetailView` — opened**

`.onAppear`:

```swift
.onAppear {
    Analytics.track(.memoryOpened(
        source: source,  // add init param, default .gallery
        ticketCount: memory.tickets.count,
        memoryIdHash: AnalyticsIdentity.hashUUID(memory.id)
    ))
}
```

- [ ] **Step 4: `NewMemoryView` — creation started**

`.onAppear`:

```swift
.onAppear { Analytics.track(.memoryCreationStarted) }
```

- [ ] **Step 5: Edit + Delete**

In the edit-save action:

```swift
Analytics.track(.memoryEdited(
    nameChanged: nameDidChange,
    emojiChanged: emojiDidChange,
    colorChanged: colorDidChange,
    memoryIdHash: AnalyticsIdentity.hashUUID(memory.id)
))
```

In delete confirmation:

```swift
Analytics.track(.memoryDeleted(
    ticketCount: memory.tickets.count,
    memoryIdHash: AnalyticsIdentity.hashUUID(memory.id)
))
```

- [ ] **Step 6: Build + commit**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

```bash
git add "Lumoria App/views/collections/"
git commit -m "feat(analytics): instrument memory create/open/edit/delete"
```

---

## Task 15: Invites + Referral instrumentation

**Files:**
- Modify: `Lumoria App/views/settings/InvitesStore.swift`
- Modify: `Lumoria App/views/settings/InviteView.swift`

- [ ] **Step 1: `InviteView` — page viewed**

`.onAppear`:

```swift
.onAppear {
    let state: InvitePageStateProp = {
        switch store.state {
        case .loading, .notSent: return .not_sent
        case .sent: return .sent
        case .redeemed: return .redeemed
        }
    }()
    Analytics.track(.invitePageViewed(state: state))
}
```

- [ ] **Step 2: `InvitesStore.sendInvite()` — invite generated**

After a successful insert:

```swift
let tokenHash = AnalyticsIdentity.hashString(token)
Analytics.track(.inviteGenerated(isFirstTime: previousInviteCount == 0))
Analytics.track(.inviteShared(channel: .system_share, inviteTokenHash: tokenHash))
Analytics.updateUserProperties(["invites_sent": previousInviteCount + 1])
```

Actually split: `Invite Generated` fires on first generation; `Invite Shared` fires when the share sheet is actually invoked. If InviteView presents a share sheet separately, move the `.inviteShared(...)` call into that action handler. Use `.copy_link` when the user taps a copy-button, `.system_share` when they tap the system share sheet.

- [ ] **Step 3: `InvitesStore.claim(token:)` — invite claimed**

Before the rpc call, capture `let start = Date()`. On success:

```swift
let ms = Int(Date().timeIntervalSince(start) * 1000)
Analytics.track(.inviteClaimed(
    inviteTokenHash: AnalyticsIdentity.hashString(token),
    role: .invitee,
    timeToClaimMs: ms
))
Analytics.updateUserProperties(["invites_redeemed": /* increment */ ])
```

- [ ] **Step 4: Build + commit**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

```bash
git add "Lumoria App/views/settings/InvitesStore.swift" "Lumoria App/views/settings/InviteView.swift"
git commit -m "feat(analytics): instrument invite generate/share/claim"
```

---

## Task 16: Settings screens instrumentation

**Files:**
- Modify: `Lumoria App/views/settings/SettingsView.swift`
- Modify: `Lumoria App/views/settings/ProfileView.swift`
- Modify: `Lumoria App/views/settings/AppearanceView.swift`

- [ ] **Step 1: `SettingsView` opened**

`.onAppear`:

```swift
.onAppear { Analytics.track(.settingsOpened) }
```

- [ ] **Step 2: Legal links**

Each legal link button action:

```swift
// TOS
Analytics.track(.legalLinkOpened(linkType: .tos))
// Privacy
Analytics.track(.legalLinkOpened(linkType: .privacy))
// Support (mailto)
Analytics.track(.legalLinkOpened(linkType: .support))
```

- [ ] **Step 3: `AppearanceView` — mode + high contrast + icon**

Mode picker onChange:

```swift
.onChange(of: storedMode) { _, newValue in
    let prop: AppearanceModeProp = {
        switch newValue {
        case AppearanceMode.light.rawValue: return .light
        case AppearanceMode.dark.rawValue: return .dark
        default: return .system
        }
    }()
    Analytics.track(.appearanceModeChanged(mode: prop))
    Analytics.updateUserProperties(["appearance_mode": prop.rawValue])
}
```

High contrast toggle onChange:

```swift
.onChange(of: highContrast) { _, on in
    Analytics.track(.highContrastToggled(enabled: on))
    Analytics.updateUserProperties(["high_contrast_enabled": on])
}
```

App icon selection action (after successful `setAlternateIconName`):

```swift
Analytics.track(.appIconChanged(iconName: selectedIconName.isEmpty ? "default" : selectedIconName))
Analytics.updateUserProperties(["app_icon": selectedIconName.isEmpty ? "default" : selectedIconName])
```

- [ ] **Step 4: `ProfileView` — viewed + edit started + saved + avatar uploaded**

`.onAppear`:

```swift
.onAppear { Analytics.track(.profileViewed) }
```

Edit button action (enter edit mode):

```swift
Analytics.track(.profileEditStarted)
```

Save action (successful):

```swift
Analytics.track(.profileSaved(
    nameChanged: nameDidChange,
    avatarChanged: avatarDidChange
))
```

After a successful avatar upload:

```swift
Analytics.track(.avatarUploaded(source: avatarSource))
```

Where `avatarSource` is `.camera` or `.library` depending on the picker.

- [ ] **Step 5: Build + commit**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

```bash
git add "Lumoria App/views/settings/"
git commit -m "feat(analytics): instrument settings (appearance/icon/profile/legal)"
```

---

## Task 17: Notifications instrumentation

**Files:**
- Modify: `Lumoria App/services/PushNotificationService.swift`
- Modify: `Lumoria App/views/notifications/NotificationCenterView.swift`
- Modify: `Lumoria App/views/notifications/NotificationsStore.swift`

- [ ] **Step 1: Push permission flow**

In `PushNotificationService.requestAuthorization()`, before calling `UNUserNotificationCenter.current().requestAuthorization(...)`:

```swift
Analytics.track(.pushPermissionRequested)
```

After:

```swift
Analytics.track(.pushPermissionResponded(granted: granted))
Analytics.updateUserProperties(["push_enabled": granted])
```

- [ ] **Step 2: Push received + opened**

In `userNotificationCenter(_:willPresent:withCompletionHandler:)`:

```swift
let kind = parseKind(from: notification) ?? .news
Analytics.track(.pushReceived(notificationKind: kind, inForeground: true))
```

In `userNotificationCenter(_:didReceive:withCompletionHandler:)` (tap):

```swift
let kind = parseKind(from: response.notification) ?? .news
let target = response.notification.request.content.userInfo["deep_link"] as? String
Analytics.track(.pushOpened(notificationKind: kind, deepLinkTarget: target))
```

- [ ] **Step 3: Notification center**

`NotificationCenterView.onAppear`:

```swift
.onAppear {
    Analytics.track(.notificationCenterOpened(unreadCount: store.unreadCount))
}
```

Tap action on a row:

```swift
Analytics.track(.notificationTapped(
    notificationKind: notification.kind.analyticsProp,
    source: .center
))
```

Mark-as-read action:

```swift
Analytics.track(.notificationMarkedRead(notificationKind: notification.kind.analyticsProp))
```

Add a `.analyticsProp` extension on your notification kind enum to map to `NotificationKindProp`.

- [ ] **Step 4: Notification prefs changed**

In `NotificationsView.swift` (settings), on each toggle:

```swift
Analytics.track(.notificationPrefsChanged(notificationType: "throwback", enabled: toggledOn))
```

Repeat for each notification type toggle in the view.

- [ ] **Step 5: Build + commit**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

```bash
git add "Lumoria App/services/PushNotificationService.swift" "Lumoria App/views/notifications/" "Lumoria App/views/settings/NotificationsView.swift"
git commit -m "feat(analytics): instrument push + notification center + prefs"
```

---

## Task 18: Error plumbing

**Files:**
- Modify: stores surfacing `errorMessage` (TicketsStore, MemoriesStore, InvitesStore, ProfileStore, NotificationsStore)

- [ ] **Step 1: Fire `App Error` on every error setter**

For each store, find the single line that sets `errorMessage = ...` (or a shared `handle(_:)` method) and add an analytics call alongside. Example in `TicketsStore.swift`:

```swift
// In the catch block that assigns errorMessage:
Analytics.track(.appError(
    domain: .ticket,
    code: (error as NSError).code.description,
    viewContext: "TicketsStore.create"
))
```

Map store to domain:
- TicketsStore → `.ticket`
- MemoriesStore → `.memory`
- InvitesStore → `.invite`
- ProfileStore → `.auth` (profile is auth-adjacent) or `.supabase`
- NotificationsStore → `.notification`
- PushNotificationService → `.notification`

- [ ] **Step 2: Build + commit**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

```bash
git add "Lumoria App/views/" "Lumoria App/services/"
git commit -m "feat(analytics): surface store errors as App Error events"
```

---

# Phase 4 — Verification

## Task 19: Local smoke test

- [ ] **Step 1: Build + run Debug on Simulator**

```bash
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

Launch the app. In Xcode console you should see repeated `[Amplitude]` log lines confirming events firing.

- [ ] **Step 2: Walk the happy path**

In the running app:
1. Sign up (or log in if already signed up).
2. Create a new ticket (plane → afterglow → horizontal → form → style → success).
3. Export to camera roll.
4. Create a memory and add the ticket.
5. Open Settings → toggle appearance, change icon.

- [ ] **Step 3: Verify events arrived in Amplitude**

Log into Amplitude dashboard → **User Lookup** → search by the Supabase UUID you just signed up with (you can grab it via the `listenForAuthChanges` log lines in the Xcode console). Within 60s you should see the full event stream tagged `environment=dev`.

- [ ] **Step 4: Verify Release tagging**

```bash
xcodebuild -scheme "Lumoria App" -configuration Release -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tail -5
```

Run the release build locally. Confirm subsequent events tag `environment=prod`.

---

# Phase 5 — Notion tracking plan

## Task 20: Extend the Events DB schema

**Tool:** Notion MCP (`notion-update-data-source`). Data source ID: `34610dea-1b05-8071-b23e-000b76646219`.

- [ ] **Step 1: Add columns via `notion-update-data-source`**

Run the MCP call with these statements (semicolon-separated):

```
ADD COLUMN "Status" SELECT('Planned':gray, 'Implemented':green, 'Deprecated':red, 'Backlog':yellow);
ADD COLUMN "Category" MULTI_SELECT('Auth':blue, 'Onboarding':purple, 'Deep Link':blue, 'Ticket Funnel':orange, 'Ticket Management':orange, 'Memories':pink, 'Export & Share':yellow, 'Invites & Referral':green, 'Profile':gray, 'Settings':gray, 'Notifications':red, 'System':default, 'Error':red);
ADD COLUMN "AARRR Stage" SELECT('Acquisition':blue, 'Activation':green, 'Retention':yellow, 'Referral':pink, 'Revenue':purple, 'System':gray);
ADD COLUMN "Priority" SELECT('P0':red, 'P1':yellow, 'P2':gray);
ADD COLUMN "Description" RICH_TEXT;
ADD COLUMN "Trigger" SELECT('User action':blue, 'System':gray, 'Error':red);
ADD COLUMN "Surface" RICH_TEXT;
ADD COLUMN "Owner" PEOPLE;
ADD COLUMN "Impl Notes" RICH_TEXT;
ADD COLUMN "Triggered By" RELATION('34610dea-1b05-8071-b23e-000b76646219', DUAL 'Triggers' 'triggers');
```

The self-relation `Triggered By` ↔ `Triggers` captures funnel chains.

## Task 21: Create Event Properties DB

**Tool:** Notion MCP (`notion-create-database`). Parent: same page as Events DB. Parent page ID: `34610dea1b0580b8b7c9ddaf82613e67`.

- [ ] **Step 1: Create Event Properties DB**

Use `notion-create-database` with:
- Title: `Event Properties`
- Properties:
  - `Name` (title)
  - `Type` SELECT: `string`, `int`, `bool`, `enum`, `timestamp`
  - `Enum Values` RICH_TEXT
  - `Description` RICH_TEXT
  - `Example` RICH_TEXT
  - `PII` CHECKBOX
  - `Required` SELECT: `Required`, `Optional`
  - `Used In` RELATION → Events DB (`34610dea-1b05-8071-b23e-000b76646219`)

- [ ] **Step 2: Back-link relation on Events DB**

Use `notion-update-data-source` on the Events DB to add `Properties` column as a dual-synced relation to the Event Properties DB (mirrors `Used In`). The create-database call in Step 1, if issued with `DUAL`, will auto-create this.

## Task 22: Create User Properties DB

**Tool:** Notion MCP (`notion-create-database`). Parent: same.

- [ ] **Step 1: Create User Properties DB**

Title: `User Properties`
Properties:
- `Name` (title)
- `Type` SELECT: `string`, `int`, `bool`, `enum`, `timestamp`
- `Description` RICH_TEXT
- `Example` RICH_TEXT
- `Updated By` RELATION → Events DB (dual sync)

## Task 23: Populate Events DB — Acquisition + Activation

**Tool:** Notion MCP (`notion-create-pages`). Parent: Events DB data source.

- [ ] **Step 1: Create all 14 Acquisition rows**

For each event listed in the spec §6.1, call `notion-create-pages` with:
- `Name`: the event title (e.g. "Session Started")
- `Status`: "Planned" → flip to "Implemented" after Task 19 passes
- `Category`: matching multi-select values (e.g. `["Auth", "Onboarding"]` for signup events, `["Deep Link"]` for link events)
- `AARRR Stage`: "Acquisition"
- `Priority`: P0 for Session Started, App Opened, Login Succeeded, Signup Submitted, Signup Verification Sent; P1 otherwise
- `Description`: one-sentence "fires when ..." + "we care because ..."
- `Trigger`: "User action" or "System"
- `Surface`: relevant view file (e.g. `LogInView.swift`)
- `Impl Notes`: file + symbol path, e.g. `Lumoria App/views/authentication/AuthManager.swift › listenForAuthChanges .signedIn`

Batch in groups of 10 pages per call.

- [ ] **Step 2: Create all 17 Activation rows**

Same pattern, one row per event in spec §6.2. Priority P0 for `New Ticket Started`, `Ticket Form Submitted`, `Ticket Created`, `First Ticket Created`, `Memory Created`, `First Memory Created`.

## Task 24: Populate Events DB — Retention + Referral + Revenue + System + Error

- [ ] **Step 1: 22 Retention rows** (spec §6.3)
- [ ] **Step 2: 8 Referral rows** (spec §6.4)
- [ ] **Step 3: 6 Revenue rows** (spec §6.5) — all with `Status: Backlog`
- [ ] **Step 4: 8 System rows** (spec §6.6)
- [ ] **Step 5: 3 Error rows** (spec §6.7)

## Task 25: Populate Event Properties + User Properties DBs

- [ ] **Step 1: Add one row per property**

For each typed property (`ticket_category`, `ticket_template`, `user_id`, etc.) and each enum value you use, create a row in the **Event Properties DB** with Type, Enum Values, Description, Example, PII flag. Reference spec §5 and §8.

- [ ] **Step 2: Add one row per user trait**

For each user property listed in spec §4.2, create a row in the **User Properties DB**. Link `Updated By` to the Events DB rows that trigger the update.

## Task 26: Link funnel chains

- [ ] **Step 1: Populate `Triggered By` self-relations**

For each row in the Events DB, use `notion-update-page` to set the `Triggered By` relation to its predecessor event(s). Reference spec §7 for the four funnel definitions (Signup, Ticket Creation, Referral, First-Time Activation).

## Task 27: Flip Status to Implemented

- [ ] **Step 1: After Task 19 passes**

Use `notion-update-page` to set `Status = Implemented` on every event that ships in this PR. Revenue events remain `Backlog`.

---

## Self-review against spec

- **§1 Goals** — covered: AARRR catalog in Tasks 20-26, Notion schema in Tasks 20-22, secure SDK in Tasks 1-9.
- **§2 Non-goals** — all explicitly not-implemented (Revenue stubs, no consent sheet, no server-side). Tasks 6+24 scaffold Revenue events with status Backlog.
- **§3 Architecture** — Tasks 4-9 implement every piece (type-safe events, protocol wrapper, xcconfig, autocapture sessions-only, opt-out hook).
- **§4 Identity** — Task 10 sets user id on login, resets on logout, sends email_domain as user property. User property updates wired across Tasks 11, 14, 15, 16, 17.
- **§5 PII rules** — Task 4 implements hashing; Task 6 never includes raw tokens/emails; Task 11 uses `field_fill_count` not form values; memory/ticket/invite UUIDs hashed in Tasks 12, 14, 15.
- **§6 Event catalog** — All 78 events have enum cases in Task 6 and Notion rows in Tasks 23-24.
- **§7 Funnel relations** — Task 26.
- **§8 Enum vocabulary** — Task 5.
- **§9 Notion structure** — Tasks 20-22.
- **§10 Implementation order** — matches Phases 1-5.
- **§11 Testing** — Tasks 4 + 6 have swift-testing suites; Noop backend in Task 7 is used by previews by default.

No gaps.

---

## Execution choice

Plan complete and saved to `docs/superpowers/plans/2026-04-18-amplitude-tracking.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
