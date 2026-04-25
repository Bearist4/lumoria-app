# Paywall Phase 2 — Purchase Flow + Kill Switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the real paywall UI, the StoreKit purchase flow, the Plan management screen, and the monetisation kill-switch — fully wired but legally inert until the developer flips `app_settings.monetisation_enabled` from `false` to `true`.

**Architecture:** A single-row `app_settings` table holds a `monetisation_enabled` boolean (default false). Server cap triggers and the new `set_premium_from_transaction` RPC both check this flag and no-op / raise when it's off. iOS `AppSettingsService` fetches the flag at the same time as the profile; `EntitlementStore.hasPremium` short-circuits to `true` while the flag is off so every paywall gate passes silently. The placeholder `PaywallView` is replaced with the real layout (default hero + 3-tile plan card + MonthTag chips + trial-aware CTA + restore link). A new `PurchaseService` handles `Product.products(for:) → purchase → verify → RPC → refresh` end-to-end. Settings → Plan goes from `placeholderView("Plan")` to a real tier-driven `PlanManagementView` that renders "Premium coming soon" while the flag is off.

**Tech Stack:** Supabase Postgres + RLS, Swift 6, SwiftUI, StoreKit 2 (`Product`, `Transaction`, `Product.purchase`, `manageSubscriptionsSheet`, `AppStore.sync()`), Swift Testing.

**Reference:** [`docs/superpowers/specs/2026-04-25-paywall-and-monetisation-design.md`](../specs/2026-04-25-paywall-and-monetisation-design.md) — the **Monetisation kill-switch** addendum and Section F **Phase 2** entry.

---

## File Structure

**Server (Supabase migration):**
- Create: `supabase/migrations/20260507000000_paywall_phase_2_kill_switch_and_purchase.sql` — `app_settings` singleton + RLS, cap-trigger updates to honour the flag, `set_premium_from_transaction` RPC.

**iOS — services/entitlement (extending the module from Phase 1):**
- Create: `Lumoria App/services/entitlement/AppSettingsService.swift` — fetches `app_settings.monetisation_enabled` from PostgREST.
- Modify: `Lumoria App/services/entitlement/EntitlementStore.swift` — adds `monetisationEnabled` and the `hasPremium` short-circuit.

**iOS — services/purchase (new module):**
- Create: `Lumoria App/services/purchase/PurchaseService.swift` — Product fetch, purchase, verification, RPC call, refresh.

**iOS — paywall components (new):**
- Create: `Lumoria App/views/paywall/MonthTag.swift` — small chip component (trial / best-value / one-time).
- Create: `Lumoria App/views/paywall/PlanCard.swift` — three-tile plan picker with selection state.
- Modify: `Lumoria App/views/paywall/PaywallView.swift` — replace placeholder layout with the real hero + plan card + CTA + restore + trust copy.

**iOS — Plan management:**
- Create: `Lumoria App/views/settings/PlanManagementView.swift` — tier-driven content; "coming soon" when monetisation is off.
- Modify: `Lumoria App/views/settings/SettingsView.swift` — replace `placeholderView("Plan")` with `PlanManagementView()`.

**iOS — tests:**
- Create: `Lumoria AppTests/AppSettingsServiceTests.swift` — JSON decode shape.
- Create: `Lumoria AppTests/EntitlementStoreMonetisationOffTests.swift` — `hasPremium` is forced true when the flag is off.

---

### Task 1: Phase 2 DB migration — kill switch, cap-trigger update, purchase RPC

**Files:**
- Create: `supabase/migrations/20260507000000_paywall_phase_2_kill_switch_and_purchase.sql`

- [ ] **Step 1: Write the SQL file**

