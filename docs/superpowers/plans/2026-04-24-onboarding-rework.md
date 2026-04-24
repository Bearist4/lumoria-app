# Onboarding V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing TipKit-based onboarding with a 12-step server-backed tutorial driven by a custom dimming overlay with a pass-through cutout around one target element per step, persisted via a new `public.profiles` Supabase table.

**Architecture:** A single `OnboardingCoordinator` (`@Observable @MainActor`) hydrates from `public.profiles` on auth. Each host view applies an `.onboardingOverlay(step:...)` modifier that only renders when `coordinator.currentStep == step`. Target elements mark their bounds with `.onboardingAnchor("…")`. The overlay dims outside the anchor rect via a `.destinationOut`-masked `Rectangle`, applies `.allowsHitTesting(false)` over the cutout so the underlying control receives taps natively, and auto-dismisses when `currentStep` changes. Analytics fire per step via `Analytics.track(.onboardingStepCompleted(step: .<case>))`.

**Tech Stack:** Swift 5.9+, SwiftUI, iOS 26 target. Supabase swift client. Swift Testing for unit tests. Amplitude via existing `Analytics` facade. XcodeGen / direct pbxproj edits for new assets.

**Spec:** `docs/superpowers/specs/2026-04-24-onboarding-rework-design.md`.

---

## File structure

**New:**
```
supabase/migrations/20260424000000_profiles.sql
Lumoria App/services/onboarding/
  └── ProfileService.swift
Lumoria App/views/onboarding/
  ├── OnboardingCoordinator.swift         # REWRITTEN
  ├── OnboardingStep.swift
  ├── OnboardingAnchorKey.swift
  ├── OnboardingTipCard.swift
  ├── OnboardingOverlay.swift
  ├── WelcomeSheetView.swift              # REWRITTEN
  ├── ResumeSheetView.swift
  └── OnboardingEndSheetView.swift
Lumoria App/Assets.xcassets/onboarding/
  ├── cover.imageset/{Contents.json,cover.png(placeholder)}
  └── end_cover.imageset/{Contents.json,end_cover.png(placeholder)}
```

**Deleted:** `Lumoria App/views/onboarding/OnboardingTips.swift`

**Modified:**
- `Lumoria App/Lumoria_AppApp.swift`
- `Lumoria App/ContentView.swift`
- `Lumoria App/views/collections/CollectionsView.swift`
- `Lumoria App/views/collections/CollectionsStore.swift`
- `Lumoria App/views/collections/CollectionDetailView.swift`
- `Lumoria App/views/tickets/new/CategoryStep.swift`
- `Lumoria App/views/tickets/new/NewTicketFunnel.swift` (view file — funnel presenter)
- `Lumoria App/views/tickets/new/FormStep.swift`
- `Lumoria App/views/tickets/new/UndergroundFormStep.swift`
- `Lumoria App/views/tickets/new/TemplateDetailsSheet.swift` (template style picker)
- `Lumoria App/views/tickets/new/SuccessStep.swift`
- `Lumoria App/views/tickets/new/ExportSheet.swift`
- `Lumoria App/views/tickets/new/AddToMemorySheet.swift`
- `Lumoria App/views/settings/SettingsView.swift`
- `Lumoria App/services/analytics/AnalyticsEvent.swift`
- `Lumoria App/services/analytics/AnalyticsProperty.swift`
- `Lumoria App/Localizable.xcstrings`
- `Lumoria AppTests/OnboardingCoordinatorTests.swift`
- `Lumoria AppTests/AnalyticsEventTests.swift`

---

## Task 1: Supabase profiles migration

**Files:**
- Create: `supabase/migrations/20260424000000_profiles.sql`

- [ ] **Step 1: Write the migration**

```sql
-- 20260424000000_profiles.sql
-- Per-user onboarding state. One row per auth.users row, created via trigger
-- at signup, deleted on cascade. RLS: owner read/update only. Insert and
-- delete are handled by triggers / cascade so clients have no policies for
-- them.

create extension if not exists moddatetime;

create table public.profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    show_onboarding boolean not null default true,
    onboarding_step text not null default 'welcome'
        check (onboarding_step in (
            'welcome','createMemory','memoryCreated','enterMemory',
            'pickCategory','pickTemplate','fillInfo','pickStyle',
            'allDone','exportOrAddMemory','endCover','done'
        )),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_self_read"
    on public.profiles for select
    using (auth.uid() = user_id);

create policy "profiles_self_update"
    on public.profiles for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create trigger profiles_updated_at
    before update on public.profiles
    for each row execute function moddatetime(updated_at);

-- Auto-create a profiles row on signup. security definer so the trigger can
-- insert even though the new user's JWT is not yet established in-session.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
    insert into public.profiles (user_id) values (new.id);
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- Backfill existing users: treat anyone who pre-dates this migration as
-- having already completed onboarding, so the new tutorial doesn't interrupt
-- testers or beta users.
insert into public.profiles (user_id, show_onboarding, onboarding_step)
    select id, false, 'done' from auth.users
    on conflict (user_id) do nothing;
```

- [ ] **Step 2: Apply via Supabase MCP**

Use the `mcp__supabase__apply_migration` tool (project id `vhozwnykphqujsiuwesi`) with name `profiles` and the full SQL above. Expected: `success` response.

- [ ] **Step 3: Verify migration state**

Run `mcp__supabase__list_migrations` (project id `vhozwnykphqujsiuwesi`).
Expected: migration `profiles` appears with version `20260424000000`.

- [ ] **Step 4: Verify table + policies exist**

Run `mcp__supabase__execute_sql`:
```sql
select count(*) from public.profiles;
select policyname from pg_policies where tablename='profiles';
```
Expected: integer row count matches `select count(*) from auth.users`; policies include `profiles_self_read` and `profiles_self_update`.

- [ ] **Step 5: Commit**

```bash
git add "supabase/migrations/20260424000000_profiles.sql"
git commit -m "feat(onboarding): add profiles table for tutorial state

Per-user show_onboarding flag + onboarding_step checkpoint, RLS owner
policies, signup trigger, backfill existing users as completed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: OnboardingStep enum + analytics prop

**Files:**
- Create: `Lumoria App/views/onboarding/OnboardingStep.swift`
- Modify: `Lumoria App/services/analytics/AnalyticsProperty.swift:128-130`

- [ ] **Step 1: Write the enum**

Create `Lumoria App/views/onboarding/OnboardingStep.swift`:

```swift
//
//  OnboardingStep.swift
//  Lumoria App
//
//  The linear state machine for the first-run tutorial. Stored as a text
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
```

- [ ] **Step 2: Replace the old OnboardingStepProp**

Open `Lumoria App/services/analytics/AnalyticsProperty.swift` and replace lines 128–130:

```swift
enum OnboardingStepProp: String, CaseIterable {
    case welcome
    case createMemory   = "create_memory"
    case memoryCreated  = "memory_created"
    case enterMemory    = "enter_memory"
    case pickCategory   = "pick_category"
    case pickTemplate   = "pick_template"
    case fillInfo       = "fill_info"
    case pickStyle      = "pick_style"
    case allDone        = "all_done"
    case exportOrAddMemory = "export_or_add_memory"
    case endCover       = "end_cover"
    case done
}
```

- [ ] **Step 3: Verify old step-prop callers compile**

Build the project (Xcode or `xcodebuild`). The old `OnboardingStepProp` had `welcome, memory, ticket, export` cases. `memory`/`ticket`/`export` are no longer valid. Expected: compiler errors in `OnboardingCoordinator.swift` and `AnalyticsEventTests.swift`. These will be fixed in Tasks 4 and 5.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/onboarding/OnboardingStep.swift" \
        "Lumoria App/services/analytics/AnalyticsProperty.swift"
git commit -m "feat(onboarding): add OnboardingStep enum + expand step prop

Mirrors the 12-case state machine stored in profiles.onboarding_step.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Expand AnalyticsEvent for onboarding

**Files:**
- Modify: `Lumoria App/services/analytics/AnalyticsEvent.swift:128-133, 241-246, 486-493`

- [ ] **Step 1: Add new onboarding event cases**

Replace the `// MARK: — Onboarding` block at lines 127–133 with:

```swift
    // MARK: — Onboarding

    case onboardingShown                                   // welcome sheet appeared
    case onboardingStarted                                 // welcome "Start tutorial" tap
    case onboardingResumed                                 // resume sheet "Continue" tap
    case onboardingDeclinedResume                          // resume sheet X tap
    case onboardingStepCompleted(step: OnboardingStepProp)
    case onboardingLeft(atStep: OnboardingStepProp)        // welcome X, tip X confirmed, or resume X
    case onboardingCompleted(durationSeconds: Int)         // end sheet CTA or X
    case onboardingReplayed                                // Settings replay row
```

- [ ] **Step 2: Add new name mappings**

Replace the `// Onboarding` block inside `name` at lines 240–246 with:

```swift
        // Onboarding
        case .onboardingShown:          return "Onboarding Shown"
        case .onboardingStarted:        return "Onboarding Started"
        case .onboardingResumed:        return "Onboarding Resumed"
        case .onboardingDeclinedResume: return "Onboarding Declined Resume"
        case .onboardingStepCompleted:  return "Onboarding Step Completed"
        case .onboardingLeft:           return "Onboarding Left"
        case .onboardingCompleted:      return "Onboarding Completed"
        case .onboardingReplayed:       return "Onboarding Replayed"
```

