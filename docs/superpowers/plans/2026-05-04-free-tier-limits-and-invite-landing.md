# Free-tier limits & invite-landing paywall — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the StoreKit paywall with an invite-only landing for free-tier limit-reached states, lift the ticket cap to 10/12, and surface an "X available slots" / `LumoriaUpgradeIncentive` pill in the Memories header.

**Architecture:** Single Swift constant (`EntitlementStore.kPaymentsEnabled = false`) gates every payment-related surface. `Paywall.present(for:.memoryLimit|.ticketLimit, …)` routes to a new `InviteLandingView` whose three states are driven by the existing `InvitesStore`. `LumoriaPremiumBadge` and `LumoriaUpgradeIncentive` are new design-token-driven components. SQL trigger constant bumped from 5 → 10 in a new migration.

**Tech Stack:** SwiftUI, Swift Testing, Supabase (Postgres triggers), `Color.Feedback.Promotion.*` design tokens, existing `InvitesStore` + `ShareSheet` + `InviteExplanationView`.

**Reference spec:** `docs/superpowers/specs/2026-05-04-free-tier-limits-and-invite-landing-design.md`

---

## Task 1 — Bump base ticket cap (Swift)

**Files:**
- Modify: `Lumoria App/services/entitlement/FreeCaps.swift:16`

- [ ] **Step 1: Edit the constant**

```swift
// Lumoria App/services/entitlement/FreeCaps.swift
enum FreeCaps {
    static let baseMemoryCap = 3
    static let memoryRewardBonus = 1

    static let baseTicketCap = 10
    static let ticketRewardBonus = 2

    static func memoryCap(rewardKind: InviteRewardKind?) -> Int {
        baseMemoryCap + (rewardKind == .memory ? memoryRewardBonus : 0)
    }

    static func ticketCap(rewardKind: InviteRewardKind?) -> Int {
        baseTicketCap + (rewardKind == .tickets ? ticketRewardBonus : 0)
    }
}
```

- [ ] **Step 2: Update the comment header to reference the new SQL migration**

Replace the `// Mirrors the SQL trigger logic in supabase/migrations/20260506000000_paywall_phase_1_foundation.sql.` line with a comment that also points to the new bump migration once Task 2 names it.

- [ ] **Step 3: Build to verify nothing else breaks**

Run: `xcodebuild -scheme "Lumoria App" -destination "generic/platform=iOS Simulator" -quiet build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/services/entitlement/FreeCaps.swift"
git commit -m "feat(caps): bump free-tier ticket cap from 5 to 10"
```

---

## Task 2 — Bump server-side ticket cap (SQL migration)

**Files:**
- Create: `supabase/migrations/20260504000000_bump_ticket_cap_to_10.sql`

- [ ] **Step 1: Create the migration**

```sql
-- supabase/migrations/20260504000000_bump_ticket_cap_to_10.sql
-- Bumps the free-tier ticket cap from 5 → 10 in the enforce_ticket_cap
-- trigger so the server matches FreeCaps.baseTicketCap on the client.
-- Reward bonus (+2 with invite_reward_kind = 'tickets') is unchanged.

CREATE OR REPLACE FUNCTION public.enforce_ticket_cap()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_monetisation_on  boolean;
  v_is_premium       boolean;
  v_grandfathered_at timestamptz;
  v_premium_expires  timestamptz;
  v_reward_kind      text;
  v_count            int;
  v_cap              int;
BEGIN
  SELECT monetisation_enabled
    INTO v_monetisation_on
    FROM public.app_settings
   LIMIT 1;
  IF NOT v_monetisation_on THEN
    RETURN NEW;
  END IF;

  SELECT is_premium, grandfathered_at, premium_expires_at, invite_reward_kind
    INTO v_is_premium, v_grandfathered_at, v_premium_expires, v_reward_kind
    FROM public.profiles
   WHERE user_id = NEW.user_id;

  IF v_grandfathered_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF v_is_premium AND (v_premium_expires IS NULL OR v_premium_expires > now()) THEN
    RETURN NEW;
  END IF;

  v_cap := 10 + (CASE WHEN v_reward_kind = 'tickets' THEN 2 ELSE 0 END);

  SELECT count(*) INTO v_count
    FROM public.tickets
   WHERE user_id = NEW.user_id;

  IF v_count >= v_cap THEN
    RAISE EXCEPTION 'ticket_cap_exceeded' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;
```