```sql
-- Paywall Phase 2: monetisation kill-switch + set_premium_from_transaction.
-- The kill-switch makes every Phase 1 cap trigger no-op until the
-- developer flips it on with:
--
--   UPDATE public.app_settings SET monetisation_enabled = true
--    WHERE id = 'singleton';

-- 1. app_settings singleton + RLS.
CREATE TABLE IF NOT EXISTS public.app_settings (
  id                   text PRIMARY KEY,
  monetisation_enabled boolean NOT NULL DEFAULT false,
  updated_at           timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.app_settings (id) VALUES ('singleton')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_settings_read_all ON public.app_settings;
CREATE POLICY app_settings_read_all
  ON public.app_settings
  FOR SELECT
  TO authenticated
  USING (true);

-- No INSERT / UPDATE / DELETE policies for authenticated. Updates land
-- via the service role only (Supabase dashboard or admin SQL).

-- 2. Helper: monetisation_enabled() — single source of truth for both
--    cap triggers and the purchase RPC. STABLE so the planner caches
--    per-statement.
CREATE OR REPLACE FUNCTION public.monetisation_enabled()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT monetisation_enabled
    FROM public.app_settings
   WHERE id = 'singleton'
   LIMIT 1;
$function$;

GRANT EXECUTE ON FUNCTION public.monetisation_enabled() TO authenticated;

-- 3. Update cap triggers to honour the kill switch.
--    Same body as Phase 1, with an early return when the flag is off.
CREATE OR REPLACE FUNCTION public.enforce_memory_cap()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_grandfathered_at timestamptz;
  v_is_premium       boolean;
  v_premium_expires  timestamptz;
  v_reward_kind      text;
  v_count            int;
  v_cap              int;
BEGIN
  -- Kill switch: caps don't fire while monetisation is off.
  IF NOT public.monetisation_enabled() THEN
    RETURN NEW;
  END IF;

  SELECT grandfathered_at, is_premium, premium_expires_at, invite_reward_kind
    INTO v_grandfathered_at, v_is_premium, v_premium_expires, v_reward_kind
    FROM public.profiles
   WHERE user_id = NEW.user_id;

  IF v_grandfathered_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF v_is_premium AND
     (v_premium_expires IS NULL OR v_premium_expires > now())
  THEN
    RETURN NEW;
  END IF;

  v_cap := 3 + (CASE WHEN v_reward_kind = 'memory' THEN 1 ELSE 0 END);

  SELECT count(*) INTO v_count
    FROM public.memories
   WHERE user_id = NEW.user_id;

  IF v_count >= v_cap THEN
    RAISE EXCEPTION 'memory_cap_exceeded' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.enforce_ticket_cap()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_grandfathered_at timestamptz;
  v_is_premium       boolean;
  v_premium_expires  timestamptz;
  v_reward_kind      text;
  v_count            int;
  v_cap              int;
BEGIN
  IF NOT public.monetisation_enabled() THEN
    RETURN NEW;
  END IF;

  SELECT grandfathered_at, is_premium, premium_expires_at, invite_reward_kind
    INTO v_grandfathered_at, v_is_premium, v_premium_expires, v_reward_kind
    FROM public.profiles
   WHERE user_id = NEW.user_id;

  IF v_grandfathered_at IS NOT NULL THEN RETURN NEW; END IF;
  IF v_is_premium AND
     (v_premium_expires IS NULL OR v_premium_expires > now())
  THEN
    RETURN NEW;
  END IF;

  v_cap := 5 + (CASE WHEN v_reward_kind = 'tickets' THEN 2 ELSE 0 END);

  SELECT count(*) INTO v_count
    FROM public.tickets
   WHERE user_id = NEW.user_id;

  IF v_count >= v_cap THEN
    RAISE EXCEPTION 'ticket_cap_exceeded' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$function$;

-- 4. set_premium_from_transaction RPC.
--
-- Phase 2 trusts the iOS-side StoreKit verification. The iOS app passes
-- through productId, transactionId, and expiresAt fields that the
-- Transaction.payloadValue has already authenticated locally. Phase 5
-- (ASSN2) layers server-side push verification on top so the client
-- can never lie post-go-live.
--
-- While the kill-switch is off, this RPC raises immediately — even a
-- compromised client can't promote a profile to premium until you flip
-- the flag.
CREATE OR REPLACE FUNCTION public.set_premium_from_transaction(
  p_product_id     text,
  p_transaction_id text,
  p_expires_at     timestamptz DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF NOT public.monetisation_enabled() THEN
    RAISE EXCEPTION 'monetisation_disabled' USING ERRCODE = 'P0001';
  END IF;

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_product_id IS NULL OR length(p_product_id) = 0
     OR p_transaction_id IS NULL OR length(p_transaction_id) = 0
  THEN
    RAISE EXCEPTION 'invalid_arguments' USING ERRCODE = '22P02';
  END IF;

  UPDATE public.profiles
     SET is_premium             = true,
         premium_expires_at     = p_expires_at,
         premium_product_id     = p_product_id,
         premium_transaction_id = p_transaction_id
   WHERE user_id = v_uid;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.set_premium_from_transaction(text, text, timestamptz)
  TO authenticated;
```

- [ ] **Step 2: Apply via Supabase MCP**

Use `mcp__supabase__apply_migration` with `project_id="vhozwnykphqujsiuwesi"`, `name="paywall_phase_2_kill_switch_and_purchase"`, and `query` set to the file contents. Expected response: `{"success": true}`.

- [ ] **Step 3: Verify schema landed**

Use `mcp__supabase__execute_sql`:

```sql
SELECT
  (SELECT count(*) FROM public.app_settings WHERE id='singleton') AS settings_row,
  (SELECT monetisation_enabled FROM public.app_settings WHERE id='singleton') AS flag,
  (SELECT count(*) FROM pg_proc
    WHERE proname IN ('monetisation_enabled','set_premium_from_transaction')) AS new_funcs;
```

