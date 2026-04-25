# Paywall Phase 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land all the plumbing required for Phases 2–4 — entitlement model, free-tier counters, server-side cap enforcement, invite-reward RPC, profile model extension — without shipping any user-visible UI yet.

**Architecture:** Single migration adds 6 columns to `profiles`, generalises the protect trigger, installs cap-enforcement triggers on `memories` and `tickets`, and adds the `claim_invite_reward` RPC. iOS gets an `EntitlementStore` (`@Observable`) that fuses the profile row with `Transaction.currentEntitlements`, a `PaywallTrigger` enum, and a `Paywall.present(for:)` helper that no-ops when premium is true. Memory and ticket creation entry points gate on `canCreate(entitlement:)` and route to a placeholder `PaywallView` when over cap.

**Tech Stack:** Supabase Postgres, Swift 6, SwiftUI, StoreKit 2, Swift Testing framework (`@Suite` / `@Test` / `#expect`), `mcp__supabase__apply_migration`.

**Reference:** [`docs/superpowers/specs/2026-04-25-paywall-and-monetisation-design.md`](../specs/2026-04-25-paywall-and-monetisation-design.md).

---

## File Structure

**Server (Supabase migrations):**
- Create: `supabase/migrations/20260505000000_grandfather_beta_testers.sql` — backfill of the already-applied grandfather migration so the repo matches the live DB. No new DB changes.
- Create: `supabase/migrations/20260506000000_paywall_phase_1_foundation.sql` — Phase 1 migration: profile columns, generalised protect trigger replacing `profiles_protect_grandfather`, cap-enforcement triggers on `memories` and `tickets`, `claim_invite_reward` RPC.

**iOS — services/entitlement (new module):**
- Create: `Lumoria App/services/entitlement/EntitlementTier.swift` — enum of user tiers.
- Create: `Lumoria App/services/entitlement/PaywallTrigger.swift` — enum + variant grouping.
- Create: `Lumoria App/services/entitlement/EntitlementStore.swift` — observable entitlement source of truth.
- Create: `Lumoria App/services/entitlement/PaywallPresenter.swift` — `Paywall.present(for:)` helper.

**iOS — paywall placeholder (new):**
- Create: `Lumoria App/views/paywall/PaywallView.swift` — placeholder UI; Phase 2 replaces this with the real layout.

**iOS — modified files:**
- Modify: `Lumoria App/services/onboarding/ProfileService.swift` — extend `Profile` struct with new columns.
- Modify: `Lumoria App/Lumoria_AppApp.swift` — instantiate and inject `EntitlementStore` into the env.
- Modify: `Lumoria App/views/collections/CollectionsStore.swift` — `canCreate(entitlement:) -> Bool` helper.
- Modify: `Lumoria App/views/tickets/TicketsStore.swift` — `canCreate(entitlement:) -> Bool` helper.
- Modify: callsites of `MemoriesStore.create` and `TicketsStore.create` (`NewMemoryView`, `NewTicketFunnelView` entry buttons) — gate on `canCreate(...)` before presenting the form; present `PaywallView` when over cap.

**iOS — tests:**
- Create: `Lumoria AppTests/EntitlementStoreTests.swift` — tier resolution + `hasPremium` from grandfather / StoreKit / lifetime / trial / free combinations.
- Create: `Lumoria AppTests/CapLogicTests.swift` — effective-cap math from `inviteRewardKind`.

**Local sandbox / docs:**
- Create: `Lumoria App/Configuration.storekit` — StoreKit testing file with the 3 products.
- Create: `docs/paywall/app-store-connect-checklist.md` — manual ASC steps for product / subscription group / intro offer setup.

---

### Task 1: Backfill the grandfather migration to the repo

The grandfather migration was applied via the Supabase MCP earlier in the session. The repo doesn't have the SQL file yet — files in `supabase/migrations/` should mirror what's live so anyone setting up a fresh project gets the same schema.

**Files:**
- Create: `supabase/migrations/20260505000000_grandfather_beta_testers.sql`

- [ ] **Step 1: Write the SQL file**

```sql
-- Beta-tester grandfathering. First 100 app sign-ups whose email is on
-- waitlist_subscribers get profiles.grandfathered_at stamped; the
-- timestamp grants lifetime free Premium without a StoreKit
-- subscription.
--
-- ALREADY APPLIED to the live DB via Supabase MCP on 2026-04-25.
-- This file is the repo-side record of that migration.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS grandfathered_at TIMESTAMPTZ;

WITH ranked AS (
  SELECT
    ws.supabase_user_id AS user_id,
    row_number() OVER (ORDER BY ws.created_at, ws.id) AS rn
  FROM public.waitlist_subscribers ws
  WHERE ws.supabase_user_id IS NOT NULL
)
UPDATE public.profiles p
   SET grandfathered_at = now()
  FROM ranked r
 WHERE p.user_id = r.user_id
   AND r.rn <= 100;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_count integer;
BEGIN
  INSERT INTO public.profiles (user_id) VALUES (NEW.id);

  PERFORM pg_advisory_xact_lock(hashtext('lumoria_grandfather_seat'));

  IF EXISTS (
    SELECT 1 FROM public.waitlist_subscribers
     WHERE supabase_user_id = NEW.id
  ) THEN
    SELECT count(*) INTO v_count
      FROM public.profiles
     WHERE grandfathered_at IS NOT NULL;

    IF v_count < 100 THEN
      UPDATE public.profiles
         SET grandfathered_at = now()
       WHERE user_id = NEW.id;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.profiles_protect_grandfather()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  IF current_user = 'authenticated'
     AND OLD.grandfathered_at IS DISTINCT FROM NEW.grandfathered_at
  THEN
    RAISE EXCEPTION 'grandfathered_at is read-only';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS profiles_protect_grandfather ON public.profiles;
CREATE TRIGGER profiles_protect_grandfather
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.profiles_protect_grandfather();
```