- [ ] **Step 2: Verify migration matches existing function signature**

Run: `grep -n "enforce_ticket_cap" supabase/migrations/20260506000000_paywall_phase_1_foundation.sql`
Expected: see the original `CREATE OR REPLACE FUNCTION public.enforce_ticket_cap()` block. Confirm the new file's signature, `LANGUAGE`, `SECURITY DEFINER`, and `search_path` exactly match.

- [ ] **Step 3: Update FreeCaps comment to reference this migration**

```swift
// Lumoria App/services/entitlement/FreeCaps.swift (top comment)
//
//  Free-tier counter math. Mirrors the SQL trigger logic in
//  supabase/migrations/20260504000000_bump_ticket_cap_to_10.sql
//  (and the original 20260506000000_paywall_phase_1_foundation.sql).
//  Keep both sides in sync.
//
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260504000000_bump_ticket_cap_to_10.sql "Lumoria App/services/entitlement/FreeCaps.swift"
git commit -m "feat(caps): bump server ticket cap from 5 to 10"
```

---

## Task 3 — Add `kPaymentsEnabled` constant + gate paywall presenter

**Files:**
- Modify: `Lumoria App/services/entitlement/EntitlementStore.swift:30-36`
- Modify: `Lumoria App/services/entitlement/PaywallPresenter.swift:29-37`
- Create: `Lumoria AppTests/PaywallPresenterTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Lumoria AppTests/PaywallPresenterTests.swift
import Foundation
import Testing
@testable import Lumoria_App

@MainActor
@Suite("Paywall.present routing")
struct PaywallPresenterTests {

    @Test("limit triggers always set state when user is free")
    func limitTriggerSetsState() {
        let entitlement = makeFreeEntitlement()
        let state = Paywall.PresentationState()

        Paywall.present(for: .memoryLimit, entitlement: entitlement, state: state)
        #expect(state.trigger == .memoryLimit)

        state.trigger = nil
        Paywall.present(for: .ticketLimit, entitlement: entitlement, state: state)
        #expect(state.trigger == .ticketLimit)
    }

    @Test("non-limit triggers no-op while kPaymentsEnabled is false")
    func nonLimitTriggerNoOpWhenPaymentsDisabled() {
        #expect(EntitlementStore.kPaymentsEnabled == false)
        let entitlement = makeFreeEntitlement()
        let state = Paywall.PresentationState()

        Paywall.present(for: .upgradeFromSettings, entitlement: entitlement, state: state)
        #expect(state.trigger == nil)

        Paywall.present(for: .timelineLocked, entitlement: entitlement, state: state)
        #expect(state.trigger == nil)
    }

    @Test("present is no-op when user already has premium")
    func skipsWhenPremium() {
        let entitlement = makeGrandfatheredEntitlement()
        let state = Paywall.PresentationState()

        Paywall.present(for: .memoryLimit, entitlement: entitlement, state: state)
        #expect(state.trigger == nil)
    }

    private func makeFreeEntitlement() -> EntitlementStore {
        let store = EntitlementStore.previewInstance(tier: .free, monetisationEnabled: true)
        return store
    }

    private func makeGrandfatheredEntitlement() -> EntitlementStore {
        EntitlementStore.previewInstance(tier: .grandfathered, monetisationEnabled: true)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -only-testing:"Lumoria AppTests/PaywallPresenterTests" -quiet`
Expected: FAIL — `EntitlementStore.kPaymentsEnabled` does not exist; `EntitlementStore.previewInstance(...)` does not exist; `nonLimitTriggerNoOpWhenPaymentsDisabled` would otherwise set `state.trigger = .upgradeFromSettings`.

- [ ] **Step 3: Add `kPaymentsEnabled` constant + previewInstance helper to `EntitlementStore`**

