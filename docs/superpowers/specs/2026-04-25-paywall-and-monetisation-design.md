# Paywall & Monetisation — Design

**Status:** Design approved 2026-04-25. Writing-plans skill invoked next for implementation plan.

**Author:** Brainstormed with Claude (Opus 4.7).

## Goal

Lumoria is going from a TestFlight beta to a paid product. This spec covers every piece of plumbing required to take the app from "everything is free" to "free tier with limits + Premium subscription + lifetime + 14-day trial + grandfathered beta testers + invite-as-reward". Foundation-first build sequence.

## Decisions locked during brainstorm

### Clarifications

1. **Invite reward mechanic** — one-shot per profile. Inviter and invitee each get one independent reward (memory or tickets, their own pick). Doesn't stack with future invites.
2. **Free trial mechanism** — StoreKit-managed (Apple's intro offer). One free trial per Apple ID family per subscription group. Server doesn't track trial state.
3. **Pricing trio:**
   - Monthly: **$3.99**
   - Annual: **$24.99** (≈ 48% off vs paying monthly)
   - Lifetime: **$59.99** (≈ 2.4× annual)
4. **Paid feature list** — bolded items in the Notion Features page, summarised under § Paid features below.
5. **Paywall personalisation** — 4 grouped variants (memoryLimit / ticketLimit / mapSuite / premiumContent), each with its own hero block. Body of the paywall (plan card, CTA, trust copy) is shared across variants.
6. **Build sequence** — foundation-first: entitlement plumbing + counters + DB triggers before any UI.

### Architectural picks

1. **Counter enforcement** — client + server. Client gate for UX (instant paywall presentation), Postgres BEFORE INSERT trigger as the actual enforcement so a malicious client can't bypass.
2. **Invite reward claim timing** — claim anytime via Invite settings banner. No forced modal at the moment a friend redeems.

### Beta-tester grandfather (already shipped this session)

Migration `grandfather_beta_testers` already applied to the `Website` Supabase project:
- `profiles.grandfathered_at TIMESTAMPTZ` added.
- `handle_new_user()` extended to atomically grandfather new sign-ups whose email is on `waitlist_subscribers`, capped at 100 lifetime seats with an advisory lock.
- Backfill stamped 1 already-signed-up user. 99 seats remain.
- `profiles_protect_grandfather` trigger blocks clients from setting the column themselves.

This trigger will be replaced by a generalised `profiles_protect_managed_columns` in Phase 1 — same semantics, broader column coverage.

## Free tier, paid features, and limits

### Free (always available)

- Categories: **Plane, Train, Concert** (Public Transport is paid in full).
- Templates: 2 free per category — Plane (Afterglow, Studio), Train (Post, Glow), Concert (the only one).
- Multi-step creation flow, orientation toggle, edit, resume draft, auto-fill.
- Smart location fields (airport / station / venue search).
- Memories: emoji + colour, **optional dates**, map view, stats card, multi-continent framing, group add to memory, quick + button.
- All Tickets library, ticket detail, edit / delete.
- Multiple social formats for ticket export (Instagram story, TikTok vertical, Instagram feed 1:1 & vertical, Facebook, X/Twitter).
- Throwback memories push notifications + granular notification settings.
- Settings: Profile, Appearance, Map preferences, Plan management, Invite, Help Center.
- Onboarding tutorial + resume.
- **3 memories** (4 with invite reward), **5 tickets** (7 with invite reward).

### Paid (Premium only)

- **Public Transport category in full** — all 3 templates (Sign, Infoscreen, Signal) + the routing engine + the 3 cities (Vienna / NYC / Paris).
- **6 placeholder categories** — Event, Food, Movie, Museum, Sport, Parks & Gardens (paid by default once their templates ship).
- **Style customisation** — changing how a ticket looks per template.
- **PKPass import** — bringing Apple Wallet passes into Lumoria.
- **Plane templates** — Heritage, Prism, Terminal.
- **Train templates** — Express, Night, Orient.
- **Memory timeline** — story-mode scrub through a trip.
- **Memory map export** — share map as image with selectable backgrounds.
- **iOS sticker pack** — sending tickets as Messages stickers.
- **Unlimited memories + tickets**.

## Architecture

### Section A — Entitlement model

Single source of truth: `EntitlementStore` (`@Observable final class`) injected via environment, lives in `services/entitlement/`.

**Inputs:**

1. `profile.grandfathered_at` (Supabase) — non-null = lifetime free Premium.
2. `Transaction.currentEntitlements` (StoreKit 2) — active monthly/annual subscription, or owned lifetime non-consumable.
3. `Product.SubscriptionInfo.Status` (StoreKit 2) — exposes `RenewalState` and `isEligibleForIntroOffer` per product.

**Outputs:**

- `hasPremium: Bool` — what every gate calls.
- `tier: EntitlementTier` enum — `.grandfathered` | `.lifetime` | `.subscriberInTrial` | `.subscriber` | `.free` — drives Plan management copy and trial-aware paywall variants.
- `trialAvailable: Bool` — derived from `isEligibleForIntroOffer` OR'd across the two subscription products. Drives the trial-vs-no-trial paywall variant choice.

**Lifecycle:**

- Listens to `Transaction.updates` async stream → auto-reacts when a subscription starts, renews, expires, or refunds. No manual polling.
- On app launch, refreshes from StoreKit + re-fetches the profile row.
- After a successful sign-up, manually refreshes the profile (so a freshly grandfathered user gets `hasPremium = true` instantly).

**Profile fetch extension:**

- `ProfileService.Profile` currently has `userId / showOnboarding / onboardingStep`.
- Add `grandfatheredAt: Date?`, `isPremium: Bool`, `premiumExpiresAt: Date?`, `premiumProductId: String?`, `inviteRewardKind: InviteRewardKind?`, `inviteRewardClaimedAt: Date?`.
- The select in `ProfileService` adds the new columns; existing RLS `profiles_self_read` already allows the user to read their own row.

**Paywall entry point:**

- `Paywall.present(for: PaywallTrigger)` static helper — every gated CTA calls it.
- Returns immediately (no-op) if `entitlement.hasPremium == true`.
- Otherwise presents the modal `PaywallView(variant: trigger.variantGroup)`.

### Section B — Free-tier limits + invite reward

**Caps (free tier):**

- Memories: 3 base, +1 if `invite_reward_kind = 'memory'` → effective 4.
- Tickets: 5 base, +2 if `invite_reward_kind = 'tickets'` → effective 7.

**Server enforcement** (BEFORE INSERT triggers on `memories` and `tickets`):

```text
1. If profile.grandfathered_at IS NOT NULL → allow.
2. If profile.is_premium = true AND
   (profile.premium_expires_at IS NULL OR profile.premium_expires_at > now())
   → allow.
3. effective_cap = base + reward bonus from invite_reward_kind.
4. If count(*) of caller's existing rows >= effective_cap → RAISE
   with code 'memory_cap_exceeded' or 'ticket_cap_exceeded'.
```

iOS catches these named error codes and presents the matching paywall variant if the trigger ever fires (defence-in-depth — client should normally have already gated).

**`is_premium` source:**

- v1: client posts a verified `Transaction` JWS to RPC `set_premium_from_transaction(p_jws)`. Server verifies signature with Apple's public key, extracts `expirationDate`, `productId`, `transactionId`, `appAccountToken`. Verifies token equals `auth.uid()`. Stamps `is_premium`, `premium_expires_at`, `premium_product_id`, `premium_transaction_id` on the profile.
- Called from iOS every time `Transaction.updates` fires, on initial purchase, and on app launch as a refresh.
- v2 (deferred to Phase 5 / v1.5): App Store Server Notifications V2 webhook → Supabase Edge Function for push-based truth. Catches out-of-band cancellations / refunds the client never sees.
- **v1 leak window:** between an out-of-band cancellation and the user's next app launch, `is_premium` stays true. Acceptable for v1; closes when ASSN2 ships.

**Client-side gating:**

- `entitlement.hasPremium == true` → no gate, never paywall.
- Else, `MemoriesStore.canCreate` / `TicketsStore.canCreate` check `count >= effectiveCap`.
- False → `Paywall.present(for: .memoryLimit)` / `.ticketLimit` instead of opening the creation flow.

**Invite reward — independent claims (locked Q1):**

- New columns: `profiles.invite_reward_kind text CHECK (invite_reward_kind IN ('memory','tickets'))`, `profiles.invite_reward_claimed_at timestamptz`.
- Existing `claim_invite(p_token)` RPC unchanged — still links friend → inviter, marks invite redeemed.
- New RPC `claim_invite_reward(p_kind text)`:
  1. Caller is in at least one **claimed** invite — either as inviter (`invites.inviter_id = auth.uid() AND claimed_by IS NOT NULL`) OR as invitee (`invites.claimed_by = auth.uid()`). Eligibility looks at `claimed_by` (the column the existing `claim_invite` RPC populates when a friend signs up via the link), not `redeemed_at` — which is a separate downstream signal `claim_invite` never sets.
  2. Caller's `invite_reward_kind IS NULL` (one-shot).
  3. Stamp `invite_reward_kind = p_kind`, `invite_reward_claimed_at = now()` on caller's profile.
- UI: "Reward ready" banner in Invite settings when eligible. Tap → memory-vs-tickets picker → calls RPC.
- Inviter receives a push notification when their invite is redeemed ("Your friend redeemed your invite — pick your perk!"). Invitee gets no push (they performed the redemption themselves; banner appears naturally next time they visit settings).

### Section C — StoreKit + Plan management

**App Store Connect setup:**

- One subscription group: **Lumoria Premium**.
- `app.lumoria.premium.monthly` — auto-renewable, $3.99/mo, 14-day free intro offer.
- `app.lumoria.premium.annual` — auto-renewable, $24.99/yr, 14-day free intro offer.
- `app.lumoria.premium.lifetime` — non-consumable, $59.99 one-time. No trial (StoreKit doesn't allow intro offers on non-consumables).
- Family sharing: enabled on all three by default.

**Local development:**

- `Configuration.storekit` file with the three products mirroring ASC for sandbox/preview testing.

**Trial mechanics (Q2 = A):**

- `Product.SubscriptionInfo.Status.isEligibleForIntroOffer` reports per-product trial eligibility.
- `entitlement.trialAvailable = monthly.isEligibleForIntroOffer || annual.isEligibleForIntroOffer`.
- Drives the Figma 969-20173 ("trial available") vs 969-20171 ("trial used") variant choice.

**App Account Token:**

- Every `Product.purchase()` call sets `options: [.appAccountToken(auth.uid())]`.
- Token comes back inside the signed JWS.
- Server uses it to bind the transaction to the right `profiles.user_id` when `set_premium_from_transaction` runs.

**Restore purchases:**

- `AppStore.sync()` on a button in Plan management. Required by App Review.

**Settings → Plan management** (replaces `placeholderView("Plan")`):

| Tier | Body content |
|---|---|
| `.grandfathered` | "You're a beta tester. Premium is on the house, for life." Thank-you copy. |
| `.lifetime` | "Lifetime — bought DD MMM YYYY". Restore link. |
| `.subscriberInTrial` | "Trial — free until DD MMM" + Manage subscription deep link. |
| `.subscriber` | "Annual / Monthly — renews DD MMM" + Manage subscription deep link. |
| `.free` | "Free tier" + "See plans" CTA → opens default paywall. |

"Manage subscription" uses SwiftUI's `.manageSubscriptionsSheet` (iOS 15+). Footer on every state: **Restore purchases** button.

### Section D — Paywall UI

**4 personalised hero variants** (Q5 = B grouping):

| Variant | Triggers map here |
|---|---|
| `.memoryLimit` | Tap "+" with 3 memories already (or 4 with reward). |
| `.ticketLimit` | Tap "Create ticket" with 5 tickets already (or 7 with reward). |
| `.mapSuite` | Tap "View timeline" or "Export map" inside a memory. |
| `.premiumContent` | Tap Public Transport category, any of the 6 placeholder categories, any paid template (Heritage / Prism / Terminal / Express / Night / Orient / Infoscreen), Style customisation, PKPass import, or iOS sticker pack. |

Each variant has its own hero block (illustration + headline + 1-line subhead). Below the hero, **everything else is identical**: same plan card, same trial CTA, same trust copy. `PaywallTrigger` enum drives the variant selection and the analytics `paywallViewed(source:)` property (already stubbed in `AnalyticsEvent.swift`).

**Plan card** (Figma 968-17975) — three tiles, vertically stacked. Default selected = **Annual**.

```text
┌───────────────────────────────────┐
│ Monthly                           │
│ $3.99/mo                          │
│ [14 days free]    ← MonthTag      │
└───────────────────────────────────┘

┌───────────────────────────────────┐  ← selected (coloured ring)
│ Annual                  Best value│
│ $24.99/yr · ≈ $2.08/mo            │
│ [14 days free]                    │
└───────────────────────────────────┘

┌───────────────────────────────────┐
│ Lifetime                          │
│ $59.99 once                       │
│ [One-time]                        │
└───────────────────────────────────┘
```

**MonthTag** (Figma 968-17993) — small chip component:

- `.trial("14 days free")`
- `.bestValue("Best value")`
- `.oneTime("One-time")`

**Trial vs no-trial** (Figma 969-20173 vs 969-20171) — same layout, two flips driven by `entitlement.trialAvailable`:

|  | Trial available | Trial used |
|---|---|---|
| MonthTag on monthly + annual | "14 days free" | hidden |
| Primary CTA | **Start free trial** | **Subscribe** (or **Buy** when lifetime selected) |
| Subhead under CTA | "Then $24.99/year. Cancel anytime." | "Cancel anytime in Settings." |

Lifetime tile selected → CTA always reads **Buy** regardless of trial state.

**Share-link action sheet** (Figma 969-20167) — triggered from "Share my link" on the Invite settings screen. Wraps a `UIActivityViewController` with the user's invite URL (`https://getlumoria.app/invite/{token}`). iOS handles Copy / Messages / Mail / WhatsApp / More natively. Sheet styling shown in Figma is the system sheet — no custom build.

### Section E — Database changes

Migration: `paywall_and_monetisation` (single migration covers all of this).

**New columns on `profiles`:**

```sql
ALTER TABLE public.profiles
  ADD COLUMN is_premium             boolean DEFAULT false NOT NULL,
  ADD COLUMN premium_expires_at     timestamptz NULL,
  ADD COLUMN premium_product_id     text NULL,
  ADD COLUMN premium_transaction_id text NULL,
  ADD COLUMN invite_reward_kind     text NULL
    CHECK (invite_reward_kind IN ('memory','tickets')),
  ADD COLUMN invite_reward_claimed_at timestamptz NULL;
```

**Generalised protect trigger** — replaces `profiles_protect_grandfather`:

```sql
CREATE OR REPLACE FUNCTION public.profiles_protect_managed_columns()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
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
$$;
```

**Cap-enforcement triggers** on `memories` and `tickets`:

```text
BEFORE INSERT FOR EACH ROW EXECUTE FUNCTION public.enforce_<table>_cap();

enforce_<table>_cap():
  1. SELECT grandfathered_at, is_premium, premium_expires_at, invite_reward_kind
       INTO v_state FROM public.profiles WHERE user_id = NEW.user_id;
  2. IF v_state.grandfathered_at IS NOT NULL → RETURN NEW.
  3. IF v_state.is_premium AND
        (v_state.premium_expires_at IS NULL OR v_state.premium_expires_at > now())
     → RETURN NEW.
  4. v_cap := <base> + (CASE invite_reward_kind WHEN '<reward>' THEN <bonus> ELSE 0 END).
  5. SELECT count(*) INTO v_count FROM public.<table> WHERE user_id = NEW.user_id.
  6. IF v_count >= v_cap → RAISE EXCEPTION '<table>_cap_exceeded'.
  7. RETURN NEW.
```

**Pre-flight check before writing the migration:** confirm `public.memories` and `public.tickets` tables exist and have a `user_id uuid` column matching `auth.users.id`. If they expose `created_by` / `owner_id` / something else, swap the column name in the trigger logic.

**RPCs:**

`set_premium_from_transaction(p_jws text)` — SECURITY DEFINER:

1. Verify the JWS using Apple's public key (cached in a small `apple_public_keys` table; refreshed via Edge Function on schedule).
2. Extract `appAccountToken`, `expirationDate`, `productId`, `transactionId`.
3. Verify `appAccountToken = auth.uid()`.
4. Update `profiles` for `auth.uid()` with `is_premium = true`, `premium_expires_at`, `premium_product_id`, `premium_transaction_id`.

`claim_invite_reward(p_kind text)` — SECURITY DEFINER:

1. `IF NOT EXISTS (SELECT 1 FROM invites WHERE (inviter_id = auth.uid() AND claimed_by IS NOT NULL) OR claimed_by = auth.uid())` → raise `'no_claimed_invite'`.
2. `IF (SELECT invite_reward_kind FROM profiles WHERE user_id = auth.uid()) IS NOT NULL` → raise `'already_claimed'`.
3. Validate `p_kind IN ('memory','tickets')`.
4. `UPDATE profiles SET invite_reward_kind = p_kind, invite_reward_claimed_at = now() WHERE user_id = auth.uid()`.

### Section F — Build sequence (foundation-first)

**Phase 1 — Foundation** (no money taken yet, no UI changes user can see)

- DB migration: new `profiles` columns, generalised protect trigger, cap-enforcement triggers on `memories`/`tickets`, two new RPCs.
- iOS `Profile` struct extension: new fields, fetched from existing profile select.
- New `services/entitlement/EntitlementStore.swift` — `Transaction.updates` subscription, `hasPremium` / `tier` / `trialAvailable` outputs.
- `PaywallTrigger` enum + `Paywall.present(for:)` helper.
- `MemoriesStore.canCreate` / `TicketsStore.canCreate` checks.
- App Store Connect: 3 products + subscription group + 14-day intro offer on monthly/annual.
- `Configuration.storekit` for sandbox testing.

**Phase 2 — Default paywall + purchase flow** (this is when the app starts taking money)

- Paywall view: default hero, plan card with 3 tiles, MonthTag chip, primary CTA, restore link.
- `Product.purchase(options: [.appAccountToken(auth.uid())])`. On verified transaction → `set_premium_from_transaction(jws)` → refresh `EntitlementStore` → dismiss.
- Trial-aware CTA copy / MonthTag swap from `entitlement.trialAvailable`.
- Plan management screen replaces the placeholder.
- **Soft launch boundary** — TestFlight ships here. Every paywall trigger uses the default hero. No personalisation, no invite reward yet.

**Phase 3 — Personalised hero variants**

- 4 hero blocks (illustration + headline + subhead) for `memoryLimit` / `ticketLimit` / `mapSuite` / `premiumContent`.
- Wire each gated CTA to its trigger.
- Copy pass + illustration sourcing per variant.

**Phase 4 — Invite-as-reward**

- Extend Invite settings: "Reward ready" banner when eligible, memory-vs-tickets picker sheet, calls `claim_invite_reward`.
- Push to inviter on friend redemption (extend existing notification plumbing).

**Phase 5 — v1.5: App Store Server Notifications V2** (deferred from v1)

- Supabase Edge Function endpoint for Apple's webhook.
- JWS verification using Apple's public key.
- Profiles-side state updates on cancel / refund / fail-to-renew / DID_CHANGE_RENEWAL_STATUS.

**Rough sizing:** 6–8 days of work end-to-end (Phases 1–4), excluding App Store review wait.

## Out of scope (for this spec)

- Server-side ASSN2 webhook (Phase 5, separate spec).
- Region-specific pricing or promo codes.
- Family-shared subscription edge cases beyond the default ASC setup.
- Anti-fraud signals beyond Apple's JWS signature verification.
- Refund handling UX (relies on ASSN2; until then, refunds are honoured silently when the next app launch's `Transaction.updates` reflects them).

## Existing code to extend (not rebuild)

- `views/settings/Invite.swift`, `InvitesStore.swift`, `InviteView.swift` — three-state invite flow already exists. Phase 4 layers the reward picker on top.
- `services/onboarding/ProfileService.swift` — extend the profile fetch with new columns.
- `views/services/analytics/AnalyticsEvent.swift` — `planViewed` / `paywallViewed(source:)` / `planSelected` / `checkoutStarted` / `subscriptionStarted` / `subscriptionCancelled` events already stubbed; wire them up.

## Existing code to replace

- `views/settings/SettingsView.swift:188` — `placeholderView("Plan")` becomes the real Plan management screen in Phase 2.
- `views/settings/InviteView.swift:95` — "Upgrade to Premium" button currently has a `TODO: wire to the premium upgrade flow` comment; gets wired in Phase 2.