- [ ] **Step 3: Add new property mappings**

Replace the `// Onboarding` block inside `properties` at lines 485–493 with:

```swift
        // Onboarding
        case .onboardingShown,
             .onboardingStarted,
             .onboardingResumed,
             .onboardingDeclinedResume,
             .onboardingReplayed:
            return [:]
        case .onboardingStepCompleted(let step):
            return ["step": step.rawValue]
        case .onboardingLeft(let step):
            return ["at_step": step.rawValue]
        case .onboardingCompleted(let seconds):
            return ["duration_seconds": seconds]
```

- [ ] **Step 4: Build + verify compile**

Run `xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet` (or build in Xcode).
Expected: remaining errors are only in `OnboardingCoordinator.swift` (old `.onboardingSkipped` / `.onboardingStepCompleted(step: .memory)` call sites). Those will be fixed in Task 5.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/services/analytics/AnalyticsEvent.swift"
git commit -m "feat(onboarding): add resumed/declined/left events

Replace the single Skipped event with a richer set covering resume
sheet interaction and left-at-step tracking.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: ProfileService (Supabase client wrapper)

**Files:**
- Create: `Lumoria App/services/onboarding/ProfileService.swift`

- [ ] **Step 1: Write the service**

```swift
//
//  ProfileService.swift
//  Lumoria App
//
//  Supabase CRUD wrapper for the public.profiles row that backs onboarding
//  state. See supabase/migrations/20260424000000_profiles.sql for schema.
//

import Foundation
import Supabase

struct Profile: Codable, Equatable, Sendable {
    let userId: UUID
    var showOnboarding: Bool
    var onboardingStep: OnboardingStep

    enum CodingKeys: String, CodingKey {
        case userId         = "user_id"
        case showOnboarding = "show_onboarding"
        case onboardingStep = "onboarding_step"
    }
}

/// Error cases surfaced to the coordinator. `.notFound` means the row
/// doesn't exist yet (trigger race); caller can retry or fall back to
/// defaults.
enum ProfileServiceError: Error {
    case notAuthenticated
    case notFound
    case underlying(Error)
}

protocol ProfileServicing: AnyObject, Sendable {
    func fetch() async throws -> Profile
    func setStep(_ step: OnboardingStep) async throws
    func setShowOnboarding(_ value: Bool) async throws
    func replay() async throws
}

final class ProfileService: ProfileServicing, @unchecked Sendable {

    func fetch() async throws -> Profile {
        guard let uid = supabase.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }
        do {
            let row: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("user_id", value: uid.uuidString)
                .single()
                .execute()
                .value
            return row
        } catch {
            // postgREST returns HTTP 406 / code PGRST116 when `.single()`
            // matches zero rows. Map to .notFound so the coordinator can
            // retry or fall back.
            let ns = error as NSError
            if ns.localizedDescription.contains("PGRST116") {
                throw ProfileServiceError.notFound
            }
            throw ProfileServiceError.underlying(error)
        }
    }

    func setStep(_ step: OnboardingStep) async throws {
        guard let uid = supabase.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }
        try await supabase
            .from("profiles")
            .update(["onboarding_step": step.rawValue])
            .eq("user_id", value: uid.uuidString)
            .execute()
    }

    func setShowOnboarding(_ value: Bool) async throws {
        guard let uid = supabase.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }
        try await supabase
            .from("profiles")
            .update(["show_onboarding": value])
            .eq("user_id", value: uid.uuidString)
            .execute()
    }

    func replay() async throws {
        guard let uid = supabase.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }
        try await supabase
            .from("profiles")
            .update([
                "show_onboarding": "true",
                "onboarding_step": OnboardingStep.welcome.rawValue,
            ])
            .eq("user_id", value: uid.uuidString)
            .execute()
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

Open `Lumoria App.xcodeproj` in Xcode; right-click `Lumoria App/services/` folder → New Group → `onboarding` (if not already present via Task 1/2 — it isn't). Drag `ProfileService.swift` into the group. Ensure membership in the `Lumoria App` target.

Alternatively, if working headless: edit `Lumoria App.xcodeproj/project.pbxproj` to add the new file reference, build phase entry, and group membership. After editing, verify with:

```bash
xcodebuild -list -project "Lumoria App.xcodeproj"
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: compiles without errors related to `ProfileService` (other errors from old coordinator remain).

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/services/onboarding/ProfileService.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(onboarding): add ProfileService wrapper for profiles table

Fetch / setStep / setShowOnboarding / replay with PGRST116 → notFound.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: OnboardingCoordinator rewrite

**Files:**
- Modify: `Lumoria App/views/onboarding/OnboardingCoordinator.swift` (full rewrite)
- Modify: `Lumoria AppTests/OnboardingCoordinatorTests.swift` (full rewrite)

- [ ] **Step 1: Write failing tests first**

Replace contents of `Lumoria AppTests/OnboardingCoordinatorTests.swift`:

```swift
//
//  OnboardingCoordinatorTests.swift
//  Lumoria AppTests
//

import Testing
@testable import Lumoria_App
import Foundation

// Mock profile service so tests don't touch Supabase.
final class MockProfileService: ProfileServicing, @unchecked Sendable {
    var storedProfile: Profile?
    var fetchError: Error?
    var writtenSteps: [OnboardingStep] = []
    var writtenShowFlags: [Bool] = []
    var replayCalls = 0

    init(profile: Profile? = nil) { self.storedProfile = profile }

    func fetch() async throws -> Profile {
        if let err = fetchError { throw err }
        guard let p = storedProfile else { throw ProfileServiceError.notFound }
        return p
    }
    func setStep(_ step: OnboardingStep) async throws {
        writtenSteps.append(step)
        storedProfile?.onboardingStep = step
    }
    func setShowOnboarding(_ value: Bool) async throws {
        writtenShowFlags.append(value)
        storedProfile?.showOnboarding = value
    }
    func replay() async throws {
        replayCalls += 1
        if var p = storedProfile {
            p.showOnboarding = true
            p.onboardingStep = .welcome
            storedProfile = p
        }
    }
}

@MainActor
struct OnboardingCoordinatorTests {

    private func makeProfile(show: Bool, step: OnboardingStep) -> Profile {
        Profile(userId: UUID(), showOnboarding: show, onboardingStep: step)
    }

    @Test
    func loadOnAuth_hydratesState() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .welcome))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        #expect(coord.showOnboarding == true)
        #expect(coord.currentStep == .welcome)
    }

    @Test
    func maybePresentEntry_showsWelcomeAtStepWelcome() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .welcome))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        coord.maybePresentEntry()
        #expect(coord.showWelcome == true)
        #expect(coord.showResume == false)
    }

    @Test
    func maybePresentEntry_showsResumeWhenStepBeyondWelcome() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .pickCategory))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        coord.maybePresentEntry()
        #expect(coord.showResume == true)
        #expect(coord.showWelcome == false)
    }

    @Test
    func maybePresentEntry_noSheetWhenOnboardingOff() async throws {
        let service = MockProfileService(profile: makeProfile(show: false, step: .done))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        coord.maybePresentEntry()
        #expect(coord.showWelcome == false)
        #expect(coord.showResume == false)
    }

    @Test
    func startTutorial_advancesToCreateMemory() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .welcome))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.startTutorial()
        #expect(coord.currentStep == .createMemory)
        #expect(coord.showWelcome == false)
        #expect(service.writtenSteps == [.createMemory])
    }

    @Test
    func dismissWelcomeSilently_turnsOffFlag() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .welcome))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.dismissWelcomeSilently()
        #expect(coord.showOnboarding == false)
        #expect(coord.currentStep == .done)
        #expect(service.writtenShowFlags == [false])
        #expect(service.writtenSteps == [.done])
    }

    @Test
    func advance_fromMatchingStepTransitions() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .createMemory))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.advance(from: .createMemory)
        #expect(coord.currentStep == .memoryCreated)
    }

    @Test
    func advance_fromMismatchedStepIsNoOp() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .pickCategory))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.advance(from: .createMemory)
        #expect(coord.currentStep == .pickCategory)
        #expect(service.writtenSteps.isEmpty)
    }

    @Test
    func advance_fromFillInfoSkipsPickStyleWhenNoVariants() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .fillInfo))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        coord.pendingStyleStep = false
        await coord.advance(from: .fillInfo)
        #expect(coord.currentStep == .allDone)
    }

    @Test
    func advance_fromFillInfoIncludesPickStyleWhenVariantsExist() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .fillInfo))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        coord.pendingStyleStep = true
        await coord.advance(from: .fillInfo)
        #expect(coord.currentStep == .pickStyle)
    }

    @Test
    func chose_recordsVariantAndAdvances() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .allDone))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.chose(.export)
        #expect(coord.currentStep == .exportOrAddMemory)
        #expect(coord.exportOrAddChoice == .export)
    }

    @Test
    func confirmLeaveTutorial_setsFlagFalseAndStepDone() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .pickCategory))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.confirmLeaveTutorial()
        #expect(coord.showOnboarding == false)
        #expect(coord.currentStep == .done)
    }

    @Test
    func resetForReplay_rewinds() async throws {
        let service = MockProfileService(profile: makeProfile(show: false, step: .done))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.resetForReplay()
        #expect(coord.showOnboarding == true)
        #expect(coord.currentStep == .welcome)
        #expect(service.replayCalls == 1)
    }

    @Test
    func finishAtEndCover_completes() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .endCover))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.finishAtEndCover()
        #expect(coord.showOnboarding == false)
        #expect(coord.currentStep == .done)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
Expected: all 13 tests FAIL (or don't compile) — signatures don't exist yet.

- [ ] **Step 3: Rewrite OnboardingCoordinator to pass tests**

Replace contents of `Lumoria App/views/onboarding/OnboardingCoordinator.swift`:

```swift
//
//  OnboardingCoordinator.swift
//  Lumoria App
//
//  State machine for the first-run tutorial. Hydrates from public.profiles
//  via ProfileService on auth, exposes @Published UI flags and a
//  currentStep enum that host views match against via .onboardingOverlay(step:).
//  All writes are optimistic locally, then fire-and-forget to Supabase.
//