```swift
// Lumoria App/services/entitlement/EntitlementStore.swift
// (insert near the other static members, after the private product-id constants)

@MainActor
@Observable
final class EntitlementStore {

    /// Master toggle for any payment-related UI. False = no purchase
    /// paths anywhere in the app; the limit-reached paywall renders the
    /// invite-only landing instead. Flip to true once StoreKit ships.
    static let kPaymentsEnabled = false

    // ... existing properties unchanged ...

#if DEBUG
    /// Test-only constructor that skips ProfileService / AppSettingsService.
    /// Lets unit tests build a deterministic store without touching Supabase.
    static func previewInstance(
        tier: EntitlementTier,
        monetisationEnabled: Bool,
        inviteRewardKind: InviteRewardKind? = nil
    ) -> EntitlementStore {
        let store = EntitlementStore(
            profileService: PreviewProfileService(),
            appSettingsService: PreviewAppSettingsService()
        )
        store.tier = tier
        store.monetisationEnabled = monetisationEnabled
        store.inviteRewardKind = inviteRewardKind
        return store
    }
#endif
}

#if DEBUG
private final class PreviewProfileService: ProfileServicing, @unchecked Sendable {
    func fetch() async throws -> Profile { throw ProfileServiceError.notFound }
    func setStep(_ step: OnboardingStep) async throws {}
    func setShowOnboarding(_ value: Bool) async throws {}
    func replay() async throws {}
}

private final class PreviewAppSettingsService: AppSettingsServicing, @unchecked Sendable {
    func fetch() async throws -> AppSettings { throw NSError(domain: "preview", code: 0) }
}
#endif
```

(Existing properties — `tier`, `monetisationEnabled`, `trialAvailable`, `inviteRewardKind` — must be `internal(set)` or already writable. They are `private(set)` today, so change them to `internal(set)` inside `#if DEBUG` only, OR add a single `#if DEBUG` mutator. Cleanest fix: change `private(set)` to `private(set) internal(set)` is invalid — instead add small `#if DEBUG` setter helpers like `_setTierForTesting(_:)`. Do whichever produces the smaller diff in your editor; the test only needs the three values seeded.)

- [ ] **Step 4: Gate `Paywall.present` on `kPaymentsEnabled`**

```swift
// Lumoria App/services/entitlement/PaywallPresenter.swift
@MainActor
static func present(
    for trigger: PaywallTrigger,
    entitlement: EntitlementStore,
    state: PresentationState
) {
    guard !entitlement.hasPremium else { return }
    if !EntitlementStore.kPaymentsEnabled, !trigger.isLimitReached {
        // Non-limit triggers (e.g. .upgradeFromSettings, .timelineLocked)
        // have nothing to upgrade to while payments are disabled.
        return
    }
    state.trigger = trigger
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -only-testing:"Lumoria AppTests/PaywallPresenterTests" -quiet`
Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/services/entitlement/EntitlementStore.swift" "Lumoria App/services/entitlement/PaywallPresenter.swift" "Lumoria AppTests/PaywallPresenterTests.swift"
git commit -m "feat(paywall): add kPaymentsEnabled flag and gate non-limit triggers"
```

---

## Task 4 — Extract `LumoriaPremiumBadge` component

**Files:**
- Create: `Lumoria App/components/LumoriaPremiumBadge.swift`
- Modify: `Lumoria App/components/FormStepCollapsibleItem.swift:89-101`

- [ ] **Step 1: Create the component**

```swift
// Lumoria App/components/LumoriaPremiumBadge.swift
//
//  Premium indicator from figma 1994:130463. Two variants:
//    - .crown: 24pt purple disc with a crown glyph (used on form steps,
//      settings status row, invite landing toolbar).
//    - .valueOffer(text): pill with white text, used for marketing copy
//      such as "2 months free".
//

import SwiftUI

struct LumoriaPremiumBadge: View {
    enum Style: Equatable {
        case crown
        case valueOffer(String)
    }

    let style: Style

    var body: some View {
        switch style {
        case .crown:
            ZStack {
                Circle()
                    .fill(Color("Colors/Purple/400"))
                    .frame(width: 24, height: 24)
                Image(systemName: "crown.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(Text("Premium"))

        case .valueOffer(let text):
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color("Colors/Purple/400"))
                )
        }
    }
}