- [ ] **Step 2: Verify the file matches the live DB**

```bash
# Confirm the column exists in the live DB and matches the file.
# Use the Supabase MCP execute_sql tool against project vhozwnykphqujsiuwesi:
#   SELECT column_name FROM information_schema.columns
#   WHERE table_schema='public' AND table_name='profiles' AND column_name='grandfathered_at';
# Expected: 1 row returned.
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260505000000_grandfather_beta_testers.sql
git commit -m "chore(db): record grandfather migration in repo"
```

---

### Task 2: Phase 1 migration — DB schema, triggers, RPC

Single migration covering all server-side Phase 1 work. The `profiles_protect_grandfather` trigger from Task 1 gets replaced by `profiles_protect_managed_columns`.

**Files:**
- Create: `supabase/migrations/20260506000000_paywall_phase_1_foundation.sql`

- [ ] **Step 1: Write the SQL file**

```sql
-- Paywall Phase 1 foundation: profile columns for entitlement +
-- invite-reward, generalised protect trigger, cap-enforcement triggers
-- on memories and tickets, and the claim_invite_reward RPC.

-- 1. New profile columns.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_premium               boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS premium_expires_at       timestamptz NULL,
  ADD COLUMN IF NOT EXISTS premium_product_id       text NULL,
  ADD COLUMN IF NOT EXISTS premium_transaction_id   text NULL,
  ADD COLUMN IF NOT EXISTS invite_reward_kind       text NULL
    CHECK (invite_reward_kind IN ('memory','tickets')),
  ADD COLUMN IF NOT EXISTS invite_reward_claimed_at timestamptz NULL;

-- 2. Generalised protect trigger replaces profiles_protect_grandfather.
CREATE OR REPLACE FUNCTION public.profiles_protect_managed_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  IF current_user = 'authenticated' THEN
    IF OLD.grandfathered_at         IS DISTINCT FROM NEW.grandfathered_at
    OR OLD.is_premium               IS DISTINCT FROM NEW.is_premium
    OR OLD.premium_expires_at       IS DISTINCT FROM NEW.premium_expires_at
    OR OLD.premium_product_id       IS DISTINCT FROM NEW.premium_product_id
    OR OLD.premium_transaction_id   IS DISTINCT FROM NEW.premium_transaction_id
    OR OLD.invite_reward_kind       IS DISTINCT FROM NEW.invite_reward_kind
    OR OLD.invite_reward_claimed_at IS DISTINCT FROM NEW.invite_reward_claimed_at
    THEN
      RAISE EXCEPTION 'managed_column_readonly';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS profiles_protect_grandfather ON public.profiles;
DROP TRIGGER IF EXISTS profiles_protect_managed_columns ON public.profiles;
CREATE TRIGGER profiles_protect_managed_columns
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.profiles_protect_managed_columns();

-- 3. Memory cap trigger.
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
  SELECT grandfathered_at, is_premium, premium_expires_at, invite_reward_kind
    INTO v_grandfathered_at, v_is_premium, v_premium_expires, v_reward_kind
    FROM public.profiles
   WHERE user_id = NEW.user_id;

  -- Grandfather: no cap.
  IF v_grandfathered_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Active premium (lifetime, in-trial, or paid sub): no cap.
  IF v_is_premium AND
     (v_premium_expires IS NULL OR v_premium_expires > now())
  THEN
    RETURN NEW;
  END IF;

  -- Free tier: 3 base + 1 if invite reward is 'memory'.
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

DROP TRIGGER IF EXISTS enforce_memory_cap ON public.memories;
CREATE TRIGGER enforce_memory_cap
BEFORE INSERT ON public.memories
FOR EACH ROW
EXECUTE FUNCTION public.enforce_memory_cap();

-- 4. Ticket cap trigger.
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

DROP TRIGGER IF EXISTS enforce_ticket_cap ON public.tickets;
CREATE TRIGGER enforce_ticket_cap
BEFORE INSERT ON public.tickets
FOR EACH ROW
EXECUTE FUNCTION public.enforce_ticket_cap();

-- 5. claim_invite_reward RPC.
--
-- Eligibility uses claimed_by — the column populated by the existing
-- claim_invite RPC when a friend signs up via an invite link. Both the
-- inviter (inviter_id = me, claimed_by IS NOT NULL on at least one of
-- their invites) and the invitee (claimed_by = me on at least one
-- invite) can call this independently. The claim is one-shot per
-- profile: invite_reward_kind goes from NULL to 'memory' or 'tickets'
-- and stays that way.
CREATE OR REPLACE FUNCTION public.claim_invite_reward(p_kind text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_existing text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_kind NOT IN ('memory', 'tickets') THEN
    RAISE EXCEPTION 'invalid_kind' USING ERRCODE = '22P02';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.invites
     WHERE (inviter_id = v_uid AND claimed_by IS NOT NULL)
        OR claimed_by = v_uid
  ) THEN
    RAISE EXCEPTION 'no_claimed_invite' USING ERRCODE = 'P0001';
  END IF;

  SELECT invite_reward_kind INTO v_existing
    FROM public.profiles WHERE user_id = v_uid;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'already_claimed' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.profiles
     SET invite_reward_kind     = p_kind,
         invite_reward_claimed_at = now()
   WHERE user_id = v_uid;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.claim_invite_reward(text) TO authenticated;
```

- [ ] **Step 2: Apply via Supabase MCP**

Use `mcp__supabase__apply_migration` with `project_id="vhozwnykphqujsiuwesi"`, `name="paywall_phase_1_foundation"`, and `query` set to the file contents. Expected response: `{"success": true}`.

- [ ] **Step 3: Verify schema landed**

Use `mcp__supabase__execute_sql` with this query:

```sql
SELECT
  (SELECT count(*) FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles'
      AND column_name IN ('is_premium','premium_expires_at',
        'premium_product_id','premium_transaction_id',
        'invite_reward_kind','invite_reward_claimed_at')) AS new_columns,
  (SELECT count(*) FROM pg_trigger
    WHERE tgname IN ('profiles_protect_managed_columns',
      'enforce_memory_cap','enforce_ticket_cap')) AS new_triggers,
  (SELECT count(*) FROM pg_proc WHERE proname = 'claim_invite_reward') AS new_rpc;
```

Expected: `new_columns = 6`, `new_triggers = 3`, `new_rpc = 1`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260506000000_paywall_phase_1_foundation.sql
git commit -m "feat(db): paywall phase 1 — caps, protect trigger, claim_invite_reward RPC"
```

---

### Task 3: Extend Profile struct with new columns

**Files:**
- Modify: `Lumoria App/services/onboarding/ProfileService.swift`
- Test: `Lumoria AppTests/ProfileDecodingTests.swift` (new file)

- [ ] **Step 1: Write the failing test**

Create `Lumoria AppTests/ProfileDecodingTests.swift`:

```swift
import Foundation
import Testing
@testable import Lumoria_App

@Suite("Profile decoding")
struct ProfileDecodingTests {