import Combine
import Foundation
import SwiftUI

enum ExportVariant: String, Sendable {
    case export
    case addToMemory
}

@MainActor
final class OnboardingCoordinator: ObservableObject {

    // MARK: - Persisted (server-backed)

    @Published private(set) var showOnboarding: Bool = false
    @Published private(set) var currentStep: OnboardingStep = .done

    // MARK: - Transient UI state

    @Published var showWelcome: Bool = false
    @Published var showResume: Bool = false
    @Published var showEndCover: Bool = false
    @Published var showLeaveAlert: Bool = false
    @Published var exportOrAddChoice: ExportVariant?
    /// Set at .pickTemplate advance — whether the chosen template has style
    /// variants. Consulted at .fillInfo advance to decide next step.
    @Published var pendingStyleStep: Bool = false

    // MARK: - Analytics timing

    private var startedAt: Date?

    // MARK: - Deps

    private let service: ProfileServicing
    private var hasHydrated: Bool = false

    init(service: ProfileServicing = ProfileService()) {
        self.service = service
    }

    // MARK: - Hydration

    /// Called by Lumoria_AppApp when auth.isAuthenticated flips true.
    func loadOnAuth() async {
        do {
            let p = try await service.fetch()
            self.showOnboarding = p.showOnboarding
            self.currentStep    = p.onboardingStep
            self.hasHydrated    = true
        } catch ProfileServiceError.notFound {
            // Trigger may not have fired yet. Default to a fresh tutorial.
            self.showOnboarding = true
            self.currentStep    = .welcome
            self.hasHydrated    = true
        } catch {
            print("[OnboardingCoordinator] loadOnAuth failed:", error)
            self.showOnboarding = false
            self.currentStep    = .done
        }
    }

    // MARK: - Entry presentation

    /// Called by ContentView 3 seconds after the Memories tab is first
    /// active. Decides welcome vs resume vs no-op.
    func maybePresentEntry() {
        guard showOnboarding else { return }
        switch currentStep {
        case .welcome:
            showWelcome = true
            Analytics.track(.onboardingShown)
        case .done:
            break
        default:
            showResume = true
        }
    }

    // MARK: - User actions

    func startTutorial() async {
        startedAt = Date()
        showWelcome = false
        Analytics.track(.onboardingStarted)
        await write(step: .createMemory)
    }

    func dismissWelcomeSilently() async {
        showWelcome = false
        Analytics.track(.onboardingLeft(atStep: .welcome))
        await writeShow(false)
        await write(step: .done)
    }

    func resume() async {
        showResume = false
        startedAt = Date()
        Analytics.track(.onboardingResumed)
        // Current step already reflects where to pick up.
    }

    func declineResume() async {
        showResume = false
        Analytics.track(.onboardingDeclinedResume)
        Analytics.track(.onboardingLeft(atStep: prop(for: currentStep)))
        await writeShow(false)
        await write(step: .done)
    }

    func confirmLeaveTutorial() async {
        let left = currentStep
        showLeaveAlert = false
        Analytics.track(.onboardingLeft(atStep: prop(for: left)))
        await writeShow(false)
        await write(step: .done)
    }

    /// Linear advance. Caller provides the step they expect to be on so a
    /// stale or duplicate call from a re-entered view is a no-op.
    func advance(from expected: OnboardingStep) async {
        guard currentStep == expected else { return }
        Analytics.track(.onboardingStepCompleted(step: prop(for: expected)))

        let next: OnboardingStep
        switch expected {
        case .welcome:            next = .createMemory
        case .createMemory:       next = .memoryCreated
        case .memoryCreated:      next = .enterMemory
        case .enterMemory:        next = .pickCategory
        case .pickCategory:       next = .pickTemplate
        case .pickTemplate:       next = .fillInfo
        case .fillInfo:           next = pendingStyleStep ? .pickStyle : .allDone
        case .pickStyle:          next = .allDone
        case .allDone:            next = .exportOrAddMemory
        case .exportOrAddMemory:  next = .endCover
        case .endCover:           next = .done
        case .done:               return
        }
        await write(step: next)
    }

    /// Called by SuccessStep when the user picks Export or Add-to-memory.
    func chose(_ variant: ExportVariant) async {
        exportOrAddChoice = variant
        await advance(from: .allDone)
    }

    /// End sheet CTA or X — both finish the tutorial.
    func finishAtEndCover() async {
        showEndCover = false
        let duration = startedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
        Analytics.track(.onboardingCompleted(durationSeconds: duration))
        await writeShow(false)
        await write(step: .done)
    }

    // MARK: - Settings replay

    func resetForReplay() async {
        Analytics.track(.onboardingReplayed)
        do {
            try await service.replay()
            showOnboarding   = true
            currentStep      = .welcome
            exportOrAddChoice = nil
            pendingStyleStep = false
            startedAt        = nil
        } catch {
            print("[OnboardingCoordinator] replay failed:", error)
        }
    }

    // MARK: - Writers

    private func write(step: OnboardingStep) async {
        currentStep = step
        if step == .endCover {
            showEndCover = true
        }
        do {
            try await service.setStep(step)
        } catch {
            print("[OnboardingCoordinator] setStep failed:", error)
        }
    }

    private func writeShow(_ value: Bool) async {
        showOnboarding = value
        do {
            try await service.setShowOnboarding(value)
        } catch {
            print("[OnboardingCoordinator] setShowOnboarding failed:", error)
        }
    }