#if DEBUG
#Preview("Crown") {
    LumoriaPremiumBadge(style: .crown)
        .padding()
        .background(Color.Background.default)
}

#Preview("Value offer") {
    LumoriaPremiumBadge(style: .valueOffer("2 months free"))
        .padding()
        .background(Color.Background.default)
}
#endif
```

- [ ] **Step 2: Replace inline badge in `FormStepCollapsibleItem`**

```swift
// Lumoria App/components/FormStepCollapsibleItem.swift
@ViewBuilder
private var statusIcon: some View {
    if proBadge {
        LumoriaPremiumBadge(style: .crown)
    } else if isComplete {
        Image(systemName: "checkmark.circle.fill")
            .font(.body)
            .foregroundStyle(Color.Feedback.Success.icon)
    } else {
        Image(systemName: "circle")
            .font(.body)
            .foregroundStyle(Color("Colors/Opacity/Black/inverse/50"))
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme "Lumoria App" -destination "generic/platform=iOS Simulator" -quiet build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Open both `#Preview` blocks in Xcode canvas**

Verify visually: crown disc renders 24×24, white crown glyph centered; value-offer pill renders with white "2 months free" on purple.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/components/LumoriaPremiumBadge.swift" "Lumoria App/components/FormStepCollapsibleItem.swift"
git commit -m "feat(components): extract LumoriaPremiumBadge with crown and valueOffer variants"
```

---

## Task 5 — Add `LumoriaUpgradeIncentive` component

**Files:**
- Create: `Lumoria App/components/LumoriaUpgradeIncentive.swift`

- [ ] **Step 1: Create the component**

```swift
// Lumoria App/components/LumoriaUpgradeIncentive.swift
//
//  Upgrade-incentive pill from figma 2146:159524. Surfaces in the
//  Memories header when the user has run out of slots, and anywhere
//  else we want to advertise the invite-reward unlock.
//

import SwiftUI

struct LumoriaUpgradeIncentive: View {
    enum Resource: Equatable {
        case memory
        case tickets
    }

    let resource: Resource

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.Feedback.Promotion.content)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.Feedback.Promotion.surface)
                    .overlay(
                        Capsule().stroke(Color.Feedback.Promotion.border, lineWidth: 1)
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("Opens an invite a friend to unlock more slots."))
    }

    private var label: LocalizedStringKey {
        switch resource {
        case .memory:  return "Unlock a new memory"
        case .tickets: return "Unlock 2 new slots"
        }
    }
}

#if DEBUG
#Preview("Memory") {
    LumoriaUpgradeIncentive(resource: .memory)
        .padding()
        .background(Color.Background.default)
}

#Preview("Tickets") {
    LumoriaUpgradeIncentive(resource: .tickets)
        .padding()
        .background(Color.Background.default)
}
#endif
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme "Lumoria App" -destination "generic/platform=iOS Simulator" -quiet build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Open both previews in Xcode canvas**

Verify visually: pill background `#f8f1ff`, 1pt purple border `#ac79e2`, text `#43006d`, 15pt semibold; padding 12 horizontal × 4 vertical; full radius capsule.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/components/LumoriaUpgradeIncentive.swift"
git commit -m "feat(components): add LumoriaUpgradeIncentive pill"
```

---

## Task 6 — Add new strings to `Localizable.xcstrings`

**Files:**
- Modify: `Lumoria App/Localizable.xcstrings`

- [ ] **Step 1: Add the new keys**

Use Xcode's String Catalog editor (open `Localizable.xcstrings`). Add these keys with `state: "translated"` for `en` and the noted variants:

| Key | en value | Notes |
|---|---|---|
| `%lld available slots` | (plural) | `one`: "1 available slot", `other`: "%lld available slots" |
| `Unlock a new memory` | "Unlock a new memory" | — |
| `Unlock 2 new slots` | "Unlock 2 new slots" | — |
| `More from Lumoria` | "More from Lumoria" | — |
| `by inviting a friend` | "by inviting a friend" | — |
| `Thank you for using Lumoria to craft beautiful tickets!` | "Thank you for using Lumoria to craft beautiful tickets!" | — |
| `You are running out of Memories or Ticket slots.` | "You are running out of Memories or Ticket slots." | — |
| `Invite a friend to gain 1 more Memory slot or 2 more ticket slots.` | "Invite a friend to gain 1 more Memory slot or 2 more ticket slots." | — |
| `Your friend will also get to choose between one or the other option for their account.` | "Your friend will also get to choose between one or the other option for their account." | — |
| `This offer is valid once per account (referring or referee).\nNo credit card required.` | "This offer is valid once per account (referring or referee).\nNo credit card required." | — |
| `Share my link` | "Share my link" | — |
| `You've used your invite. Delete a memory or a ticket to make room for a new one.` | "You've used your invite. Delete a memory or a ticket to make room for a new one." | — |
| `Early adopter — unlimited memories and tickets` | "Early adopter — unlimited memories and tickets" | — |
| `Free plan` | "Free plan" | — |
| `3 memories, 10 tickets` | "3 memories, 10 tickets" | — |
| `+1 memory or +2 tickets when your invite is redeemed` | "+1 memory or +2 tickets when your invite is redeemed" | — |
| `Premium` | "Premium" | accessibility label for the badge |