    @Test("decodes a fully populated profile row from PostgREST JSON")
    func fullyPopulatedRow() throws {
        let json = """
        {
          "user_id": "11111111-1111-1111-1111-111111111111",
          "show_onboarding": false,
          "onboarding_step": "done",
          "grandfathered_at": "2026-04-25T13:21:22.989366+00:00",
          "is_premium": true,
          "premium_expires_at": "2027-04-25T00:00:00+00:00",
          "premium_product_id": "app.lumoria.premium.annual",
          "premium_transaction_id": "2000000000000001",
          "invite_reward_kind": "memory",
          "invite_reward_claimed_at": "2026-04-26T10:00:00+00:00"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let p = try decoder.decode(Profile.self, from: json)

        #expect(p.grandfatheredAt != nil)
        #expect(p.isPremium == true)
        #expect(p.premiumExpiresAt != nil)
        #expect(p.premiumProductId == "app.lumoria.premium.annual")
        #expect(p.premiumTransactionId == "2000000000000001")
        #expect(p.inviteRewardKind == .memory)
        #expect(p.inviteRewardClaimedAt != nil)
    }

    @Test("decodes a profile row with all paywall fields null/false")
    func unpaidProfile() throws {
        let json = """
        {
          "user_id": "22222222-2222-2222-2222-222222222222",
          "show_onboarding": true,
          "onboarding_step": "welcome",
          "grandfathered_at": null,
          "is_premium": false,
          "premium_expires_at": null,
          "premium_product_id": null,
          "premium_transaction_id": null,
          "invite_reward_kind": null,
          "invite_reward_claimed_at": null
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let p = try decoder.decode(Profile.self, from: json)

        #expect(p.grandfatheredAt == nil)
        #expect(p.isPremium == false)
        #expect(p.inviteRewardKind == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Build target: `Lumoria App` scheme, `Lumoria AppTests` test target. Run via:

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Lumoria AppTests/ProfileDecodingTests" \
  2>&1 | tail -20
```

Expected: build error or test failure complaining about missing `grandfatheredAt`/`isPremium`/`inviteRewardKind` etc. on `Profile`.

- [ ] **Step 3: Extend Profile struct**

Replace the `Profile` struct in `Lumoria App/services/onboarding/ProfileService.swift` with:

```swift
enum InviteRewardKind: String, Codable, Equatable, Sendable {
    case memory  = "memory"
    case tickets = "tickets"
}

struct Profile: Codable, Equatable, Sendable {
    let userId: UUID
    var showOnboarding: Bool
    var onboardingStep: OnboardingStep

    // Entitlement / paywall.
    var grandfatheredAt: Date?
    var isPremium: Bool
    var premiumExpiresAt: Date?
    var premiumProductId: String?
    var premiumTransactionId: String?

    // Invite reward (Phase 1 foundation; Phase 4 wires the UI).
    var inviteRewardKind: InviteRewardKind?
    var inviteRewardClaimedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId                = "user_id"
        case showOnboarding        = "show_onboarding"
        case onboardingStep        = "onboarding_step"
        case grandfatheredAt       = "grandfathered_at"
        case isPremium             = "is_premium"
        case premiumExpiresAt      = "premium_expires_at"
        case premiumProductId      = "premium_product_id"
        case premiumTransactionId  = "premium_transaction_id"
        case inviteRewardKind      = "invite_reward_kind"
        case inviteRewardClaimedAt = "invite_reward_claimed_at"
    }

    init(
        userId: UUID,
        showOnboarding: Bool,
        onboardingStep: OnboardingStep,
        grandfatheredAt: Date? = nil,
        isPremium: Bool = false,
        premiumExpiresAt: Date? = nil,
        premiumProductId: String? = nil,
        premiumTransactionId: String? = nil,
        inviteRewardKind: InviteRewardKind? = nil,
        inviteRewardClaimedAt: Date? = nil
    ) {
        self.userId = userId
        self.showOnboarding = showOnboarding
        self.onboardingStep = onboardingStep
        self.grandfatheredAt = grandfatheredAt
        self.isPremium = isPremium
        self.premiumExpiresAt = premiumExpiresAt
        self.premiumProductId = premiumProductId
        self.premiumTransactionId = premiumTransactionId
        self.inviteRewardKind = inviteRewardKind
        self.inviteRewardClaimedAt = inviteRewardClaimedAt
    }
}
```

The existing `ProfileService.fetch()` uses `.select()` (no column list), which expands to `select=*`. New columns are returned automatically — no change required there.

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Lumoria AppTests/ProfileDecodingTests" \
  2>&1 | tail -20
```

Expected: 2 tests passed.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/services/onboarding/ProfileService.swift" \
        "Lumoria AppTests/ProfileDecodingTests.swift"
git commit -m "feat(profile): add entitlement and invite-reward columns to Profile"
```

---

### Task 4: EntitlementTier enum

Tiers used for routing UI (Plan management copy, paywall variant trial-vs-no-trial).

**Files:**
- Create: `Lumoria App/services/entitlement/EntitlementTier.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  EntitlementTier.swift
//  Lumoria App
//
//  What kind of access the user has. Drives the Plan management screen
//  copy and the paywall trial-vs-no-trial variant choice.
//

import Foundation

enum EntitlementTier: Equatable, Sendable {
    case grandfathered
    case lifetime
    case subscriberInTrial(productId: String, expiresAt: Date)
    case subscriber(productId: String, renewsAt: Date)
    case free

    var hasPremium: Bool {
        switch self {
        case .grandfathered, .lifetime, .subscriberInTrial, .subscriber:
            return true
        case .free:
            return false
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "Lumoria App/services/entitlement/EntitlementTier.swift"
git commit -m "feat(entitlement): add EntitlementTier enum"
```

---

### Task 5: PaywallTrigger enum + variant grouping

Identifies which gated CTA fired and which of the 4 hero variants to render. Phase 1 only uses `.memoryLimit` and `.ticketLimit` (the cap gates); the others are wired in later phases but defined now so signatures are stable.

**Files:**
- Create: `Lumoria App/services/entitlement/PaywallTrigger.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  PaywallTrigger.swift
//  Lumoria App
//
//  Identifies the entry point that opened the paywall. Maps to one of
//  the four personalised hero variants (Q5 = B grouping in the spec).
//  Also drives the analytics `paywallViewed(source:)` property.
//

import Foundation

enum PaywallTrigger: String, Equatable, Sendable {
    // Free-tier counters.
    case memoryLimit  = "memory_limit"
    case ticketLimit  = "ticket_limit"

    // Map suite (Phase 2/3).
    case timelineLocked = "timeline_locked"
    case mapExportLocked = "map_export_locked"

    // Premium content (Phase 2/3).
    case publicTransportCategory = "public_transport_category"
    case placeholderCategory     = "placeholder_category"
    case paidTemplate            = "paid_template"
    case styleCustomisation      = "style_customisation"
    case pkpassImport            = "pkpass_import"
    case stickerPack             = "sticker_pack"

    /// One of four hero variants to render.
    enum Variant: String, Equatable, Sendable {
        case memoryLimit
        case ticketLimit
        case mapSuite
        case premiumContent
    }

    var variant: Variant {
        switch self {
        case .memoryLimit:
            return .memoryLimit
        case .ticketLimit:
            return .ticketLimit
        case .timelineLocked, .mapExportLocked:
            return .mapSuite
        case .publicTransportCategory,
             .placeholderCategory,
             .paidTemplate,
             .styleCustomisation,
             .pkpassImport,
             .stickerPack:
            return .premiumContent
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "Lumoria App/services/entitlement/PaywallTrigger.swift"
git commit -m "feat(entitlement): add PaywallTrigger enum + variant grouping"
```

---

### Task 6: EntitlementStore — observable source of truth

Subscribes to `Transaction.updates`, fuses StoreKit state with the cached Profile row, exposes `hasPremium`, `tier`, `trialAvailable`, and `inviteRewardKind`. Phase 1 builds the read side only — the write side (`set_premium_from_transaction` after a purchase) ships in Phase 2 along with the buy flow.

**Files:**
- Create: `Lumoria App/services/entitlement/EntitlementStore.swift`
- Test: `Lumoria AppTests/EntitlementStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Lumoria AppTests/EntitlementStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import Lumoria_App

@Suite("EntitlementStore tier resolution")
struct EntitlementStoreTests {

    private func profile(
        grandfathered: Bool = false,
        isPremium: Bool = false,
        expires: Date? = nil,
        productId: String? = nil
    ) -> Profile {
        Profile(
            userId: UUID(),
            showOnboarding: false,
            onboardingStep: .done,
            grandfatheredAt: grandfathered ? Date() : nil,
            isPremium: isPremium,
            premiumExpiresAt: expires,
            premiumProductId: productId,
            premiumTransactionId: nil,
            inviteRewardKind: nil,
            inviteRewardClaimedAt: nil
        )
    }

    @Test("grandfathered profile resolves to .grandfathered")
    func grandfathered() {
        let t = EntitlementStore.tier(
            for: profile(grandfathered: true),
            now: Date()
        )
        #expect(t == .grandfathered)
    }

    @Test("lifetime product resolves to .lifetime")
    func lifetime() {
        let t = EntitlementStore.tier(
            for: profile(isPremium: true, expires: nil,
                         productId: "app.lumoria.premium.lifetime"),
            now: Date()
        )
        #expect(t == .lifetime)
    }

    @Test("annual sub with future expiry resolves to .subscriber")
    func subscriber() {
        let exp = Date().addingTimeInterval(60 * 60 * 24 * 30)
        let t = EntitlementStore.tier(
            for: profile(isPremium: true, expires: exp,
                         productId: "app.lumoria.premium.annual"),
            now: Date()
        )
        if case let .subscriber(productId, renewsAt) = t {
            #expect(productId == "app.lumoria.premium.annual")
            #expect(renewsAt == exp)
        } else {
            Issue.record("expected .subscriber, got \(t)")
        }
    }

    @Test("expired sub falls back to .free")
    func expired() {
        let t = EntitlementStore.tier(
            for: profile(isPremium: true,
                         expires: Date().addingTimeInterval(-10),
                         productId: "app.lumoria.premium.monthly"),
            now: Date()
        )
        #expect(t == .free)
    }

    @Test("no premium, no grandfather resolves to .free")
    func free() {
        let t = EntitlementStore.tier(for: profile(), now: Date())
        #expect(t == .free)
    }
}
```

The `subscriberInTrial` case is StoreKit-driven and tested via the StoreKit framework's own `Transaction` mock; we'll cover it in an integration test in Phase 2 when the purchase flow lands.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Lumoria AppTests/EntitlementStoreTests" \
  2>&1 | tail -20
```

Expected: build error — `EntitlementStore.tier(for:now:)` does not exist yet.

- [ ] **Step 3: Write EntitlementStore**

Create `Lumoria App/services/entitlement/EntitlementStore.swift`:

```swift
//
//  EntitlementStore.swift
//  Lumoria App
//
//  Single source of truth for "is this user Premium". Fuses the
//  Supabase profile row (grandfather + DB-mirrored subscription state)
//  with the iOS-side StoreKit transaction stream.
//
//  Phase 1: read side only. Phase 2 adds the write side
//  (`set_premium_from_transaction` RPC call after a verified purchase).
//

import Foundation
import StoreKit
import Observation

/// Lifetime product identifier (no expiry semantic).
private let kLifetimeProductId = "app.lumoria.premium.lifetime"
private let kMonthlyProductId  = "app.lumoria.premium.monthly"
private let kAnnualProductId   = "app.lumoria.premium.annual"

@MainActor
@Observable
final class EntitlementStore {

    private(set) var tier: EntitlementTier = .free
    private(set) var trialAvailable: Bool = false
    private(set) var inviteRewardKind: InviteRewardKind? = nil

    private var transactionListener: Task<Void, Never>? = nil
    private let profileService: ProfileServicing

    init(profileService: ProfileServicing) {
        self.profileService = profileService
        self.transactionListener = Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refresh()
            }
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    var hasPremium: Bool { tier.hasPremium }

    /// Pull the latest profile row + StoreKit state. Call on app launch,
    /// after sign-in, after a successful purchase, and after a manual
    /// "Restore purchases" tap.
    func refresh() async {
        do {
            let profile = try await profileService.fetch()
            let now = Date()
            self.tier = Self.tier(for: profile, now: now)
            self.inviteRewardKind = profile.inviteRewardKind
        } catch {
            // No profile row → treat as free until we have one. Don't
            // surface the error here; the caller's auth flow handles it.
            self.tier = .free
            self.inviteRewardKind = nil
        }
        await refreshTrialAvailability()
    }

    /// Pure tier-resolution helper. Exposed for testing.
    static func tier(for profile: Profile, now: Date) -> EntitlementTier {
        if profile.grandfatheredAt != nil {
            return .grandfathered
        }
        if profile.isPremium {
            // Lifetime: no expiry.
            if profile.premiumExpiresAt == nil {
                return .lifetime
            }
            // Active sub.
            if let exp = profile.premiumExpiresAt, exp > now {
                let pid = profile.premiumProductId ?? kAnnualProductId
                return .subscriber(productId: pid, renewsAt: exp)
            }
            // Expired sub: fall through to .free.
        }
        return .free
    }

    private func refreshTrialAvailability() async {
        do {
            let products = try await Product.products(
                for: [kMonthlyProductId, kAnnualProductId]
            )
            var anyEligible = false
            for product in products {
                guard let status = try? await product.subscription?.status,
                      let firstStatus = status.first
                else { continue }
                let info = try firstStatus.transaction.payloadValue
                // If the user has *no* prior transaction in this group,
                // they're eligible for the intro offer. Apple flags this
                // via `Product.SubscriptionInfo.isEligibleForIntroOffer`.
                _ = info
                if let isEligible = await product.subscription?
                    .isEligibleForIntroOffer
                {
                    if isEligible { anyEligible = true }
                }
            }
            self.trialAvailable = anyEligible
        } catch {
            self.trialAvailable = false
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Lumoria AppTests/EntitlementStoreTests" \
  2>&1 | tail -20
```

Expected: 5 tests passed.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/services/entitlement/EntitlementStore.swift" \
        "Lumoria AppTests/EntitlementStoreTests.swift"
git commit -m "feat(entitlement): add EntitlementStore with tier resolution + StoreKit listener"
```

---

### Task 7: PaywallPresenter — `Paywall.present(for:)` helper

Single entry point every gated CTA calls. No-ops when `entitlement.hasPremium == true`. Otherwise presents `PaywallView(trigger:)`.

**Files:**
- Create: `Lumoria App/services/entitlement/PaywallPresenter.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  PaywallPresenter.swift
//  Lumoria App
//
//  `Paywall.present(for:)` is the single entry point every gated CTA
//  calls. Skips presentation when the user already has Premium.
//

import SwiftUI

enum Paywall {

    /// Whether the paywall sheet is currently presented. Bound from the
    /// app root via `@Bindable`. Phase 1 keeps this simple (one global
    /// presentation state); Phase 2 may evolve it if multiple paywall
    /// entry points need to coexist.
    @MainActor
    @Observable
    final class PresentationState {
        var trigger: PaywallTrigger? = nil
        var isPresented: Bool {
            get { trigger != nil }
            set { if !newValue { trigger = nil } }
        }
    }

    /// Present the paywall for the given trigger. Returns immediately
    /// (no-op) when the user is already Premium.
    @MainActor
    static func present(
        for trigger: PaywallTrigger,
        entitlement: EntitlementStore,
        state: PresentationState
    ) {
        guard !entitlement.hasPremium else { return }
        state.trigger = trigger
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "Lumoria App/services/entitlement/PaywallPresenter.swift"
git commit -m "feat(entitlement): add Paywall.present(for:) helper"
```

---

### Task 8: Placeholder PaywallView

Phase 2 ships the real layout (plan card, MonthTag, hero variants). For Phase 1, a minimal placeholder so the gate has something to present.

**Files:**
- Create: `Lumoria App/views/paywall/PaywallView.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  PaywallView.swift
//  Lumoria App
//
//  Phase 1 placeholder. Phase 2 replaces this with the real plan-card +
//  hero-variant layout per the design spec.
//

import SwiftUI

struct PaywallView: View {
    let trigger: PaywallTrigger
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Premium")
                .font(.largeTitle.bold())
            Text(headline)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("Phase 2 ships the real paywall here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }

    private var headline: String {
        switch trigger.variant {
        case .memoryLimit:    return "Unlimited memories with Premium."
        case .ticketLimit:    return "Unlimited tickets with Premium."
        case .mapSuite:       return "Timeline + map export with Premium."
        case .premiumContent: return "The full catalogue with Premium."
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "Lumoria App/views/paywall/PaywallView.swift"
git commit -m "feat(paywall): placeholder PaywallView (Phase 2 ships real one)"
```

---

### Task 9: Inject EntitlementStore + paywall sheet at the app root

**Files:**
- Modify: `Lumoria App/Lumoria_AppApp.swift` (verify the actual filename — may be slightly different; the entry-point `@main`-marked App struct).

- [ ] **Step 1: Locate the @main App struct**

```bash
grep -l "@main" "Lumoria App"/*.swift
```

Expected output: a single file path (likely `Lumoria App/Lumoria_AppApp.swift` based on Xcode default naming).

- [ ] **Step 2: Add EntitlementStore + presentation state instances**

Inside the `@main` App struct, add:

```swift
@State private var entitlement = EntitlementStore(
    profileService: ProfileService()
)
@State private var paywallState = Paywall.PresentationState()
```

- [ ] **Step 3: Inject into env + present sheet at root**

Wrap the root scene's content in:

```swift
WindowGroup {
    RootContent()
        .environment(entitlement)
        .environment(paywallState)
        .sheet(isPresented: Binding(
            get: { paywallState.isPresented },
            set: { paywallState.isPresented = $0 }
        )) {
            if let trigger = paywallState.trigger {
                PaywallView(trigger: trigger)
            }
        }
        .task {
            await entitlement.refresh()
        }
}
```

(Replace `RootContent` with the actual existing root view name — likely `ContentView`.)

- [ ] **Step 4: Build to verify it compiles**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/Lumoria_AppApp.swift"
git commit -m "feat(entitlement): wire EntitlementStore + paywall sheet at app root"
```

---

### Task 10: MemoriesStore.canCreate gate

**Files:**
- Modify: `Lumoria App/views/collections/CollectionsStore.swift`
- Test: `Lumoria AppTests/CapLogicTests.swift` (new file)

- [ ] **Step 1: Write the failing test**

Create `Lumoria AppTests/CapLogicTests.swift`:

```swift
import Foundation
import Testing
@testable import Lumoria_App

@Suite("Free-tier cap math")
struct CapLogicTests {

    @Test("memory cap is 3 by default")
    func memoryDefault() {
        #expect(FreeCaps.memoryCap(rewardKind: nil) == 3)
    }

    @Test("memory cap is 4 when invite reward is memory")
    func memoryWithReward() {
        #expect(FreeCaps.memoryCap(rewardKind: .memory) == 4)
    }

    @Test("memory cap is 3 when invite reward is tickets")
    func memoryWithTicketReward() {
        #expect(FreeCaps.memoryCap(rewardKind: .tickets) == 3)
    }

    @Test("ticket cap is 5 by default")
    func ticketDefault() {
        #expect(FreeCaps.ticketCap(rewardKind: nil) == 5)
    }

    @Test("ticket cap is 7 when invite reward is tickets")
    func ticketWithReward() {
        #expect(FreeCaps.ticketCap(rewardKind: .tickets) == 7)
    }

    @Test("ticket cap is 5 when invite reward is memory")
    func ticketWithMemoryReward() {
        #expect(FreeCaps.ticketCap(rewardKind: .memory) == 5)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Lumoria AppTests/CapLogicTests" \
  2>&1 | tail -20
```

Expected: build error — `FreeCaps` type does not exist.

- [ ] **Step 3: Add FreeCaps + canCreate**

Append to `Lumoria App/services/entitlement/EntitlementStore.swift` (or in a sibling file `FreeCaps.swift` — same module):

```swift
//
//  FreeCaps — free-tier counter math. Mirrors the SQL trigger logic in
//  20260506000000_paywall_phase_1_foundation.sql. Keep both in sync.
//

enum FreeCaps {
    static let baseMemoryCap = 3
    static let memoryRewardBonus = 1

    static let baseTicketCap = 5
    static let ticketRewardBonus = 2

    static func memoryCap(rewardKind: InviteRewardKind?) -> Int {
        baseMemoryCap + (rewardKind == .memory ? memoryRewardBonus : 0)
    }

    static func ticketCap(rewardKind: InviteRewardKind?) -> Int {
        baseTicketCap + (rewardKind == .tickets ? ticketRewardBonus : 0)
    }
}
```

Then in `Lumoria App/views/collections/CollectionsStore.swift`, add a method below `create(...)`:

```swift
/// Whether the user can create another memory under the free-tier cap.
/// Premium / grandfathered / lifetime / active subscriber → always true.
func canCreate(entitlement: EntitlementStore) -> Bool {
    if entitlement.hasPremium { return true }
    let cap = FreeCaps.memoryCap(rewardKind: entitlement.inviteRewardKind)
    return memories.count < cap
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Lumoria AppTests/CapLogicTests" \
  2>&1 | tail -20
```

Expected: 6 tests passed.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/services/entitlement/EntitlementStore.swift" \
        "Lumoria App/views/collections/CollectionsStore.swift" \
        "Lumoria AppTests/CapLogicTests.swift"
git commit -m "feat(memories): add canCreate gate honoring invite reward bonus"
```

---

### Task 11: TicketsStore.canCreate gate

Same pattern as Task 10, applied to tickets.

**Files:**
- Modify: `Lumoria App/views/tickets/TicketsStore.swift`

- [ ] **Step 1: Add canCreate**

In `Lumoria App/views/tickets/TicketsStore.swift`, alongside the existing `create(...)` method:

```swift
/// Whether the user can create another ticket under the free-tier cap.
/// Premium / grandfathered / lifetime / active subscriber → always true.
func canCreate(entitlement: EntitlementStore) -> Bool {
    if entitlement.hasPremium { return true }
    let cap = FreeCaps.ticketCap(rewardKind: entitlement.inviteRewardKind)
    return tickets.count < cap
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/views/tickets/TicketsStore.swift"
git commit -m "feat(tickets): add canCreate gate honoring invite reward bonus"
```

---

### Task 12: Wire memory-creation entry points to the gate

Locate every UI entry that opens the new-memory form. For each one, gate on `memoriesStore.canCreate(entitlement:)` before navigating; if false, call `Paywall.present(for: .memoryLimit, entitlement:, state:)` instead.

**Files (likely candidates — verify with grep):**
- Modify: `Lumoria App/views/collections/CollectionsView.swift` — the "+" / "New memory" button handler.
- Modify: `Lumoria App/views/collections/NewCollectionView.swift` — if it auto-presents on tab open or has a confirm step.

- [ ] **Step 1: Locate the entry points**

```bash
grep -rn "NewMemoryView\|NewCollectionView\|createMemory\|presentNewMemory" "Lumoria App"/views --include='*.swift'
```

Note each file:line where a new-memory presentation is initiated.

- [ ] **Step 2: Wrap each entry point**

Pattern to apply at every located callsite — replace any direct `isShowingNewMemorySheet = true` (or equivalent) with:

```swift
if memoriesStore.canCreate(entitlement: entitlement) {
    isShowingNewMemorySheet = true
} else {
    Paywall.present(
        for: .memoryLimit,
        entitlement: entitlement,
        state: paywallState
    )
}
```

Add the required environment dependencies at the top of each modified view:

```swift
@Environment(EntitlementStore.self) private var entitlement
@Environment(Paywall.PresentationState.self) private var paywallState
```

- [ ] **Step 3: Build to verify it compiles**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual smoke test (simulator)**

Run the app in a sandbox simulator with a fresh non-grandfathered account. Create 3 memories. Tap "+" again — paywall placeholder should appear with "Unlimited memories with Premium." headline. Close it; the app should be in a clean state.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/collections/"
git commit -m "feat(memories): gate new-memory entry points on free-tier cap"
```

---

### Task 13: Wire ticket-creation entry points to the gate

Same as Task 12, applied to tickets.

**Files (likely candidates):**
- Modify: `Lumoria App/views/tickets/AllTicketsView.swift` — the "+" handler.
- Modify: `Lumoria App/views/collections/CollectionDetailView.swift` — the new "+" button next to the map / ⋯ icons (added in the *Memory + button* changelog).

- [ ] **Step 1: Locate the entry points**

```bash
grep -rn "NewTicketFunnel\|presentNewTicket\|isShowingNewTicket" "Lumoria App"/views --include='*.swift'
```

- [ ] **Step 2: Wrap each entry point**

```swift
if ticketsStore.canCreate(entitlement: entitlement) {
    isShowingNewTicketSheet = true
} else {
    Paywall.present(
        for: .ticketLimit,
        entitlement: entitlement,
        state: paywallState
    )
}
```

Add the required env dependencies at the top of each modified view:

```swift
@Environment(EntitlementStore.self) private var entitlement
@Environment(Paywall.PresentationState.self) private var paywallState
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual smoke test**

Sandbox sim, fresh account. Create 5 tickets. Tap "+" again — paywall placeholder with "Unlimited tickets with Premium." headline.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/tickets/" "Lumoria App/views/collections/CollectionDetailView.swift"
git commit -m "feat(tickets): gate new-ticket entry points on free-tier cap"
```

---

### Task 14: Configuration.storekit — local sandbox products

Phase 1 doesn't sell anything yet, but having the config file in place lets developers test entitlement flows in the simulator (StoreKit Configuration in the scheme) before Phase 2 lands.

**Files:**
- Create: `Lumoria App/Configuration.storekit`

- [ ] **Step 1: Write the file**

In Xcode: File → New → File → StoreKit Configuration File. Name it `Configuration` and place it under `Lumoria App/`. Add three products via the GUI, OR paste this JSON directly into the file (Xcode parses both):

```json
{
  "identifier": "16E5D9F3-A5C0-4D7B-9C8E-2F0E0E1C6A55",
  "nonRenewingSubscriptions": [],
  "products": [
    {
      "displayPrice": "59.99",
      "familyShareable": true,
      "internalID": "0001",
      "localizations": [
        {
          "description": "Premium for life — pay once.",
          "displayName": "Lumoria Lifetime",
          "locale": "en_US"
        }
      ],
      "productID": "app.lumoria.premium.lifetime",
      "referenceName": "Lifetime",
      "type": "NonConsumable"
    }
  ],
  "settings": {
    "_failTransactionsEnabled": false,
    "_locale": "en_US",
    "_storefront": "USA",
    "_storeKitErrors": []
  },
  "subscriptionGroups": [
    {
      "id": "21000000",
      "localizations": [],
      "name": "Lumoria Premium",
      "subscriptions": [
        {
          "adHocOffers": [],
          "codeOffers": [],
          "displayPrice": "3.99",
          "familyShareable": true,
          "groupNumber": 1,
          "internalID": "1001",
          "introductoryOffer": {
            "internalID": "introMonthly",
            "paymentMode": "free",
            "subscriptionPeriod": "P14D"
          },
          "localizations": [
            {
              "description": "Premium, billed monthly.",
              "displayName": "Lumoria Monthly",
              "locale": "en_US"
            }
          ],
          "productID": "app.lumoria.premium.monthly",
          "recurringSubscriptionPeriod": "P1M",
          "referenceName": "Monthly",
          "subscriptionGroupID": "21000000",
          "type": "RecurringSubscription"
        },
        {
          "adHocOffers": [],
          "codeOffers": [],
          "displayPrice": "24.99",
          "familyShareable": true,
          "groupNumber": 2,
          "internalID": "1002",
          "introductoryOffer": {
            "internalID": "introAnnual",
            "paymentMode": "free",
            "subscriptionPeriod": "P14D"
          },
          "localizations": [
            {
              "description": "Premium, billed annually.",
              "displayName": "Lumoria Annual",
              "locale": "en_US"
            }
          ],
          "productID": "app.lumoria.premium.annual",
          "recurringSubscriptionPeriod": "P1Y",
          "referenceName": "Annual",
          "subscriptionGroupID": "21000000",
          "type": "RecurringSubscription"
        }
      ]
    }
  ],
  "version": {
    "major": 4,
    "minor": 0
  }
}
```

- [ ] **Step 2: Add the file to the Xcode project**

In Xcode, drag `Configuration.storekit` into the project navigator under the `Lumoria App` group. Make sure the file is added to the `Lumoria App` target (the file uses Xcode's StoreKit Configuration format).

- [ ] **Step 3: Wire the file into the run scheme**

Edit Scheme → Run → Options → StoreKit Configuration → select `Configuration.storekit`.

- [ ] **Step 4: Verify**

Run the app on the simulator. Open Xcode's Debug → StoreKit menu — the three products should be listed.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/Configuration.storekit"
git commit -m "chore(storekit): local sandbox config with 3 paywall products"
```

---

### Task 15: App Store Connect manual checklist

ASC setup is a manual UI process — document the steps so anyone can replicate them.

**Files:**
- Create: `docs/paywall/app-store-connect-checklist.md`

- [ ] **Step 1: Write the file**

```markdown
# App Store Connect — Paywall product setup

Manual one-time setup in App Store Connect for the three paywall
products. Mirror these in `Lumoria App/Configuration.storekit` for
local sandbox testing.

## 1. Create the subscription group

- App Store Connect → Apps → Lumoria → In-App Purchases.
- Click **+** next to **Subscription Groups**.
- Name: `Lumoria Premium`. Save.

## 2. Create monthly subscription

- Subscription Groups → Lumoria Premium → click **+** under
  **Subscriptions**.
- Reference Name: `Monthly`.
- Product ID: `app.lumoria.premium.monthly`.
- Subscription duration: `1 Month`.
- Pricing: $3.99 USD (Apple's price tier ~Tier 4 — verify the current
  tier mapping; pricing for other regions auto-fills).
- Family Sharing: **enabled**.
- Add an **Introductory Offer**:
  - Type: **Free**.
  - Duration: **2 weeks**.
  - Eligibility: New subscribers only.
- Localisation (English, US):
  - Display Name: `Lumoria Monthly`.
  - Description: `Premium, billed monthly.`
- Save.

## 3. Create annual subscription

Same as monthly, with:

- Reference Name: `Annual`.
- Product ID: `app.lumoria.premium.annual`.
- Subscription duration: `1 Year`.
- Pricing: $24.99 USD.
- Same 2-week free intro offer.

## 4. Create lifetime non-consumable

- App Store Connect → In-App Purchases → click **+**.
- Type: **Non-Consumable**.
- Reference Name: `Lifetime`.
- Product ID: `app.lumoria.premium.lifetime`.
- Pricing: $59.99 USD.
- Family Sharing: **enabled**.
- Localisation (English, US):
  - Display Name: `Lumoria Lifetime`.
  - Description: `Premium for life — pay once.`
- No intro offer (StoreKit doesn't allow trials on non-consumables).

## 5. Submit for review with Phase 2 ship

The products are status `Ready to Submit` until they land in a build
that uses them. Ship Phase 2's purchase flow, then submit alongside
the binary that references them.
```

- [ ] **Step 2: Commit**

```bash
git add docs/paywall/app-store-connect-checklist.md
git commit -m "docs(paywall): App Store Connect product setup checklist"
```

---

## Self-Review

Walking the spec section-by-section against the plan:

- **Section A (Entitlement model)** — Tasks 4 (`EntitlementTier`), 6 (`EntitlementStore`), 9 (env injection). ✓
- **Section B (Free-tier limits + invite reward)** — Tasks 2 (cap triggers + RPC), 10 + 11 (`canCreate`), 12 + 13 (callsite gates). ✓ ASSN2 + `set_premium_from_transaction` deferred to Phase 2 plan as documented in the spec. ✓
- **Section C (StoreKit + Plan management)** — Task 14 (Configuration.storekit), Task 15 (ASC checklist). Plan management screen + purchase flow ship in Phase 2. ✓
- **Section D (Paywall UI)** — Task 5 (`PaywallTrigger`), Task 7 (`Paywall.present`), Task 8 (placeholder view). Real layout ships in Phase 2. ✓
- **Section E (Database changes)** — Tasks 1 (grandfather backfill) + 2 (Phase 1 migration). ✓
- **Section F (Phase 1 only)** — every Phase 1 line item has a task. ✓

No placeholder text. Type / property names consistent across tasks (`InviteRewardKind`, `EntitlementTier`, `PaywallTrigger.Variant`). SQL column names match the live `invites` schema (`inviter_id`, `claimed_by`, `claimed_at`).

Phase 1 deliverable on completion: a build that fetches the new profile columns, has working entitlement plumbing, blocks free users at the 3-memory / 5-ticket cap with a placeholder paywall, and has 3 sandbox products available for local StoreKit testing. No money is taken; no user-visible UI changes beyond the placeholder paywall sheet.