    private func prop(for step: OnboardingStep) -> OnboardingStepProp {
        switch step {
        case .welcome:            return .welcome
        case .createMemory:       return .createMemory
        case .memoryCreated:      return .memoryCreated
        case .enterMemory:        return .enterMemory
        case .pickCategory:       return .pickCategory
        case .pickTemplate:       return .pickTemplate
        case .fillInfo:           return .fillInfo
        case .pickStyle:          return .pickStyle
        case .allDone:            return .allDone
        case .exportOrAddMemory:  return .exportOrAddMemory
        case .endCover:           return .endCover
        case .done:               return .done
        }
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

```bash
xcodebuild test -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:"Lumoria AppTests/OnboardingCoordinatorTests"
```
Expected: all 13 tests pass.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/onboarding/OnboardingCoordinator.swift" \
        "Lumoria AppTests/OnboardingCoordinatorTests.swift"
git commit -m "feat(onboarding): rewrite coordinator on 12-step machine

Server-backed via ProfileService. advance(from:) gates on expected step
so re-entry is a no-op. fillInfo consults pendingStyleStep.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Anchor preference + OnboardingTipCard

**Files:**
- Create: `Lumoria App/views/onboarding/OnboardingAnchorKey.swift`
- Create: `Lumoria App/views/onboarding/OnboardingTipCard.swift`

- [ ] **Step 1: Write the anchor preference**

```swift
//
//  OnboardingAnchorKey.swift
//  Lumoria App
//
//  PreferenceKey that bubbles target-element bounds up to the overlay
//  modifier, which resolves them via GeometryReader into a CGRect for
//  positioning the cutout and tip card.
//

import SwiftUI

struct OnboardingAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    /// Registers this view's bounds under `id` so a sibling
    /// `.onboardingOverlay(...)` modifier can cut out around it.
    func onboardingAnchor(_ id: String) -> some View {
        anchorPreference(key: OnboardingAnchorKey.self,
                         value: .bounds) { [id: $0] }
    }
}
```

- [ ] **Step 2: Write the tip card view**

```swift
//
//  OnboardingTipCard.swift
//  Lumoria App
//
//  Blue tip card with title, body, and an X button. Visuals match the
//  Figma tip component (see spec §6). The X triggers the leave-tutorial
//  alert on the coordinator.
//

import SwiftUI

struct OnboardingTipCopy: Equatable {
    let title: LocalizedStringKey
    let body: LocalizedStringKey
    /// Optional SF Symbol / asset name shown next to the title.
    let leadingEmoji: String?

    init(title: LocalizedStringKey,
         body: LocalizedStringKey,
         leadingEmoji: String? = nil) {
        self.title = title
        self.body = body
        self.leadingEmoji = leadingEmoji
    }
}

struct OnboardingTipCard: View {
    let copy: OnboardingTipCopy
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let emoji = copy.leadingEmoji {
                    Text(emoji).font(.system(size: 20))
                }
                Text(copy.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Leave the tutorial"))
            }
            Text(copy.body)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 300, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.294, green: 0.349, blue: 0.933)) // #4B59EE
        )
        .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        OnboardingTipCard(
            copy: .init(
                title: "Create a memory",
                body: "Memories gather tickets into one place. Create one by tapping the + button.",
                leadingEmoji: nil
            ),
            onClose: {}
        )
        .padding()
    }
}
```

- [ ] **Step 3: Add both files to Xcode project**

Add `OnboardingAnchorKey.swift` and `OnboardingTipCard.swift` to the `Lumoria App/views/onboarding/` group with target membership `Lumoria App`.

- [ ] **Step 4: Build to verify**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/onboarding/OnboardingAnchorKey.swift" \
        "Lumoria App/views/onboarding/OnboardingTipCard.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(onboarding): tip card + anchor preference

Blue tip card matches Figma spec. anchorPreference bubbles target bounds
to the overlay modifier.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: OnboardingOverlay modifier (pass-through cutout)

**Files:**
- Create: `Lumoria App/views/onboarding/OnboardingOverlay.swift`

- [ ] **Step 1: Write the overlay modifier**

```swift
//
//  OnboardingOverlay.swift
//  Lumoria App
//
//  Dim-and-cutout modifier applied to any view that hosts an onboarding
//  step. Renders only when `coordinator.currentStep == step`. Dim layer
//  blocks taps; cutout region is pass-through; tap on the tip X opens the
//  leave-alert on the coordinator.
//

import SwiftUI

struct OnboardingOverlayModifier: ViewModifier {
    let step: OnboardingStep
    @ObservedObject var coordinator: OnboardingCoordinator
    let anchorID: String
    let tip: OnboardingTipCopy
    /// Called when the overlay actually dismisses because `currentStep`
    /// moved past this step. Host views don't usually need to do anything.
    var onDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(OnboardingAnchorKey.self) { anchors in
                if coordinator.currentStep == step,
                   let anchor = anchors[anchorID] {
                    GeometryReader { proxy in
                        overlay(rect: proxy[anchor], fullSize: proxy.size)
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .onChange(of: coordinator.currentStep) { _, newValue in
                if newValue != step { onDismiss?() }
            }
    }

    // MARK: - Overlay body

    private func overlay(rect targetRect: CGRect, fullSize: CGSize) -> some View {
        // Inset the target to add breathing room around the cutout.
        let padded = targetRect.insetBy(dx: -8, dy: -8)
        let cornerRadius: CGFloat = 18

        return ZStack {
            // Dim layer — full-screen rect minus the rounded target rect,
            // masked with destinationOut to punch a hole.
            Canvas { ctx, size in
                ctx.addFilter(.blur(radius: 0))
                var dim = Path()
                dim.addRect(CGRect(origin: .zero, size: size))
                ctx.fill(dim, with: .color(.black.opacity(0.45)))

                var hole = Path()
                hole.addRoundedRect(in: padded,
                                    cornerSize: CGSize(width: cornerRadius,
                                                       height: cornerRadius))
                ctx.blendMode = .destinationOut
                ctx.fill(hole, with: .color(.black))
            }
            .allowsHitTesting(false)  // never blocks pass-through to target

            // Solid "eater" that catches taps OUTSIDE the cutout so the user
            // can't interact with other parts of the screen. Layered under
            // the tip card; uses an exact path with the rounded hole as an
            // even-odd exclusion so taps inside the hole fall through.
            DimBlocker(
                fullSize: fullSize,
                hole: padded,
                cornerRadius: cornerRadius
            )

            // Tip card positioned below the target rect by default; above
            // if the target is in the bottom third of the screen.
            OnboardingTipCard(copy: tip) {
                coordinator.showLeaveAlert = true
            }
            .position(
                tipCenter(
                    fullSize: fullSize,
                    target: padded
                )
            )
            .allowsHitTesting(true)
        }
    }

    private func tipCenter(fullSize: CGSize, target: CGRect) -> CGPoint {
        let tipHeight: CGFloat = 110
        let tipWidth:  CGFloat = 300
        let spacing:   CGFloat = 16
        let belowY = target.maxY + spacing + tipHeight / 2
        let aboveY = target.minY - spacing - tipHeight / 2
        let preferBelow = belowY + tipHeight / 2 < fullSize.height
        let y = preferBelow ? belowY : max(tipHeight / 2 + 40, aboveY)
        // Clamp x so the card stays on-screen.
        let x = min(max(target.midX, 16 + tipWidth / 2),
                    fullSize.width - 16 - tipWidth / 2)
        return CGPoint(x: x, y: y)
    }
}

/// Fills the screen with a hit-testable rectangle that has the target
/// rounded rect cut out via even-odd fill rule. Taps inside the cutout
/// pass through to the underlying element; taps outside are consumed.
private struct DimBlocker: View {
    let fullSize: CGSize
    let hole: CGRect
    let cornerRadius: CGFloat

    var body: some View {
        HoleShape(hole: hole, cornerRadius: cornerRadius)
            .fill(Color.clear, style: FillStyle(eoFill: true, antialiased: true))
            .frame(width: fullSize.width, height: fullSize.height)
            .contentShape(HoleShape(hole: hole, cornerRadius: cornerRadius),
                          eoFill: true)
    }
}

private struct HoleShape: Shape {
    let hole: CGRect
    let cornerRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        p.addRoundedRect(in: hole,
                         cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return p
    }
}

extension View {
    /// Attach an onboarding overlay that activates when
    /// `coordinator.currentStep == step` and cuts around the view tagged
    /// with `.onboardingAnchor(anchorID)`.
    func onboardingOverlay(
        step: OnboardingStep,
        coordinator: OnboardingCoordinator,
        anchorID: String,
        tip: OnboardingTipCopy
    ) -> some View {
        modifier(OnboardingOverlayModifier(
            step: step,
            coordinator: coordinator,
            anchorID: anchorID,
            tip: tip
        ))
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

Add `OnboardingOverlay.swift` to the onboarding group.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/onboarding/OnboardingOverlay.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(onboarding): dim + pass-through cutout overlay modifier

Even-odd filled hole rect consumes taps outside the target and lets taps
inside the cutout fall through to the underlying control.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Asset placeholders (cover + end_cover)

**Files:**
- Create: `Lumoria App/Assets.xcassets/onboarding/cover.imageset/Contents.json`
- Create: `Lumoria App/Assets.xcassets/onboarding/cover.imageset/cover.png` (1px placeholder)
- Create: `Lumoria App/Assets.xcassets/onboarding/end_cover.imageset/Contents.json`
- Create: `Lumoria App/Assets.xcassets/onboarding/end_cover.imageset/end_cover.png` (1px placeholder)

- [ ] **Step 1: Create cover imageset**

Create `Lumoria App/Assets.xcassets/onboarding/cover.imageset/Contents.json`:

```json
{
  "images": [
    { "idiom": "universal", "filename": "cover.png", "scale": "1x" },
    { "idiom": "universal", "scale": "2x" },
    { "idiom": "universal", "scale": "3x" }
  ],
  "info": { "version": 1, "author": "xcode" }
}
```

Generate a 1×1 placeholder PNG:

```bash
mkdir -p "Lumoria App/Assets.xcassets/onboarding/cover.imageset"
# Create a 1x1 lavender PNG. Real art supplied by design later.
python3 -c "
import struct, zlib, sys
def chunk(t,d):
    return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
sig=b'\\x89PNG\\r\\n\\x1a\\n'
ihdr=struct.pack('>IIBBBBB',1,1,8,2,0,0,0)
idat=zlib.compress(b'\\x00\\xe6\\xe6\\xfb')
png=sig+chunk(b'IHDR',ihdr)+chunk(b'IDAT',idat)+chunk(b'IEND',b'')
sys.stdout.buffer.write(png)
" > "Lumoria App/Assets.xcassets/onboarding/cover.imageset/cover.png"
```

- [ ] **Step 2: Create end_cover imageset**

Create `Lumoria App/Assets.xcassets/onboarding/end_cover.imageset/Contents.json`:

```json
{
  "images": [
    { "idiom": "universal", "filename": "end_cover.png", "scale": "1x" },
    { "idiom": "universal", "scale": "2x" },
    { "idiom": "universal", "scale": "3x" }
  ],
  "info": { "version": 1, "author": "xcode" }
}
```

```bash
mkdir -p "Lumoria App/Assets.xcassets/onboarding/end_cover.imageset"
python3 -c "
import struct, zlib, sys
def chunk(t,d):
    return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
sig=b'\\x89PNG\\r\\n\\x1a\\n'
ihdr=struct.pack('>IIBBBBB',1,1,8,2,0,0,0)
idat=zlib.compress(b'\\x00\\xfa\\xfa\\xfa')
png=sig+chunk(b'IHDR',ihdr)+chunk(b'IDAT',idat)+chunk(b'IEND',b'')
sys.stdout.buffer.write(png)
" > "Lumoria App/Assets.xcassets/onboarding/end_cover.imageset/end_cover.png"
```

- [ ] **Step 3: Verify both imagesets exist**

```bash
ls "Lumoria App/Assets.xcassets/onboarding/"
```
Expected output: `cover.imageset end_cover.imageset`.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/Assets.xcassets/onboarding/"
git commit -m "chore(onboarding): placeholder cover + end_cover imagesets

Real art will be supplied by design. 1x1 PNGs keep the bundle valid.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Welcome / Resume / End sheet views

**Files:**
- Modify: `Lumoria App/views/onboarding/WelcomeSheetView.swift` (rewrite)
- Create: `Lumoria App/views/onboarding/ResumeSheetView.swift`
- Create: `Lumoria App/views/onboarding/OnboardingEndSheetView.swift`

- [ ] **Step 1: Rewrite WelcomeSheetView**

Replace the full content of `Lumoria App/views/onboarding/WelcomeSheetView.swift`:

```swift
//
//  WelcomeSheetView.swift
//  Lumoria App
//
//  First-run tutorial welcome. Bottom-sheet style with a hero cover image,
//  a headline, a body, and Start / X actions. See Figma node 1902-103368.
//

import SwiftUI

struct WelcomeSheetView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image("onboarding/cover")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .clipped()
                    .accessibilityHidden(true)

                Button {
                    Task { await coordinator.dismissWelcomeSilently() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.9), in: Circle())
                }
                .padding(16)
                .accessibilityLabel(Text("Close"))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to Lumoria!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.Text.primary)

                Text("Memories gather tickets into one place — a trip, a season, a night out. Whatever you want to hold onto.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Button {
                Task { await coordinator.startTutorial() }
            } label: {
                Text("Start tutorial")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.Text.primary)
                    .foregroundStyle(Color.Background.default)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.Background.default)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
}
```

- [ ] **Step 2: Create ResumeSheetView**

```swift
//
//  ResumeSheetView.swift
//  Lumoria App
//
//  Presented on cold launch when show_onboarding=true and
//  onboarding_step != welcome. Offers the user a choice: continue the
//  tutorial from where they left off, or leave it.
//