- [ ] **Step 2: Verify the catalog parses**

Run: `xcodebuild -scheme "Lumoria App" -destination "generic/platform=iOS Simulator" -quiet build`
Expected: `BUILD SUCCEEDED` (string catalog compiles into the bundle).

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/Localizable.xcstrings"
git commit -m "i18n: add strings for free-tier limits and invite landing"
```

---

## Task 7 — Add Memories header subtitle (slot counter / pill)

**Files:**
- Modify: `Lumoria App/views/collections/CollectionsView.swift:302-326`

- [ ] **Step 1: Replace the `header` computed view**

```swift
// Lumoria App/views/collections/CollectionsView.swift
private var header: some View {
    HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Memories")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)

            slotIndicator
        }

        Spacer()

        HStack(spacing: 8) {
            LumoriaIconButton(
                systemImage: "bell",
                badgeCount: notificationsStore.unreadCount
            ) {
                showNotificationCenter = true
            }
            LumoriaIconButton(systemImage: "plus") {
                presentNewMemoryOrPaywall()
            }
            .onboardingAnchor("memories.plus")
        }
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 8)
}

@ViewBuilder
private var slotIndicator: some View {
    // hasPremium already returns true when the kill-switch is off, so
    // this single guard hides the indicator for premium / grandfathered
    // users *and* during free-for-all mode.
    if !entitlement.hasPremium {
        let cap = FreeCaps.memoryCap(rewardKind: entitlement.inviteRewardKind)
        let remaining = max(0, cap - store.memories.count)
        if remaining == 0 {
            Button {
                Paywall.present(
                    for: .memoryLimit,
                    entitlement: entitlement,
                    state: paywallState
                )
            } label: {
                LumoriaUpgradeIncentive(resource: .memory)
            }
            .buttonStyle(.plain)
        } else {
            Text("\(remaining) available slots")
                .font(.system(size: 15))
                .foregroundStyle(Color.Text.tertiary)
        }
    }
}
```

- [ ] **Step 2: Build and run on the iOS Simulator**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -quiet build`
Expected: `BUILD SUCCEEDED`.