Expected: `settings_row = 1`, `flag = false`, `new_funcs = 2`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260507000000_paywall_phase_2_kill_switch_and_purchase.sql
git commit -m "feat(db): paywall phase 2 — kill switch + set_premium_from_transaction"
```

---

### Task 2: AppSettingsService — fetch monetisation_enabled

**Files:**
- Create: `Lumoria App/services/entitlement/AppSettingsService.swift`
- Test: `Lumoria AppTests/AppSettingsServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import Lumoria_App

@Suite("AppSettings decoding")
struct AppSettingsServiceTests {

    @Test("decodes the singleton row from PostgREST JSON")
    func decode() throws {
        let json = """
        {
          "id": "singleton",
          "monetisation_enabled": false,
          "updated_at": "2026-04-25T13:00:00+00:00"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(AppSettings.self, from: json)
        #expect(row.id == "singleton")
        #expect(row.monetisationEnabled == false)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:"Lumoria AppTests/AppSettingsServiceTests" \
  2>&1 | tail -10
```

Expected: build error — `AppSettings` type does not exist.

- [ ] **Step 3: Write AppSettingsService**

```swift
//
//  AppSettingsService.swift
//  Lumoria App
//
//  Reads the singleton public.app_settings row that backs the
//  monetisation kill-switch. The row is updatable only by the service
//  role; clients can SELECT but never INSERT/UPDATE/DELETE.
//

import Foundation
import Supabase

struct AppSettings: Codable, Equatable, Sendable {
    let id: String
    var monetisationEnabled: Bool
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case monetisationEnabled = "monetisation_enabled"
        case updatedAt           = "updated_at"
    }
}

protocol AppSettingsServicing: AnyObject, Sendable {
    func fetch() async throws -> AppSettings
}

final class AppSettingsService: AppSettingsServicing, @unchecked Sendable {

    func fetch() async throws -> AppSettings {
        let row: AppSettings = try await supabase
            .from("app_settings")
            .select()
            .eq("id", value: "singleton")
            .single()
            .execute()
            .value
        return row
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:"Lumoria AppTests/AppSettingsServiceTests" \
  2>&1 | tail -5
```

Expected: 1 test passed.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/services/entitlement/AppSettingsService.swift" \
        "Lumoria AppTests/AppSettingsServiceTests.swift"
git commit -m "feat(entitlement): add AppSettingsService for the monetisation flag"
```

---

### Task 3: EntitlementStore monetisation override

**Files:**
- Modify: `Lumoria App/services/entitlement/EntitlementStore.swift`
- Test: `Lumoria AppTests/EntitlementStoreMonetisationOffTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import Lumoria_App

@Suite("EntitlementStore monetisation override")
struct EntitlementStoreMonetisationOffTests {

    private func freeProfile() -> Profile {
        Profile(
            userId: UUID(),
            showOnboarding: false,
            onboardingStep: .done,
            grandfatheredAt: nil,
            isPremium: false,
            premiumExpiresAt: nil,
            premiumProductId: nil,
            premiumTransactionId: nil,
            inviteRewardKind: nil,
            inviteRewardClaimedAt: nil
        )
    }

    @Test("hasPremium is true for a free user when monetisation is off")
    func freeUserOff() {
        let resolved = EntitlementStore.resolved(
            profile: freeProfile(),
            monetisationEnabled: false,
            now: Date()
        )
        #expect(resolved.hasPremium == true)
        #expect(resolved.tier == .free)
    }

    @Test("hasPremium follows tier when monetisation is on")
    func freeUserOn() {
        let resolved = EntitlementStore.resolved(
            profile: freeProfile(),
            monetisationEnabled: true,
            now: Date()
        )
        #expect(resolved.hasPremium == false)
        #expect(resolved.tier == .free)
    }

    @Test("grandfathered hasPremium stays true regardless of flag")
    func grandfatheredAlwaysPremium() {
        var p = freeProfile()
        p.grandfatheredAt = Date()
        let off = EntitlementStore.resolved(
            profile: p, monetisationEnabled: false, now: Date()
        )
        let on = EntitlementStore.resolved(
            profile: p, monetisationEnabled: true, now: Date()
        )
        #expect(off.hasPremium == true)
        #expect(on.hasPremium == true)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:"Lumoria AppTests/EntitlementStoreMonetisationOffTests" \
  2>&1 | tail -10
```

Expected: build error — `EntitlementStore.resolved(profile:monetisationEnabled:now:)` does not exist.

- [ ] **Step 3: Add monetisation override to EntitlementStore**

Replace the existing `tier(for:now:)` static helper with a richer `resolved(profile:monetisationEnabled:now:)` that returns both the tier *and* a `hasPremium` bool that respects the flag. Update the runtime instance to fetch + cache `monetisationEnabled` and use the new helper.

```swift
//
// In EntitlementStore.swift, replace the existing class body and
// static helper. Diff is non-trivial — write the full file.
//

import Foundation
import StoreKit
import Observation

private let kLifetimeProductId = "app.lumoria.premium.lifetime"
private let kMonthlyProductId  = "app.lumoria.premium.monthly"
private let kAnnualProductId   = "app.lumoria.premium.annual"

@MainActor
@Observable
final class EntitlementStore {

    /// Pre-flag tier (what StoreKit + the profile say).
    private(set) var tier: EntitlementTier = .free
    /// Whether monetisation is live for this build / user.
    private(set) var monetisationEnabled: Bool = false
    private(set) var trialAvailable: Bool = false
    private(set) var inviteRewardKind: InviteRewardKind? = nil

    private let profileService: ProfileServicing
    private let appSettingsService: AppSettingsServicing

    init(
        profileService: ProfileServicing,
        appSettingsService: AppSettingsServicing
    ) {
        self.profileService = profileService
        self.appSettingsService = appSettingsService
        Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refresh()
            }
        }
    }

    /// While monetisation is off (kill switch in `app_settings`), every
    /// gate behaves as if the user already has Premium — caps don't
    /// fire, paywall never presents.
    var hasPremium: Bool {
        if !monetisationEnabled { return true }
        return tier.hasPremium
    }

    func refresh() async {
        // Fetch settings + profile in parallel.
        async let settingsTask = try? appSettingsService.fetch()
        async let profileTask  = try? profileService.fetch()

        let settings = await settingsTask
        let profile  = await profileTask

        self.monetisationEnabled = settings?.monetisationEnabled ?? false

        if let profile {
            self.tier = Self.tier(for: profile, now: Date())
            self.inviteRewardKind = profile.inviteRewardKind
        } else {
            self.tier = .free
            self.inviteRewardKind = nil
        }
    }

    /// Resolved view for tests — pure, no I/O.
    struct Resolved: Equatable {
        let tier: EntitlementTier
        let hasPremium: Bool
    }

    nonisolated static func resolved(
        profile: Profile,
        monetisationEnabled: Bool,
        now: Date
    ) -> Resolved {
        let tier = tier(for: profile, now: now)
        let has = !monetisationEnabled || tier.hasPremium
        return Resolved(tier: tier, hasPremium: has)
    }

    nonisolated static func tier(for profile: Profile, now: Date) -> EntitlementTier {
        if profile.grandfatheredAt != nil {
            return .grandfathered
        }
        if profile.isPremium {
            if profile.premiumExpiresAt == nil {
                return .lifetime
            }
            if let exp = profile.premiumExpiresAt, exp > now {
                let pid = profile.premiumProductId ?? kAnnualProductId
                return .subscriber(productId: pid, renewsAt: exp)
            }
        }
        return .free
    }
}
```

- [ ] **Step 4: Update app-root injection for the new init signature**

In `Lumoria App/Lumoria_AppApp.swift`, the existing `@State` initialiser needs the new dependency:

```swift
@State private var entitlement = EntitlementStore(
    profileService: ProfileService(),
    appSettingsService: AppSettingsService()
)
```

- [ ] **Step 5: Run all entitlement tests**

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:"Lumoria AppTests/EntitlementStoreTests" \
  -only-testing:"Lumoria AppTests/EntitlementStoreMonetisationOffTests" \
  2>&1 | tail -10
```

Expected: 8 tests pass (5 from Phase 1 + 3 new).

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/services/entitlement/EntitlementStore.swift" \
        "Lumoria App/Lumoria_AppApp.swift" \
        "Lumoria AppTests/EntitlementStoreMonetisationOffTests.swift"
git commit -m "feat(entitlement): kill-switch override — hasPremium=true while flag off"
```

---

### Task 4: MonthTag chip component

**Files:**
- Create: `Lumoria App/views/paywall/MonthTag.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  MonthTag.swift
//  Lumoria App
//
//  Small chip that sits inside a PlanCard tile.
//  Figma: 968-17993
//

import SwiftUI

struct MonthTag: View {
    enum Kind: Equatable {
        case trial(_ text: String)        // e.g. "14 days free"
        case bestValue(_ text: String)    // e.g. "Best value"
        case oneTime(_ text: String)      // e.g. "One-time"
    }

    let kind: Kind

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }

    private var text: String {
        switch kind {
        case .trial(let t), .bestValue(let t), .oneTime(let t): return t
        }
    }

    private var foreground: Color {
        switch kind {
        case .trial:     return Color.white
        case .bestValue: return Color.white
        case .oneTime:   return Color.Text.primary
        }
    }

    private var background: Color {
        switch kind {
        case .trial:     return Color.accentColor
        case .bestValue: return Color.green
        case .oneTime:   return Color.gray.opacity(0.2)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        MonthTag(kind: .trial("14 days free"))
        MonthTag(kind: .bestValue("Best value"))
        MonthTag(kind: .oneTime("One-time"))
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/views/paywall/MonthTag.swift"
git commit -m "feat(paywall): MonthTag chip — trial / best-value / one-time"
```

---

### Task 5: PlanCard component

**Files:**
- Create: `Lumoria App/views/paywall/PlanCard.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  PlanCard.swift
//  Lumoria App
//
//  3-tile plan picker. Tapping a tile updates the binding.
//  Figma: 968-17975
//

import SwiftUI

enum PaywallPlan: String, Equatable, CaseIterable, Identifiable {
    case monthly  = "app.lumoria.premium.monthly"
    case annual   = "app.lumoria.premium.annual"
    case lifetime = "app.lumoria.premium.lifetime"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly:  return "Monthly"
        case .annual:   return "Annual"
        case .lifetime: return "Lifetime"
        }
    }

    var isSubscription: Bool {
        switch self {
        case .monthly, .annual: return true
        case .lifetime:         return false
        }
    }
}

struct PlanCard: View {
    @Binding var selected: PaywallPlan
    /// Resolved (localised) display prices, keyed by the plan. Pulled
    /// from StoreKit `Product.displayPrice` when available, falling
    /// back to spec defaults.
    let prices: [PaywallPlan: String]
    /// Whether to show the "14 days free" tag on monthly/annual.
    let trialAvailable: Bool

    var body: some View {
        VStack(spacing: 12) {
            ForEach(PaywallPlan.allCases) { plan in
                tile(plan)
            }
        }
    }

    @ViewBuilder
    private func tile(_ plan: PaywallPlan) -> some View {
        let isSelected = plan == selected
        let price = prices[plan] ?? defaultPrice(plan)

        Button {
            selected = plan
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.headline)
                        if plan == .annual && !trialAvailable {
                            MonthTag(kind: .bestValue("Best value"))
                        }
                    }
                    Text(subtitle(plan, price: price))
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.secondary)
                }
                Spacer()
                if let tag = leadingTag(plan) {
                    tag
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.gray.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.Background.default)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func leadingTag(_ plan: PaywallPlan) -> some View {
        switch plan {
        case .monthly, .annual:
            if trialAvailable {
                MonthTag(kind: .trial("14 days free"))
            }
        case .lifetime:
            MonthTag(kind: .oneTime("One-time"))
        }
    }

    private func subtitle(_ plan: PaywallPlan, price: String) -> String {
        switch plan {
        case .monthly:  return "\(price) / month"
        case .annual:   return "\(price) / year"
        case .lifetime: return "\(price) once"
        }
    }

    private func defaultPrice(_ plan: PaywallPlan) -> String {
        switch plan {
        case .monthly:  return "$3.99"
        case .annual:   return "$24.99"
        case .lifetime: return "$59.99"
        }
    }
}

#Preview("Trial available") {
    @Previewable @State var selected: PaywallPlan = .annual
    PlanCard(
        selected: $selected,
        prices: [:],
        trialAvailable: true
    )
    .padding(24)
}

#Preview("Trial used") {
    @Previewable @State var selected: PaywallPlan = .annual
    PlanCard(
        selected: $selected,
        prices: [:],
        trialAvailable: false
    )
    .padding(24)
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/views/paywall/PlanCard.swift"
git commit -m "feat(paywall): PlanCard — 3-tile plan picker with selection ring"
```

---

### Task 6: PurchaseService — fetch products, purchase, verify, RPC, refresh

**Files:**
- Create: `Lumoria App/services/purchase/PurchaseService.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  PurchaseService.swift
//  Lumoria App
//
//  Wraps StoreKit 2 product fetch + purchase + verification, then posts
//  the verified Transaction's productId / transactionId / expiresAt to
//  `set_premium_from_transaction` so the server profile mirrors the
//  paid state. Refreshes EntitlementStore on success so every gate
//  picks up the new tier without a manual reload.
//

import Foundation
import StoreKit
import Supabase

@MainActor
@Observable
final class PurchaseService {

    enum Failure: Error, Equatable {
        case notSignedIn
        case verificationFailed
        case rpcFailed(String)
        case storeKitError(String)
    }

    private(set) var products: [PaywallPlan: Product] = [:]
    private(set) var isPurchasing: Bool = false
    private(set) var lastError: Failure? = nil

    private let entitlement: EntitlementStore

    init(entitlement: EntitlementStore) {
        self.entitlement = entitlement
    }

    /// Fetch the three known products. Idempotent — call on paywall
    /// appear; cached afterwards.
    func loadProducts() async {
        do {
            let ids = PaywallPlan.allCases.map(\.rawValue)
            let fetched = try await Product.products(for: ids)
            var byPlan: [PaywallPlan: Product] = [:]
            for p in fetched {
                if let plan = PaywallPlan(rawValue: p.id) {
                    byPlan[plan] = p
                }
            }
            self.products = byPlan
        } catch {
            self.lastError = .storeKitError(error.localizedDescription)
        }
    }

    func displayPrice(for plan: PaywallPlan) -> String? {
        products[plan]?.displayPrice
    }

    /// Run a full purchase. Returns true on success.
    @discardableResult
    func purchase(_ plan: PaywallPlan) async -> Bool {
        guard let product = products[plan] else { return false }
        guard let uid = supabase.auth.currentUser?.id else {
            lastError = .notSignedIn
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase(options: [
                .appAccountToken(uid)
            ])
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                try await markPremiumOnServer(
                    transaction: transaction,
                    product: product
                )
                await transaction.finish()
                await entitlement.refresh()
                return true

            case .userCancelled, .pending:
                return false

            @unknown default:
                return false
            }
        } catch {
            lastError = .storeKitError(error.localizedDescription)
            return false
        }
    }

    /// Apple-required: re-sync purchases for users who reinstall or
    /// switch devices.
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
            await entitlement.refresh()
            return true
        } catch {
            lastError = .storeKitError(error.localizedDescription)
            return false
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):     return value
        case .unverified(_, let err):  throw Failure.verificationFailed
        }
    }

    private func markPremiumOnServer(
        transaction: Transaction,
        product: Product
    ) async throws {
        struct Params: Encodable {
            let p_product_id: String
            let p_transaction_id: String
            let p_expires_at: String?
        }

        let expiresAt: Date? = product.subscription != nil
            ? transaction.expirationDate
            : nil

        let params = Params(
            p_product_id: product.id,
            p_transaction_id: String(transaction.id),
            p_expires_at: expiresAt.map { ISO8601DateFormatter().string(from: $0) }
        )

        do {
            try await supabase.rpc("set_premium_from_transaction", params: params).execute()
        } catch {
            throw Failure.rpcFailed(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/services/purchase/PurchaseService.swift"
git commit -m "feat(purchase): PurchaseService — fetch, purchase, verify, RPC, refresh"
```

---

### Task 7: Replace placeholder PaywallView with real layout

**Files:**
- Modify: `Lumoria App/views/paywall/PaywallView.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  PaywallView.swift
//  Lumoria App
//
//  Real paywall layout. Phase 2 ships a single default hero per the
//  trigger variant; Phase 3 splits the hero into 4 personalised blocks.
//
//  Figma — default: 969-20169 · trial: 969-20173 · trial used: 969-20171
//

import SwiftUI

struct PaywallView: View {
    let trigger: PaywallTrigger
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementStore.self) private var entitlement
    @State private var purchase: PurchaseService
    @State private var selected: PaywallPlan = .annual
    @State private var error: String? = nil

    init(trigger: PaywallTrigger, entitlement: EntitlementStore) {
        self.trigger = trigger
        self._purchase = State(initialValue: PurchaseService(entitlement: entitlement))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                hero
                planCard
                primaryCTA
                trustCopy
                restoreLink
                if let error { errorBanner(error) }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
        .task {
            await purchase.loadProducts()
        }
    }

    // MARK: - Hero (default for Phase 2)

    private var hero: some View {
        VStack(spacing: 16) {
            Image(systemName: heroSymbol)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.top, 24)
            Text(headline)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(subhead)
                .font(.title3)
                .foregroundStyle(Color.Text.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var heroSymbol: String {
        switch trigger.variant {
        case .memoryLimit:    return "rectangle.stack.fill"
        case .ticketLimit:    return "ticket.fill"
        case .mapSuite:       return "map.fill"
        case .premiumContent: return "sparkles"
        }
    }

    private var headline: String {
        switch trigger.variant {
        case .memoryLimit:    return "Unlimited memories."
        case .ticketLimit:    return "Unlimited tickets."
        case .mapSuite:       return "Your trips, told."
        case .premiumContent: return "The full catalogue."
        }
    }

    private var subhead: String {
        switch trigger.variant {
        case .memoryLimit:
            return "Free covers 3 memories. Premium has no cap."
        case .ticketLimit:
            return "Free covers 5 tickets. Premium has no cap."
        case .mapSuite:
            return "Premium unlocks the timeline scrub and full map export."
        case .premiumContent:
            return "Premium unlocks every template, every category, and the iOS sticker pack."
        }
    }

    // MARK: - Plan card

    private var planCard: some View {
        var prices: [PaywallPlan: String] = [:]
        for plan in PaywallPlan.allCases {
            if let p = purchase.displayPrice(for: plan) {
                prices[plan] = p
            }
        }
        return PlanCard(
            selected: $selected,
            prices: prices,
            trialAvailable: entitlement.trialAvailable
        )
    }

    // MARK: - CTA

    private var primaryCTA: some View {
        Button {
            Task {
                if await purchase.purchase(selected) {
                    dismiss()
                } else if let f = purchase.lastError {
                    error = description(of: f)
                }
            }
        } label: {
            Text(ctaText)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(purchase.isPurchasing)
    }

    private var ctaText: String {
        if selected == .lifetime {
            return "Buy lifetime"
        }
        if entitlement.trialAvailable {
            return "Start free trial"
        }
        return "Subscribe"
    }

    private var trustCopy: some View {
        VStack(spacing: 4) {
            Text(trustLine)
                .font(.footnote)
                .foregroundStyle(Color.Text.secondary)
                .multilineTextAlignment(.center)
            Text("By continuing you agree to our Terms and Privacy.")
                .font(.caption2)
                .foregroundStyle(Color.Text.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var trustLine: String {
        if selected == .lifetime {
            return "One-time purchase. No subscription."
        }
        if entitlement.trialAvailable {
            return "Free for 14 days, then \(priceTrailer). Cancel anytime."
        }
        return "Cancel anytime in Settings."
    }

    private var priceTrailer: String {
        guard let p = purchase.displayPrice(for: selected) else {
            return selected == .annual ? "$24.99/year" : "$3.99/month"
        }
        return selected == .annual ? "\(p)/year" : "\(p)/month"
    }

    // MARK: - Restore

    private var restoreLink: some View {
        Button("Restore purchases") {
            Task { _ = await purchase.restore() }
        }
        .font(.footnote)
        .foregroundStyle(.tint)
    }

    private func errorBanner(_ msg: String) -> some View {
        Text(msg)
            .font(.footnote)
            .foregroundStyle(Color.Feedback.Danger.icon)
            .multilineTextAlignment(.center)
    }

    private func description(of failure: PurchaseService.Failure) -> String {
        switch failure {
        case .notSignedIn:        return "You need to be signed in."
        case .verificationFailed: return "Couldn't verify the purchase. Try again."
        case .rpcFailed(let m):   return "Server didn't accept the purchase. (\(m))"
        case .storeKitError(let m): return m
        }
    }
}
```

- [ ] **Step 2: Update the sheet at app root to inject the entitlement store**

In `Lumoria App/Lumoria_AppApp.swift`, the sheet body changes from:

```swift
PaywallView(trigger: trigger)
```

to:

```swift
PaywallView(trigger: trigger, entitlement: entitlement)
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/paywall/PaywallView.swift" "Lumoria App/Lumoria_AppApp.swift"
git commit -m "feat(paywall): real layout — hero, plan card, CTA, restore, trust copy"
```

---

### Task 8: Replace SettingsView placeholder with PlanManagementView

**Files:**
- Create: `Lumoria App/views/settings/PlanManagementView.swift`
- Modify: `Lumoria App/views/settings/SettingsView.swift`

- [ ] **Step 1: Write PlanManagementView**

```swift
//
//  PlanManagementView.swift
//  Lumoria App
//
//  Settings → Plan management. Shows tier-driven copy when monetisation
//  is on; renders a "Premium coming soon" stub while the kill-switch
//  is off so the user sees the section exists without exposing buy
//  buttons.
//

import SwiftUI
import StoreKit

struct PlanManagementView: View {
    @Environment(EntitlementStore.self) private var entitlement
    @Environment(Paywall.PresentationState.self) private var paywallState

    @State private var purchase: PurchaseService

    init(entitlement: EntitlementStore) {
        self._purchase = State(initialValue: PurchaseService(entitlement: entitlement))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !entitlement.monetisationEnabled {
                    comingSoon
                } else {
                    tierCard
                    primaryAction
                }
                restoreButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Off state

    private var comingSoon: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Premium")
                .font(.largeTitle.bold())
            Text("Premium plans are coming soon. Today, every Lumoria account gets the full app for free.")
                .font(.body)
                .foregroundStyle(Color.Text.secondary)
        }
    }

    // MARK: - On state

    @ViewBuilder
    private var tierCard: some View {
        switch entitlement.tier {
        case .grandfathered:
            tierBlock(
                title: "Beta tester",
                body: "Premium is on the house, for life. Thanks for testing Lumoria."
            )
        case .lifetime:
            tierBlock(
                title: "Lifetime",
                body: "You bought Lumoria Lifetime. Premium stays unlocked forever."
            )
        case .subscriberInTrial(_, let exp):
            tierBlock(
                title: "Trial",
                body: "Free until \(exp.formatted(date: .abbreviated, time: .omitted))."
            )
        case .subscriber(let pid, let renews):
            let label = pid.contains("annual") ? "Annual" : "Monthly"
            tierBlock(
                title: label,
                body: "Renews \(renews.formatted(date: .abbreviated, time: .omitted))."
            )
        case .free:
            tierBlock(
                title: "Free",
                body: "Upgrade to unlock unlimited memories, tickets, the map suite, and more."
            )
        }
    }

    private func tierBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.bold())
            Text(body).font(.body).foregroundStyle(Color.Text.secondary)
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch entitlement.tier {
        case .free:
            Button {
                Paywall.present(
                    for: .premiumContent,
                    entitlement: entitlement,
                    state: paywallState
                )
            } label: {
                Text("See plans")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .subscriber, .subscriberInTrial:
            Link("Manage subscription",
                 destination: URL(string: "itms-apps://apps.apple.com/account/subscriptions")!)
                .font(.headline)
        case .lifetime, .grandfathered:
            EmptyView()
        }
    }

    // MARK: - Restore (always visible)

    private var restoreButton: some View {
        Button("Restore purchases") {
            Task { _ = await purchase.restore() }
        }
        .font(.footnote)
        .foregroundStyle(.tint)
    }
}
```

- [ ] **Step 2: Wire it into SettingsView**

Locate `placeholderView("Plan")` in `Lumoria App/views/settings/SettingsView.swift` and replace it. The exact site:

```swift
case .plan:
    placeholderView("Plan")
```

becomes:

```swift
case .plan:
    PlanManagementView(entitlement: entitlement)
```

You'll also need to add `@Environment(EntitlementStore.self) private var entitlement` to `SettingsView` if it isn't already there.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual smoke check (simulator, kill-switch OFF)**

Run the app in the sim. Settings → Plan should show "Premium coming soon" copy. No buy buttons. Restore link still visible.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/settings/PlanManagementView.swift" \
        "Lumoria App/views/settings/SettingsView.swift"
git commit -m "feat(settings): real Plan management — tier-driven UI + coming-soon when off"
```

---

### Task 9: Full-suite verification

- [ ] **Step 1: Run all Phase 1 + Phase 2 tests**

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:"Lumoria AppTests/ProfileDecodingTests" \
  -only-testing:"Lumoria AppTests/EntitlementStoreTests" \
  -only-testing:"Lumoria AppTests/EntitlementStoreMonetisationOffTests" \
  -only-testing:"Lumoria AppTests/CapLogicTests" \
  -only-testing:"Lumoria AppTests/AppSettingsServiceTests" \
  2>&1 | grep -E "\*\*" | tail -3
```

Expected: `** TEST SUCCEEDED **`. 17 tests total (2 + 5 + 3 + 6 + 1).

- [ ] **Step 2: Hand off**

Report total tests passing and that the kill-switch is OFF on the live DB. Phase 2 is then ready to merge to main.

---

## Self-Review

- **Spec coverage:**
  - Kill-switch addendum → Tasks 1, 2, 3, 8 (DB + AppSettingsService + EntitlementStore override + PlanManagementView coming-soon copy). ✓
  - Phase 2 build sequence: paywall view (Task 7), purchase flow (Task 6), Plan management (Task 8). ✓
  - `set_premium_from_transaction` RPC accepts client-passed Transaction fields per the spec (no JWS verification this phase). ✓
- **Placeholder scan:** No "TODO" / "TBD" / vague verbs in the steps. Each step has either real SQL, real Swift, or a real shell command.
- **Type consistency:** `AppSettings.monetisationEnabled` (camelCase iOS) ↔ `app_settings.monetisation_enabled` (snake_case DB). `PaywallPlan.rawValue` matches the StoreKit `productID`. `EntitlementStore.resolved(profile:monetisationEnabled:now:)` signature stays consistent across Tasks 3 + 9.
- **Ambiguity check:** "Replace `placeholderView("Plan")`" in Task 8 is unambiguous — Phase 1 left an exact match in SettingsView.
- **Kill-switch invariant:** flipping `app_settings.monetisation_enabled` from `false` → `true` is the **only** action required for legal go-live. No app rebuild, no migration, no policy change. Verified via Tasks 1 (cap triggers respect the flag), 1 (purchase RPC respects the flag), 3 (`hasPremium` short-circuits), 8 (Plan management swaps to tier-driven UI).

## Out of scope (Phase 2)

- Server-side ASSN2 webhook (Phase 5).
- Personalised hero variants per trigger (Phase 3).
- Invite-as-reward UI (Phase 4).
- App Store Server API transaction lookup (Phase 5).

## Phase 2 deliverable on completion

A build that, on a free non-grandfathered user with the kill-switch OFF (the default):
- Has no caps, no paywall, no observable difference from Phase 1.
- Can browse Settings → Plan and see "Premium coming soon".
- Has a working but inert PurchaseService — `purchase()` would call the RPC but the RPC raises `monetisation_disabled` so nothing changes.

When the developer flips `app_settings.monetisation_enabled` from `false` to `true`:
- Memory and ticket caps fire instantly (next insert).
- Paywall appears on every gated CTA for free users.
- Settings → Plan switches to tier-driven UI with a "See plans" CTA for free users.
- Purchases land via the RPC and write `is_premium` + `premium_expires_at` + product/transaction IDs to the profile row.
- The 1 grandfathered beta tester keeps Premium without doing anything.