import SwiftUI

struct ResumeSheetView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image("onboarding/cover")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .clipped()
                    .accessibilityHidden(true)

                Button {
                    Task { await coordinator.declineResume() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.9), in: Circle())
                }
                .padding(16)
                .accessibilityLabel(Text("Leave the tutorial"))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome back")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.Text.primary)

                Text("Want to continue where you left off in the tutorial?")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Button {
                Task { await coordinator.resume() }
            } label: {
                Text("Continue tutorial")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.Text.primary)
                    .foregroundStyle(Color.Background.default)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.Background.default)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
}
```

- [ ] **Step 3: Create OnboardingEndSheetView**

```swift
//
//  OnboardingEndSheetView.swift
//  Lumoria App
//
//  Presented on the Memories tab after the user finishes the tutorial
//  (export or add-to-memory done). Celebratory wrap-up card matching
//  Figma node 1905-113490.
//

import SwiftUI

struct OnboardingEndSheetView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image("onboarding/end_cover")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .accessibilityHidden(true)

                Button {
                    Task { await coordinator.finishAtEndCover() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.9), in: Circle())
                }
                .padding(16)
                .accessibilityLabel(Text("Close"))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("All done!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.Text.primary)

                Text("You can now enjoy Lumoria and create beautiful tickets for every moments you'd like to remember. We just covered the basics of Lumoria. There's so many more features waiting to be discovered.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Button {
                Task { await coordinator.finishAtEndCover() }
            } label: {
                Text("Start using Lumoria")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.Text.primary)
                    .foregroundStyle(Color.Background.default)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.Background.default)
        .presentationDetents([.height(480)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
}
```

- [ ] **Step 4: Add the two new files to the Xcode project**

Add `ResumeSheetView.swift` and `OnboardingEndSheetView.swift` to the onboarding group.

- [ ] **Step 5: Build to verify**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: success.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/views/onboarding/WelcomeSheetView.swift" \
        "Lumoria App/views/onboarding/ResumeSheetView.swift" \
        "Lumoria App/views/onboarding/OnboardingEndSheetView.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(onboarding): welcome/resume/end bottom sheets

Matches Figma covers. Welcome X silently ends tutorial; resume X declines;
end sheet CTA and X both finish.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Delete OnboardingTips + bootstrap rewiring

**Files:**
- Delete: `Lumoria App/views/onboarding/OnboardingTips.swift`
- Modify: `Lumoria App/Lumoria_AppApp.swift`
- Modify: `Lumoria App/ContentView.swift`

- [ ] **Step 1: Delete OnboardingTips.swift**

```bash
git rm "Lumoria App/views/onboarding/OnboardingTips.swift"
```

- [ ] **Step 2: Remove file reference from Xcode project**

Edit `Lumoria App.xcodeproj/project.pbxproj` to remove the `OnboardingTips.swift` file reference and any build-phase entry. Verify:

```bash
grep -c "OnboardingTips" "Lumoria App.xcodeproj/project.pbxproj"
```
Expected: `0`.

- [ ] **Step 3: Strip TipKit from Lumoria_AppApp.swift**

Open `Lumoria App/Lumoria_AppApp.swift`. Replace the `analyticsBootstrap` closure (lines 15–24) with:

```swift
private let analyticsBootstrap: Void = {
    if let service = AmplitudeAnalyticsService() {
        Analytics.configure(service)
    }
    Analytics.track(.sdkInitialized)
}()
```

Remove the `import TipKit` line (line 11).

- [ ] **Step 4: Rewire onboardingCoordinator to auth**

In `Lumoria_AppApp.swift`, locate the `.onChange(of: authManager.isAuthenticated)` block (line 114). Replace with:

```swift
            .onChange(of: authManager.isAuthenticated) { _, isAuthed in
                if isAuthed {
                    pushService.authDidChange()
                    Task {
                        await notificationPrefs.load()
                        await onboardingCoordinator.loadOnAuth()
                    }
                } else {
                    Task { await pushService.signedOut() }
                }
            }
```

Also trigger the initial hydrate on app launch (in case a session was restored silently). Right before the existing `.onChange(of: authManager.isAuthenticated)` line, add:

```swift
            .task {
                if authManager.isAuthenticated {
                    await onboardingCoordinator.loadOnAuth()
                }
            }
```

Note: there is already a `.task { ... Analytics.track(.appOpened(source: .cold)) ... }` block a few lines earlier. Merge by placing the new loadOnAuth call inside that existing `.task`:

```swift
            .task {
                Analytics.track(.appOpened(source: .cold))
                await pushService.requestAuthorization()
                if authManager.isAuthenticated {
                    await onboardingCoordinator.loadOnAuth()
                }
            }
```

- [ ] **Step 5: Rewrite ContentView sheets + 3s entry**

Replace the body / modifier stack in `Lumoria App/ContentView.swift`. Replace the block starting at line 52 (`.task`) up to the `.fullScreenCover` (before line 85) with:

```swift
        .task {
            memoriesStore.onboardingCoordinator = onboardingCoordinator
            WidgetSnapshotWriter.shared.observe(
                memoriesStore: memoriesStore,
                ticketsStore: ticketsStore
            )
            await memoriesStore.load()
            await ticketsStore.load()
            await profileStore.load()
            await notificationsStore.load()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            onboardingCoordinator.maybePresentEntry()
        }
        .sheet(isPresented: $onboardingCoordinator.showWelcome) {
            WelcomeSheetView()
                .environmentObject(onboardingCoordinator)
        }
        .sheet(isPresented: $onboardingCoordinator.showResume) {
            ResumeSheetView()
                .environmentObject(onboardingCoordinator)
        }
        .sheet(isPresented: $onboardingCoordinator.showEndCover) {
            OnboardingEndSheetView()
                .environmentObject(onboardingCoordinator)
        }
        .alert(
            "Leave the tutorial?",
            isPresented: $onboardingCoordinator.showLeaveAlert
        ) {
            Button("Leave", role: .destructive) {
                Task { await onboardingCoordinator.confirmLeaveTutorial() }
            }
            Button("Stay", role: .cancel) {
                onboardingCoordinator.showLeaveAlert = false
            }
        } message: {
            Text("You can replay it anytime from Settings.")
        }
        .onChange(of: onboardingCoordinator.showWelcome) { _, isShowing in
            if isShowing { selectedTab = 0 }
        }
        .onChange(of: onboardingCoordinator.showResume) { _, isShowing in
            if isShowing { selectedTab = 0 }
        }
        .onChange(of: onboardingCoordinator.showEndCover) { _, isShowing in
            if isShowing { selectedTab = 0 }
        }
```

Also remove the old `.onChange(of: onboardingCoordinator.pendingMemoryToOpen)` block (lines 76–79) since that property no longer exists on the coordinator.

- [ ] **Step 6: Build to verify**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: compile errors only in `CollectionsStore.swift` (still calls `donateMemoryCreated`), `CollectionsView.swift`, `CollectionDetailView.swift`, `SuccessStep.swift`, and any other file using removed coordinator methods or Tip structs. These are addressed in the next tasks.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor(onboarding): delete TipKit, wire new coordinator + sheets

Removes OnboardingTips.swift, TipKit import, and Tips.configure. Wires
Welcome / Resume / End sheet presentation in ContentView with a 3-second
post-load delay and a leave-tutorial alert.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: CollectionsView + CollectionsStore (createMemory / memoryCreated)

**Files:**
- Modify: `Lumoria App/views/collections/CollectionsView.swift`
- Modify: `Lumoria App/views/collections/CollectionsStore.swift:122` (replace `donateMemoryCreated` call)

- [ ] **Step 1: Update CollectionsStore call-site**

Open `Lumoria App/views/collections/CollectionsStore.swift`. Replace line 122 (`onboardingCoordinator?.donateMemoryCreated(inserted)`) with:

```swift
            if onboardingCoordinator?.currentStep == .createMemory {
                Task { await onboardingCoordinator?.advance(from: .createMemory) }
            }
```

- [ ] **Step 2: Add anchors + overlays in CollectionsView**

Open `Lumoria App/views/collections/CollectionsView.swift`. First add the environment object import if missing:

```swift
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
```

Find the "+" button in the toolbar / top bar (search for `systemImage: "plus"` or `"plus.circle"`). Tag it:

```swift
            Button { /* existing action */ } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
            }
            .onboardingAnchor("memories.plus")