Then launch the app, sign in as a free user with 0 memories — verify "3 available slots" renders 4pt below the title in tertiary tint. Create memories until at the cap (3) — verify the pill appears in the same row position. Tap the pill — verify the `InviteLandingView` sheet presents (Task 8 ships this view; until then, this tap will route through the existing `PaywallView` — that's expected during this task).

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/views/collections/CollectionsView.swift"
git commit -m "feat(memories): add slot counter and upgrade-incentive pill to header"
```

---

## Task 8 — Build `InviteLandingView`

**Files:**
- Create: `Lumoria App/views/paywall/InviteLandingView.swift`

- [ ] **Step 1: Create the view**

```swift
// Lumoria App/views/paywall/InviteLandingView.swift
//
//  Invite-only "More from Lumoria" landing — figma 972:23490 (notSent
//  / sent), figma 972:23491 (redeemed). Replaces the StoreKit paywall
//  for `.memoryLimit` / `.ticketLimit` triggers while
//  EntitlementStore.kPaymentsEnabled is false.
//

import SwiftUI
import UIKit

struct InviteLandingView: View {

    let trigger: PaywallTrigger

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: InvitesStore

    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showExplanation = false
    @State private var error: String? = nil

    init(trigger: PaywallTrigger, store: InvitesStore = InvitesStore()) {
        self.trigger = trigger
        self._store = StateObject(wrappedValue: store)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
                .padding(.horizontal, 16)
                .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    bodyBlock
                    if let invite = currentInvite {
                        linkField(invite.shareURL)
                    }
                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Color.Feedback.Danger.text)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }

            Spacer(minLength: 0)

            primaryCTA
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            footnote
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .background(promotionBackdrop.ignoresSafeArea())
        .task {
            await store.load()
            Analytics.track(.invitePageViewed(state: invitePageStateProp))
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showExplanation) {
            InviteExplanationView()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            LumoriaIconButton(
                systemImage: "xmark",
                position: .onBackground
            ) {
                dismiss()
            }
            Spacer()
            LumoriaIconButton(
                systemImage: "questionmark",
                position: .onBackground
            ) {
                showExplanation = true
            }
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("More from Lumoria")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)
            Text("by inviting a friend")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.secondary)
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyBlock: some View {
        switch store.state {
        case .redeemed:
            Text("You've used your invite. Delete a memory or a ticket to make room for a new one.")
                .font(.body)
                .foregroundStyle(Color.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
        default:
            VStack(alignment: .leading, spacing: 12) {
                Text("Thank you for using Lumoria to craft beautiful tickets!")
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)

                (Text("You are running out of Memories or Ticket slots.")
                    .font(.body.bold())
                    .foregroundStyle(Color.Text.primary)
                 + Text(" ")
                 + Text("Invite a friend to gain 1 more Memory slot or 2 more ticket slots.")
                    .font(.body)
                    .foregroundStyle(Color.Text.primary))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Your friend will also get to choose between one or the other option for their account.")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Link field

    private func linkField(_ url: URL) -> some View {
        HStack(spacing: 8) {
            Text(url.absoluteString)
                .font(.body)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.InputField.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.InputField.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Primary CTA

    @ViewBuilder
    private var primaryCTA: some View {
        switch store.state {
        case .redeemed:
            EmptyView()
        case .loading:
            shareButton(label: "Share my link", disabled: true)
                .redacted(reason: .placeholder)
        case .notSent:
            shareButton(label: "Share my link", disabled: false) {
                Task {
                    if let invite = await store.sendInvite() {
                        shareURL = invite.shareURL
                        showShareSheet = true
                        Analytics.track(.inviteShared(
                            channel: .system_share,
                            inviteTokenHash: AnalyticsIdentity.hashString(invite.token)
                        ))
                    } else if let message = store.errorMessage {
                        error = message
                    }
                }
            }
        case .sent(let invite):
            shareButton(label: "Share my link", disabled: false) {
                shareURL = invite.shareURL
                showShareSheet = true
                Analytics.track(.inviteShared(
                    channel: .system_share,
                    inviteTokenHash: AnalyticsIdentity.hashString(invite.token)
                ))
            }
        }
    }

    private func shareButton(
        label: LocalizedStringKey,
        disabled: Bool,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black)
                )
        }
        .disabled(disabled)
    }

    // MARK: - Footnote

    private var footnote: some View {
        Text("This offer is valid once per account (referring or referee).\nNo credit card required.")
            .font(.caption2)
            .foregroundStyle(Color.Text.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Backdrop (pink-tinted blur from figma)

    private var promotionBackdrop: some View {
        ZStack(alignment: .top) {
            Color.Background.default
            LinearGradient(
                colors: [Color("Colors/Pink/50"), Color.Background.default],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 300)
            .blur(radius: 50)
        }
    }

    // MARK: - Helpers

    private var currentInvite: Invite? {
        switch store.state {
        case .sent(let invite):     return invite
        case .redeemed(let invite): return invite
        default:                    return nil
        }
    }

    private var invitePageStateProp: InvitePageStateProp {
        switch store.state {
        case .loading, .notSent: return .not_sent
        case .sent:              return .sent
        case .redeemed:          return .redeemed
        }
    }
}

#if DEBUG
private func previewStore(_ state: InvitesStore.ViewState) -> InvitesStore {
    let store = InvitesStore()
    store.setStateForPreview(state)
    return store
}

private var previewInvite: Invite {
    Invite(
        id: UUID(),
        inviterId: UUID(),
        token: "ABCDE23456",
        createdAt: Date(),
        revokedAt: nil,
        claimedBy: nil,
        claimedAt: nil,
        redeemedAt: nil
    )
}

private var previewRedeemedInvite: Invite {
    Invite(
        id: UUID(),
        inviterId: UUID(),
        token: "ABCDE23456",
        createdAt: Date().addingTimeInterval(-7 * 24 * 3600),
        revokedAt: nil,
        claimedBy: UUID(),
        claimedAt: Date().addingTimeInterval(-1 * 24 * 3600),
        redeemedAt: Date().addingTimeInterval(-1 * 24 * 3600)
    )
}

#Preview("Not sent") {
    InviteLandingView(trigger: .memoryLimit, store: previewStore(.notSent))
}

#Preview("Sent") {
    InviteLandingView(trigger: .memoryLimit, store: previewStore(.sent(previewInvite)))
}

#Preview("Redeemed") {
    InviteLandingView(trigger: .memoryLimit, store: previewStore(.redeemed(previewRedeemedInvite)))
}
#endif
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme "Lumoria App" -destination "generic/platform=iOS Simulator" -quiet build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Open all three previews in Xcode canvas**

Verify visually for each state: title block, body copy variant, link field (sent + redeemed only), CTA (notSent + sent show "Share my link"; redeemed shows nothing), footnote always visible, pink-tinted backdrop near top.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/paywall/InviteLandingView.swift"
git commit -m "feat(paywall): add InviteLandingView with notSent/sent/redeemed states"
```

---

## Task 9 — Switch the paywall sheet mount to render `InviteLandingView`

**Files:**
- Modify: `Lumoria App/Lumoria_AppApp.swift:121-128`

- [ ] **Step 1: Update the sheet binding**

Replace the existing block (around line 121-128, inside the `.sheet` mounting on the root view):

```swift
// Lumoria App/Lumoria_AppApp.swift
.environment(paywallState)
.sheet(isPresented: Binding(
    get: { paywallState.isPresented },
    set: { paywallState.isPresented = $0 }
)) {
    if let trigger = paywallState.trigger {
        if EntitlementStore.kPaymentsEnabled {
            PaywallView(trigger: trigger, entitlement: entitlement)
        } else {
            InviteLandingView(trigger: trigger)
        }
    }
}
```

- [ ] **Step 2: Build and run on the iOS Simulator**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -quiet build`
Expected: `BUILD SUCCEEDED`.

Then launch, sign in as a free user, create 3 memories, tap `+`. Verify the new `InviteLandingView` presents (not `PaywallView`).

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/Lumoria_AppApp.swift"
git commit -m "feat(paywall): route limit triggers to InviteLandingView while payments are off"
```

---

## Task 10 — Repurpose `PlanManagementView` as status-only

**Files:**
- Modify: `Lumoria App/views/settings/PlanManagementView.swift`

- [ ] **Step 1: Replace the body to render status only**

```swift
// Lumoria App/views/settings/PlanManagementView.swift
//
//  Settings → Plan management. While EntitlementStore.kPaymentsEnabled
//  is false, this is a read-only status row: shows the early-adopter
//  badge and copy for grandfathered users, or the free-plan blurb for
//  everyone else. The upgrade flow returns when payments ship.
//

import SwiftUI