```

Find the memory tile grid rendering (search for `ForEach` over memories returning a `MemoryTile` / `CollectionCard`). Identify the newest memory (`memories.first`, since `load()` orders by `created_at desc`). Tag its card:

```swift
            ForEach(memoriesStore.memories) { memory in
                CollectionCard(memory: memory) // existing
                    .onboardingAnchor(
                        memory.id == memoriesStore.memories.first?.id
                            ? "memories.newTile" : "unused.\(memory.id.uuidString)"
                    )
            }
```

Remove any `.popoverTip(MemoryTip())` modifier on the + button (if present).

At the root `body` of the view (end of the outermost container), attach both overlays:

```swift
        .onboardingOverlay(
            step: .createMemory,
            coordinator: onboardingCoordinator,
            anchorID: "memories.plus",
            tip: OnboardingTipCopy(
                title: "Create a memory",
                body: "Memories gather tickets into one place. Create one by tapping the + button."
            )
        )
        .onboardingOverlay(
            step: .memoryCreated,
            coordinator: onboardingCoordinator,
            anchorID: "memories.newTile",
            tip: OnboardingTipCopy(
                title: "Your memory has been created",
                body: "Once you will have tickets added to this memory, they will appear on this tile. Tap this memory to open it."
            )
        )
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: no errors in CollectionsView / CollectionsStore.

- [ ] **Step 4: Manual smoke test plan** (doc-only — commit after implementing)

On a fresh (no memories) signup: tap Start tutorial → verify dim overlay with cutout around +. Tap +. Create memory. Verify overlay dismisses, then after save reappears around the newly created tile with the second-step copy.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/collections/"
git commit -m "feat(onboarding): createMemory + memoryCreated overlays

Anchors on the + button and the newest memory tile; CollectionsStore
advances the coordinator on addMemory success.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: CollectionDetailView (enterMemory) + CategoryStep (pickCategory)

**Files:**
- Modify: `Lumoria App/views/collections/CollectionDetailView.swift`
- Modify: `Lumoria App/views/tickets/new/CategoryStep.swift`

- [ ] **Step 1: CollectionDetailView — anchor + overlay + on-appear advance**

Open `Lumoria App/views/collections/CollectionDetailView.swift`. Inject the coordinator:

```swift
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
```

Locate the top-trailing `+` button. Tag it:

```swift
            Button { /* existing action opening NewTicketFunnelView */ } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
            }
            .onboardingAnchor("memoryDetail.plus")
```

Remove any `.popoverTip(TicketTip())` modifier if present.

At the root body, add:

```swift
        .onboardingOverlay(
            step: .enterMemory,
            coordinator: onboardingCoordinator,
            anchorID: "memoryDetail.plus",
            tip: OnboardingTipCopy(
                title: "Create your first ticket",
                body: "Let's fill this memory with your first ticket. Tap the + button to start.",
                leadingEmoji: "😀"
            )
        )
        .onAppear {
            if onboardingCoordinator.currentStep == .memoryCreated {
                Task { await onboardingCoordinator.advance(from: .memoryCreated) }
            }
        }
```

- [ ] **Step 2: CategoryStep — anchor grid + overlay**

Open `Lumoria App/views/tickets/new/CategoryStep.swift`. Inject coordinator:

```swift
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
```

Wrap the `LazyVGrid` with an anchor + overlay. Change body to:

```swift
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(TicketCategory.allCases.filter(\.isAvailable)) { category in
                CategoryTile(
                    title: category.title,
                    imageName: category.imageName,
                    isSelected: funnel.category == category,
                    isAvailable: category.isAvailable,
                    onTap: { funnel.category = category }
                )
            }
        }
        .onboardingAnchor("funnel.categories")
        .onAppear {
            if onboardingCoordinator.currentStep == .enterMemory {
                Task { await onboardingCoordinator.advance(from: .enterMemory) }
            }
        }
        .onChange(of: funnel.category) { _, newValue in
            guard let newValue else { return }
            Analytics.track(.ticketCategorySelected(category: newValue.analyticsProp))
            if onboardingCoordinator.currentStep == .pickCategory {
                Task { await onboardingCoordinator.advance(from: .pickCategory) }
            }
        }
        .onboardingOverlay(
            step: .pickCategory,
            coordinator: onboardingCoordinator,
            anchorID: "funnel.categories",
            tip: OnboardingTipCopy(
                title: "Pick a category",
                body: "Tickets are separated into categories. Pick a category to continue."
            )
        )
    }
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/collections/CollectionDetailView.swift" \
        "Lumoria App/views/tickets/new/CategoryStep.swift"
git commit -m "feat(onboarding): enterMemory + pickCategory overlays

Detail view's + button and the categories grid. Advances fire on view
appear and on category pick respectively.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: pickTemplate overlay + pendingStyleStep

**Files:**
- Modify: `Lumoria App/views/tickets/new/NewTicketFunnel.swift` (view layer)

Note: there are two files with this name — the data model at line 1 above, and a view file presenting the funnel. The template picker view is typically `NewTicketFunnelView` or a dedicated `TemplateStep`. Find the file with the template grid:

```bash
grep -l "TicketTemplateKind" "Lumoria App/views/tickets/new/" -r
```

- [ ] **Step 1: Locate the template grid**

Find the file rendering `template ?? .plane.templates` or similar. It's most likely `NewTicketFunnel.swift` (the view presenter wrapping the funnel state) — if not, use whichever file defines the `TemplateStep` subview. Open it.

- [ ] **Step 2: Tag first template card + add overlay**

Inject coordinator:
```swift
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
```

Inside the template ForEach, tag only the first item:

```swift
            ForEach(Array(templates.enumerated()), id: \.element) { idx, template in
                TemplateCard(template: template) // existing
                    .onboardingAnchor(idx == 0 ? "funnel.firstTemplate" : "unused.tpl.\(template.rawValue)")
            }
```

On template selection (where `funnel.template = …` is assigned), add:

```swift
                        funnel.template = template
                        if onboardingCoordinator.currentStep == .pickTemplate {
                            onboardingCoordinator.pendingStyleStep = funnel.hasStylesStep
                            Task { await onboardingCoordinator.advance(from: .pickTemplate) }
                        }
```

Note: `funnel.hasStylesStep` must reflect the just-picked template. `funnel.template = template` triggers it. `hasStylesStep` is a `var` that reads the current template. If it's evaluated synchronously after assignment, the new template is already in place.

At the template step's root view, add the overlay:

```swift
        .onboardingOverlay(
            step: .pickTemplate,
            coordinator: onboardingCoordinator,
            anchorID: "funnel.firstTemplate",
            tip: OnboardingTipCopy(
                title: "Pick a template",
                body: "Each category has different templates that match it. You can also check the content of each template by tapping the information button."
            )
        )
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/new/NewTicketFunnel.swift"
git commit -m "feat(onboarding): pickTemplate overlay + pendingStyleStep capture

Records whether the chosen template has style variants so fillInfo
advance knows whether to route through pickStyle.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: fillInfo overlay on FormStep + UndergroundFormStep

**Files:**
- Modify: `Lumoria App/views/tickets/new/FormStep.swift`
- Modify: `Lumoria App/views/tickets/new/UndergroundFormStep.swift`

- [ ] **Step 1: FormStep — anchor first required field + overlay**

Open `Lumoria App/views/tickets/new/FormStep.swift`. Inject the coordinator:

```swift
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @FocusState private var onboardingFocusField: Bool
```