struct PlanManagementView: View {
    @Environment(EntitlementStore.self) private var entitlement

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !entitlement.monetisationEnabled {
                    comingSoon
                } else {
                    statusRow
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var comingSoon: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Premium")
                .font(.largeTitle.bold())
            Text("Premium plans are coming soon. Today, every Lumoria account gets the full app for free.")
                .font(.body)
                .foregroundStyle(Color.Text.secondary)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch entitlement.tier {
        case .grandfathered:
            HStack(alignment: .top, spacing: 12) {
                LumoriaPremiumBadge(style: .crown)
                Text("Early adopter — unlimited memories and tickets")
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                Text("Free plan")
                    .font(.title2.bold())
                Text("3 memories, 10 tickets")
                    .font(.body)
                    .foregroundStyle(Color.Text.secondary)
                Text("+1 memory or +2 tickets when your invite is redeemed")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.tertiary)
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme "Lumoria App" -destination "generic/platform=iOS Simulator" -quiet build`
Expected: `BUILD SUCCEEDED`. (Removing the `import StoreKit` and `PurchaseService` references is intentional — they're dormant elsewhere.)

- [ ] **Step 3: Manual smoke test**

Launch app → Settings → Plan. Verify:
- Free user: "Free plan" + "3 memories, 10 tickets" + "+1 memory or +2 tickets …".
- Grandfathered user: crown badge + "Early adopter — unlimited memories and tickets".
- No upgrade button, no restore button.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/settings/PlanManagementView.swift"
git commit -m "feat(settings): repurpose Plan management as read-only status while payments are off"
```

---

## Task 11 — Changelog entry

**Files:**
- Create: `lumoria/src/content/changelog/2026-05-04--free-tier-limits-and-invite-landing.mdx`

- [ ] **Step 1: Create the changelog file**

```mdx
export const meta = {
  version: '1.0.7',
  date: '2026-05-04',
  type: 'new-features',
  title: 'Free-tier limits and invite-only paywall',
}

Lumoria now ships with explicit free-tier caps and an invite-only "More from Lumoria" landing in place of the StoreKit paywall. Free accounts can create up to 3 memories and 10 tickets; redeeming an invite lifts that to either 4 memories or 12 tickets. Early adopters who registered on the website keep their unlimited Premium status — no change for them. The Memories tab now shows "X available slots" 4pt under the title, and once you're at the cap the new `LumoriaUpgradeIncentive` pill replaces it. Tapping the pill (or the `+` button at the cap) opens the invite landing where you can share your one-time invite link via the iOS share sheet. Once your invite is redeemed and you're at the cap again, the landing prompts you to delete a memory or ticket to free a slot. Settings → Plan now renders a read-only status row: a crown badge for early adopters, a plain "Free plan, 3 memories, 10 tickets" blurb for everyone else.
```

- [ ] **Step 2: Bump the version number if needed**

Run: `ls -1 lumoria/src/content/changelog/ | tail -5`
Expected: confirm the most recent `version:` value is `1.0.6` (the airport IATA fix). Bump to `1.0.7`.

- [ ] **Step 3: Commit**

```bash
git add lumoria/src/content/changelog/2026-05-04--free-tier-limits-and-invite-landing.mdx
git commit -m "docs(changelog): free-tier limits and invite-only paywall"
```

---

## Final verification

After Task 11, run the full smoke checklist:

- [ ] **Build a clean app:** `xcodebuild -scheme "Lumoria App" -destination "generic/platform=iOS Simulator" -quiet clean build`. Expect `BUILD SUCCEEDED`.
- [ ] **Run all existing tests:** `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -quiet`. Expect all green, including the new `PaywallPresenterTests`.
- [ ] **Free user, fresh account:** Memories header reads "3 available slots". Create 3 memories — header swaps to the purple pill. Tap pill → invite landing opens with "Share my link". Tap button → iOS share sheet appears with the invite URL.
- [ ] **Free user, invite already sent:** Reach the cap. Tap pill → invite landing shows "Share my link" tied to the existing token (no new invite created).
- [ ] **Free user, invite already redeemed (cap = 4):** At 4 memories, tap pill → invite landing shows the redeemed copy ("You've used your invite. Delete a memory…") and no CTA.
- [ ] **Grandfathered user:** No subtitle in Memories header, paywall never opens, Settings → Plan shows the crown badge + "Early adopter" copy.
- [ ] **Kill-switch off:** `app_settings.monetisation_enabled = false` → header subtitle hidden, paywall never opens, `+` always opens new-memory sheet regardless of memory count.
- [ ] **Server cap parity:** With `monetisation_enabled = true` and a free user at 10 tickets, attempt to insert an 11th via Supabase directly — expect `ticket_cap_exceeded` Postgres error.