Locate the first required field (for plane templates it's typically the origin airport picker; for train templates the origin station / city; for concert the artist). Tag it. Example for plane:

```swift
            AirportPickerField(/* existing */)
                .onboardingAnchor("funnel.firstField")
```

If there are multiple template variants in FormStep, conditionally tag the template-specific first field. Simplest approach: tag the first visible field unconditionally — a single outermost `VStack { ... }` wrapped with `.onboardingAnchor("funnel.firstField")` pointed at its *first child* via `Section("Departure")` / first `Field` widget.

Actually tag the visually first field regardless of template, by placing the anchor on whatever container renders the first row. If the layout is a Form / VStack, a pragmatic choice is to tag the first row subview.

Example, tag the first VStack section:

```swift
            VStack(alignment: .leading, spacing: 8) {
                // existing first field (Airport / Origin City / Artist …)
            }
            .onboardingAnchor("funnel.firstField")
```

At the root of the form, add:

```swift
        .onboardingOverlay(
            step: .fillInfo,
            coordinator: onboardingCoordinator,
            anchorID: "funnel.firstField",
            tip: OnboardingTipCopy(
                title: "Fill the required information",
                body: "Every template have specific information attached to it. Fill all the required information to edit your ticket."
            )
        )
        .onAppear {
            if onboardingCoordinator.currentStep == .pickTemplate {
                // User may skip orientation step visuals but it fires anyway.
                Task { await onboardingCoordinator.advance(from: .pickTemplate) }
            }
        }
```

Also advance when user focuses the first required field (tap inside the cutout):

```swift
        // inside the first field binding onChange / onTap:
        .onTapGesture {
            if onboardingCoordinator.currentStep == .fillInfo {
                Task { await onboardingCoordinator.advance(from: .fillInfo) }
            }
        }
```

- [ ] **Step 2: UndergroundFormStep — same pattern**

Open `Lumoria App/views/tickets/new/UndergroundFormStep.swift`. Apply the same pattern: tag the first required UI (city picker or origin station), and add the same overlay modifier. Reuse the `funnel.firstField` anchor id — only one of the two will render at a time.

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/new/FormStep.swift" \
        "Lumoria App/views/tickets/new/UndergroundFormStep.swift"
git commit -m "feat(onboarding): fillInfo overlay with cutout on first required field

Overlay dismisses when user taps into the cutout. Advance transitions
to pickStyle or allDone per pendingStyleStep.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: pickStyle overlay (TemplateDetailsSheet or style step view)

**Files:**
- Modify: `Lumoria App/views/tickets/new/TemplateDetailsSheet.swift` (or whichever file renders the style grid)

- [ ] **Step 1: Locate the style step view**

```bash
grep -l "availableStyles\|TicketStyleVariant" "Lumoria App/views/tickets/new/" -r
```

Open the file that renders the `Available styles` grid (matches Figma node 1904-108979).

- [ ] **Step 2: Anchor the styles grid + overlay**

Inject coordinator and apply:

```swift
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator

    // Inside the styles LazyVGrid / ForEach container:
    LazyVGrid(/* existing */) {
        ForEach(funnel.availableStyles, id: \.id) { variant in
            StyleTile(variant: variant) // existing
        }
    }
    .onboardingAnchor("funnel.styles")
    .onAppear {
        if onboardingCoordinator.currentStep == .fillInfo {
            Task { await onboardingCoordinator.advance(from: .fillInfo) }
        }
    }
    .onChange(of: funnel.selectedStyleId) { _, newId in
        guard newId != nil else { return }
        if onboardingCoordinator.currentStep == .pickStyle {
            Task { await onboardingCoordinator.advance(from: .pickStyle) }
        }
    }
```

At the root:

```swift
        .onboardingOverlay(
            step: .pickStyle,
            coordinator: onboardingCoordinator,
            anchorID: "funnel.styles",
            tip: OnboardingTipCopy(
                title: "Select a style",
                body: "Some templates have alternative styles. Scroll through the options and tap the one you like to change how your ticket looks."
            )
        )
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/new/"
git commit -m "feat(onboarding): pickStyle overlay on style grid

Skipped automatically when template has no variants because
coordinator.pendingStyleStep is false at fillInfo advance.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: SuccessStep allDone + export/addToMemory branching

**Files:**
- Modify: `Lumoria App/views/tickets/new/SuccessStep.swift`

- [ ] **Step 1: Replace donate calls + add overlay**

Open `Lumoria App/views/tickets/new/SuccessStep.swift`. In `actionsGrid` (line 219), replace the create-flow `VStack` (lines 232–246) with:

```swift
            VStack(spacing: 12) {
                Button("Export Ticket") {
                    showExport = true
                    if onboardingCoordinator.currentStep == .allDone {
                        Task { await onboardingCoordinator.chose(.export) }
                    }
                }
                .lumoriaButtonStyle(.secondary, size: .large)
                .disabled(funnel.createdTicket == nil)

                Button("Add to Memory") {
                    showAddToMemory = true
                    if onboardingCoordinator.currentStep == .allDone {
                        Task { await onboardingCoordinator.chose(.addToMemory) }
                    }
                }
                .lumoriaButtonStyle(.primary, size: .large)
                .disabled(funnel.createdTicket == nil)
            }
            .onboardingAnchor("success.actions")
```

Remove the `.popoverTip(ExportTip())` modifier. Remove the `import TipKit` at the top if no longer used.

- [ ] **Step 2: Remove the old donateTicketCreated / donateExportOpened calls**

Replace line 112 (`onboardingCoordinator.donateTicketCreated()`) with:

```swift
            if onboardingCoordinator.currentStep == .pickStyle
                || onboardingCoordinator.currentStep == .fillInfo {
                // pickStyle might have been skipped; fillInfo might not have
                // fired advance yet if the user tapped Next very fast. Unify
                // by advancing whichever step is current so we land on .allDone.
                let current = onboardingCoordinator.currentStep
                Task { await onboardingCoordinator.advance(from: current) }
            }
```

- [ ] **Step 3: Add allDone overlay**

At the root of the view body, after existing modifiers:

```swift
        .onboardingOverlay(
            step: .allDone,
            coordinator: onboardingCoordinator,
            anchorID: "success.actions",
            tip: OnboardingTipCopy(
                title: "Ticket created!",
                body: "Your ticket has been created. You can find it in All Tickets. You can now add it to a Memory or Export your ticket to use it in another app."
            )
        )
```

- [ ] **Step 4: Build**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/tickets/new/SuccessStep.swift"
git commit -m "feat(onboarding): allDone overlay + variant branching on SuccessStep

Removes donateTicketCreated / donateExportOpened. Export / Add to Memory
buttons call coordinator.chose(variant).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: export + addToMemory overlays on the two sheets

**Files:**
- Modify: `Lumoria App/views/tickets/new/ExportSheet.swift`
- Modify: `Lumoria App/views/tickets/new/AddToMemorySheet.swift` (or wherever it lives)

- [ ] **Step 1: Find the exact filenames**

```bash
grep -l "ExportSheet\|AddToMemorySheet" "Lumoria App/views/" -r
```

- [ ] **Step 2: ExportSheet — anchor the three group cards stack + overlay**

Open `ExportSheet.swift`. Inject coordinator. Tag the container holding the three export groups (Social / IM / Camera roll):

```swift
        VStack(spacing: 16) {
            SocialGroupCard(...)
            InstantMessagingGroupCard(...)
            CameraRollCard(...)
        }
        .onboardingAnchor("export.groups")
```

On any export-destination tap (wherever `Analytics.track(.exportDestinationSelected(...))` fires), add:

```swift
            if onboardingCoordinator.currentStep == .exportOrAddMemory
               && onboardingCoordinator.exportOrAddChoice == .export {
                Task { await onboardingCoordinator.advance(from: .exportOrAddMemory) }
            }
```

At the root:

```swift
        .onboardingOverlay(
            step: .exportOrAddMemory,
            coordinator: onboardingCoordinator,
            anchorID: "export.groups",
            tip: OnboardingTipCopy(
                title: "Export your ticket",
                body: "Choose the export option that matches what you want to achieve."
            )
        )
```

Note: the overlay only renders if this sheet is the visible `exportOrAddMemory` target (i.e. user picked Export, not Add-to-Memory). Since only one of the two sheets is presented at a time, this is naturally scoped.

- [ ] **Step 3: AddToMemorySheet — anchor memory list + overlay**

Open `AddToMemorySheet.swift`. Inject coordinator. Tag the memory list:

```swift
        List { /* memories */ }
            .onboardingAnchor("addToMemory.list")
```

On memory pick:

```swift
            if onboardingCoordinator.currentStep == .exportOrAddMemory
               && onboardingCoordinator.exportOrAddChoice == .addToMemory {
                Task { await onboardingCoordinator.advance(from: .exportOrAddMemory) }
            }
```

At the root:

```swift
        .onboardingOverlay(
            step: .exportOrAddMemory,
            coordinator: onboardingCoordinator,
            anchorID: "addToMemory.list",
            tip: OnboardingTipCopy(
                title: "Add to a memory",
                body: "Tap the memory you would like to add your ticket to. This can be changed later."
            )
        )
```

- [ ] **Step 4: Build**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/tickets/"
git commit -m "feat(onboarding): export + add-to-memory overlays

Either sheet hosts the same .exportOrAddMemory step; only the one the
user chose via SuccessStep is visible at a time.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 18: Settings replay row + Localizable.xcstrings

**Files:**
- Modify: `Lumoria App/views/settings/SettingsView.swift`
- Modify: `Lumoria App/Localizable.xcstrings`

- [ ] **Step 1: Rewire Settings replay row**

Open `Lumoria App/views/settings/SettingsView.swift`. Find the "Replay onboarding" row (grep for `replay`). Replace its action with:

```swift
            Button {
                Task {
                    await onboardingCoordinator.resetForReplay()
                    dismiss()  // dismiss Settings so the welcome sheet can present on Memories
                }
            } label: {
                Text("Replay onboarding")
            }
```

Remove any TipKit / `Tips.resetDatastore()` references.

- [ ] **Step 2: Add all new copy keys to Localizable.xcstrings**

Open `Lumoria App/Localizable.xcstrings` (JSON). Add entries for every `LocalizedStringKey` used in this feature if not already present:

- `"Welcome to Lumoria!"`
- `"Memories gather tickets into one place — a trip, a season, a night out. Whatever you want to hold onto."`
- `"Start tutorial"`
- `"Welcome back"`
- `"Want to continue where you left off in the tutorial?"`
- `"Continue tutorial"`
- `"All done!"`
- `"You can now enjoy Lumoria and create beautiful tickets for every moments you'd like to remember. We just covered the basics of Lumoria. There's so many more features waiting to be discovered."`
- `"Start using Lumoria"`
- `"Leave the tutorial?"`
- `"You can replay it anytime from Settings."`
- `"Leave"`
- `"Stay"`
- `"Create a memory"`
- `"Memories gather tickets into one place. Create one by tapping the + button."`
- `"Your memory has been created"`
- `"Once you will have tickets added to this memory, they will appear on this tile. Tap this memory to open it."`
- `"Create your first ticket"`
- `"Let's fill this memory with your first ticket. Tap the + button to start."`
- `"Pick a category"`
- `"Tickets are separated into categories. Pick a category to continue."`
- `"Pick a template"`
- `"Each category has different templates that match it. You can also check the content of each template by tapping the information button."`
- `"Fill the required information"`
- `"Every template have specific information attached to it. Fill all the required information to edit your ticket."`
- `"Select a style"`
- `"Some templates have alternative styles. Scroll through the options and tap the one you like to change how your ticket looks."`
- `"Ticket created!"`
- `"Your ticket has been created. You can find it in All Tickets. You can now add it to a Memory or Export your ticket to use it in another app."`
- `"Export your ticket"`
- `"Choose the export option that matches what you want to achieve."`
- `"Add to a memory"`
- `"Tap the memory you would like to add your ticket to. This can be changed later."`
- `"Replay onboarding"`
- `"Close"`
- `"Leave the tutorial"` (accessibility label)

Pattern for each entry (English only, extract-on-export for others):

```json
    "Welcome to Lumoria!": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Welcome to Lumoria!" } }
      }
    },
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -configuration Debug build -quiet
```
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/settings/SettingsView.swift" \
        "Lumoria App/Localizable.xcstrings"
git commit -m "feat(onboarding): settings replay row rewrite + localization keys

Replay row calls coordinator.resetForReplay() then dismisses Settings.
All tutorial copy registered in the string catalog for translation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 19: Update AnalyticsEventTests

**Files:**
- Modify: `Lumoria AppTests/AnalyticsEventTests.swift`

- [ ] **Step 1: Update onboarding event tests**

Open `Lumoria AppTests/AnalyticsEventTests.swift`. Find the onboarding event test block (grep for `onboardingSkipped` or `onboardingStepCompleted`). Replace references to the removed case `.onboardingSkipped(atStep:)` and old `OnboardingStepProp.memory` / `.ticket` / `.export` with the new cases:

```swift
    @Test
    func onboarding_events_nameAndProperties() {
        #expect(AnalyticsEvent.onboardingShown.name == "Onboarding Shown")
        #expect(AnalyticsEvent.onboardingStarted.name == "Onboarding Started")
        #expect(AnalyticsEvent.onboardingResumed.name == "Onboarding Resumed")
        #expect(AnalyticsEvent.onboardingDeclinedResume.name == "Onboarding Declined Resume")
        #expect(AnalyticsEvent.onboardingReplayed.name == "Onboarding Replayed")

        let stepCompleted = AnalyticsEvent.onboardingStepCompleted(step: .createMemory)
        #expect(stepCompleted.name == "Onboarding Step Completed")
        #expect(stepCompleted.properties["step"] as? String == "create_memory")

        let left = AnalyticsEvent.onboardingLeft(atStep: .fillInfo)
        #expect(left.name == "Onboarding Left")
        #expect(left.properties["at_step"] as? String == "fill_info")

        let completed = AnalyticsEvent.onboardingCompleted(durationSeconds: 45)
        #expect(completed.properties["duration_seconds"] as? Int == 45)
    }
```

- [ ] **Step 2: Run analytics tests**

```bash
xcodebuild test -scheme "Lumoria App" \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    -only-testing:"Lumoria AppTests/AnalyticsEventTests"
```
Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria AppTests/AnalyticsEventTests.swift"
git commit -m "test(onboarding): update analytics event tests for new cases

Covers onboardingResumed, declined, left, stepCompleted payload keys.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 20: End-to-end manual smoke + final sanity

**Files:** none (validation only).

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test -scheme "Lumoria App" \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```
Expected: all tests pass.

- [ ] **Step 2: Manual happy-path smoke test**

Run the app in the simulator. Sign up with a new email. Verify:
1. MemoriesView loads empty. Wait ~3 s. Welcome sheet appears.
2. Tap Start tutorial. Sheet dismisses. Dim overlay with cutout around the + button appears (step 1 tip copy visible).
3. Tap +. Overlay dismisses. Create memory sheet appears.
4. Create a memory named "Test". Return to MemoriesView. Overlay reappears around the new tile (step 2 copy).
5. Tap the memory tile. Detail view pushes. Overlay around + button (step 3 copy).
6. Tap +. Funnel presents. Overlay on category grid (step 4 copy).
7. Pick a category (e.g. Plane). Advance. Overlay on first template card (step 5 copy).
8. Pick a template (e.g. Studio). Advance. Form step. Overlay cutout around first field (step 6 copy).
9. Tap the cutout field. Overlay dismisses. Fill the form, tap Next. If template has styles (Studio does), style step appears with overlay (step 7 copy). Pick a style, Next.
10. SuccessStep. Overlay around Export / Add to Memory buttons (step 8 copy).
11. Tap Add to Memory. Sheet appears with overlay around memory list (addToMemory variant copy).
12. Pick the Test memory. Sheet dismisses. Funnel closes. Back on MemoriesView. End sheet appears.
13. Tap Start using Lumoria. Sheet dismisses. No more overlays.
14. Verify `public.profiles` row for the test user has `show_onboarding=false, onboarding_step=done` via Supabase dashboard.

- [ ] **Step 3: Smoke the skip path**

Sign up with a fresh email. Wait for welcome sheet. Tap X. Verify sheet dismisses, no overlays appear on Memories. Verify `public.profiles` has `show_onboarding=false, onboarding_step=done`.

- [ ] **Step 4: Smoke the resume path**

Sign up with a fresh email. Start tutorial. Advance to pickCategory overlay. Kill the app (stop the sim). Relaunch. Verify the Resume sheet appears on MemoriesView with "Welcome back" copy. Tap Continue. Verify overlay resumes on the category grid (the user is now inside the funnel from the previous session — actually, since the funnel was dismissed when the app was killed, the resume will need the user to open the funnel again via +. Confirm the overlay reappears on CategoryStep when they re-enter the funnel.)

- [ ] **Step 5: Smoke the replay path**

After completing (or leaving) the tutorial, open Settings → Replay onboarding. Verify Settings dismisses and the Welcome sheet reappears on Memories.

- [ ] **Step 6: Smoke the leave-tip path**

Start a fresh tutorial. At pickCategory overlay, tap the X on the tip card. Alert "Leave the tutorial?" appears. Tap Leave. Verify no more overlays and `public.profiles` shows `show_onboarding=false, onboarding_step=done`.

- [ ] **Step 7: Final commit if any fixes emerged**

If any of the above smoke steps uncovered issues, fix them in targeted commits. When green, done.

---

## Self-review checklist

- Spec coverage:
  - ✅ Profiles migration + RLS + trigger + backfill — Task 1
  - ✅ OnboardingStep enum — Task 2
  - ✅ OnboardingStepProp expanded to 12 cases — Task 2
  - ✅ AnalyticsEvent cases: shown/started/resumed/declined/stepCompleted/left/completed/replayed — Task 3
  - ✅ ProfileService — Task 4
  - ✅ OnboardingCoordinator rewrite with tests — Task 5
  - ✅ OnboardingAnchorKey + OnboardingTipCard — Task 6
  - ✅ OnboardingOverlay modifier — Task 7
  - ✅ Cover + end_cover imagesets — Task 8
  - ✅ Welcome/Resume/End sheets — Task 9
  - ✅ TipKit removal + ContentView sheet & alert wiring — Task 10
  - ✅ createMemory + memoryCreated overlays — Task 11
  - ✅ enterMemory + pickCategory overlays — Task 12
  - ✅ pickTemplate + pendingStyleStep capture — Task 13
  - ✅ fillInfo overlay with cutout — Task 14
  - ✅ pickStyle overlay — Task 15
  - ✅ allDone + chose(_:) branching — Task 16
  - ✅ exportOrAddMemory on both sheets — Task 17
  - ✅ Settings replay + localization — Task 18
  - ✅ AnalyticsEventTests update — Task 19
  - ✅ Manual E2E smoke — Task 20
- Type consistency:
  - `OnboardingStep.rawValue` matches the check constraint in the SQL migration (camelCase).
  - `OnboardingStepProp.rawValue` uses snake_case for the multi-word cases; `onboardingStepCompleted` consumes it directly.
  - `OnboardingCoordinator.advance(from:)`, `chose(_:)`, `dismissWelcomeSilently()`, `confirmLeaveTutorial()`, `resume()`, `declineResume()`, `finishAtEndCover()`, `resetForReplay()` — exact names used in tests (Task 5) and callers (Tasks 11–18).
  - `ProfileServicing` protocol used in both `OnboardingCoordinator` (production path) and `MockProfileService` (tests). No drift.
  - `onboardingAnchor` / `onboardingOverlay` modifiers used with consistent `anchorID` strings.
- Placeholder scan: no TBD / TODO / "implement later" — all steps contain complete code.

**Plan complete and saved to `docs/superpowers/plans/2026-04-24-onboarding-rework.md`.**
