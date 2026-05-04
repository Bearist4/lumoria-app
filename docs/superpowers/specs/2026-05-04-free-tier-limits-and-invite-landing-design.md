# Free-tier limits & invite-landing paywall

**Status:** spec
**Date:** 2026-05-04
**Owner:** Benjamin Caillet

## Goal

Replace the StoreKit-based paywall with an invite-only "More from Lumoria" landing for free-tier limit-reached states, so the app can ship with caps enforced and no payment surfaces. Early adopters (registered via website, marked `grandfathered_at`) remain unlimited.

## Non-goals

- Removing or migrating away from existing StoreKit code. It stays dormant behind a single `kPaymentsEnabled` constant so payments can be re-enabled later.
- Changing the `monetisationEnabled` server kill-switch semantics. It still acts as the global "lift all caps" override.
- Any changes to the website / Supabase signup path — `Profile.grandfatheredAt` is already set there.

## Tier model

Two effective states for the user-facing UI:

| Tier | Memories | Tickets | Source |
|---|---|---|---|
| `.grandfathered` (early adopter) | unlimited | unlimited | `profiles.grandfathered_at` set during website signup |
| `.free` | 3 (4 with invite reward) | 10 (12 with invite reward) | default |

`EntitlementTier.lifetime` / `.subscriber` / `.subscriberInTrial` cases stay in the enum but are unreachable while `kPaymentsEnabled == false`. `EntitlementStore.tier(for:now:)` keeps current resolution logic — only `.grandfathered` and `.free` will surface in practice.

## Cap math

| Resource | Base cap | Invite-reward bonus | Max |
|---|---|---|---|
| Memories | 3 | +1 (when `invite_reward_kind = 'memory'`) | 4 |
| Tickets | **10** (was 5) | +2 (when `invite_reward_kind = 'tickets'`) | 12 |

Changes:
- `FreeCaps.baseTicketCap`: `5` → `10`
- New SQL migration `YYYYMMDDHHMMSS_bump_ticket_cap_to_10.sql` updating `enforce_ticket_cap` trigger constant `5` → `10`. Memory cap unchanged.

`enforce_memory_cap` trigger and `claim_invite_reward` RPC are unchanged.

## Payment-flag constant

Add a single source of truth in `EntitlementStore.swift`:

```swift
/// Master toggle for any payment-related UI. False = no purchase paths
/// anywhere in the app; the limit-reached paywall renders the
/// invite-only landing instead. Flip to true once StoreKit ships.
static let kPaymentsEnabled = false
```

Surfaces guarded by this constant:
- `Paywall.present(for:entitlement:state:)` — for `.memoryLimit` / `.ticketLimit` triggers, route to `InviteLandingView` when `kPaymentsEnabled == false`. For all other triggers, no-op when `kPaymentsEnabled == false`.
- `PlanManagementView` — hide upgrade CTA, render status-only row.
- `PaywallView` (purchase UI) — file stays in tree, but no caller references it while `kPaymentsEnabled == false`.

## Components

### `LumoriaUpgradeIncentive` (new)

Pill matching figma 2146:159524.

```swift
struct LumoriaUpgradeIncentive: View {
    enum Resource { case memory, tickets }
    let resource: Resource
    var body: some View { … }
}
```

Visual:
- Background: `Color.Feedback.Promotion.surface` (`#f8f1ff`)
- Border: 1pt `Color.Feedback.Promotion.border` (`#ac79e2`)
- Text color: `Color.Feedback.Promotion.content` (`#43006d`)
- Font: 15pt SF Pro Semibold
- Padding: horizontal 12, vertical 4
- Corner radius: 44

Copy:
- `.memory`: "Unlock a new memory"
- `.tickets`: "Unlock 2 new slots"

### `LumoriaPremiumBadge` (new)

Extracted from inline impl in `FormStepCollapsibleItem.statusIcon`. Two variants matching figma 1994:130463:

```swift
struct LumoriaPremiumBadge: View {
    enum Style {
        case crown        // 24pt purple disc + crown.fill glyph
        case valueOffer(String) // pill, e.g. "2 months free"
    }
    let style: Style
    var body: some View { … }
}
```

`FormStepCollapsibleItem` migrates to use `.crown` variant.

Initial placements:
- Settings → status row (when grandfathered)
- `InviteLandingView` toolbar slot (decorative)

### `InviteLandingView` (new)

Matches figma 972:23490 + 2147:161824. Driven by `InvitesStore.state`. Replaces the limit-reached variant of `PaywallView` for `.memoryLimit` / `.ticketLimit` triggers.

Layout (top to bottom):
- Sheet toolbar: leading `xmark` close button, trailing `questionmark.circle` info button (tap → reuses existing `InviteExplanationView` if present, else no-op)
- Pink-tinted blur ornament behind upper region
- Title block: "More from Lumoria" (LargeTitle.bold), "by inviting a friend" (Title2.bold, secondary)
- Body paragraph: "Thank you for using Lumoria to craft beautiful tickets!"
- Emphasis paragraph: bold lead "You are running out of Memories or Ticket slots." + body "Invite a friend to gain 1 more Memory slot or 2 more ticket slots."
- Footnote: "Your friend will also get to choose between one or the other option for their account."
- Read-only input field showing the share URL (`getlumoria.app/{token}` or placeholder if not yet sent)
- Primary CTA — copy depends on state (see below)
- Caption2 footer: "This offer is valid once per account (referring or referee).\nNo credit card required."

State-dependent CTA + behavior:

| `InvitesStore.state` | CTA label | onTap |
|---|---|---|
| `.notSent` | "Share my link" | `await store.sendInvite()` → on success, `showShareSheet = true` |
| `.sent(invite)` | "Share my link" | `showShareSheet = true` (re-share existing token) |
| `.redeemed` | (no CTA) | — body copy swaps to: "You've used your invite. Delete a memory or a ticket to make room for a new one." |
| `.loading` | (button disabled, redacted placeholder) | — |

`ShareSheet` is the existing `UIActivityViewController` wrapper. Items: `[invite.shareURL]`. Once presented, the user can pick any iOS share target (figma 2147:161824 = standard iOS share sheet, no custom UI).

Analytics: emit `.invitePageViewed(state:)` on appear (reusing existing event) and `.inviteShared(channel: .system_share, …)` on share-sheet present.

## Memories header subtitle

`MemoriesView.header` adds a subtitle line 4pt below "Memories":

```
free, slots > 0:        Text("\(remaining) available slots")  // 15pt regular text/tertiary
free, slots == 0:       LumoriaUpgradeIncentive(.memory)       // tappable pill
grandfathered/premium:  (no subtitle)
```

Tap on the pill → `Paywall.present(for: .memoryLimit, entitlement: …, state: …)`.

`remaining` = `FreeCaps.memoryCap(rewardKind:) - store.memories.count`, clamped to >= 0. Recomputes on `store.memories` change and `entitlement.tier`/`entitlement.inviteRewardKind` change.

When `entitlement.monetisationEnabled == false` (kill-switch), subtitle is hidden too — kill-switch means free-for-all everywhere.

## Routing changes

In `Paywall.present(for:entitlement:state:)`:

```swift
@MainActor
static func present(
    for trigger: PaywallTrigger,
    entitlement: EntitlementStore,
    state: PresentationState
) {
    guard !entitlement.hasPremium else { return }
    if !EntitlementStore.kPaymentsEnabled {
        // Only limit-reached triggers have something to show
        // (the invite landing). Everything else is dormant.
        guard trigger.isLimitReached else { return }
    }
    state.trigger = trigger
}
```

`Paywall.PresentationState`'s sheet binding (currently `PaywallView(trigger: …)`) switches on `kPaymentsEnabled`:

```swift
.sheet(isPresented: $paywallState.isPresented) {
    if let trigger = paywallState.trigger {
        if EntitlementStore.kPaymentsEnabled {
            PaywallView(trigger: trigger, entitlement: entitlement)
        } else {
            InviteLandingView(trigger: trigger)
        }
    }
}
```

Located wherever the existing paywall sheet is currently mounted (likely `ContentView` or `Lumoria_AppApp`).

## Settings changes

`PlanManagementView` renders one of two states based on `entitlement.tier`:

| Tier | Display |
|---|---|
| `.grandfathered` | `LumoriaPremiumBadge(.crown)` + "Early adopter — unlimited memories and tickets" |
| `.free` | "Free plan" + "3 memories, 10 tickets" + "+1 memory or +2 tickets when your invite is redeemed" |

No upgrade button, no purchase CTA. The "Coming soon" stub copy (currently shown when `monetisationEnabled == false`) becomes the default.

## Files touched

New:
- `Lumoria App/components/LumoriaUpgradeIncentive.swift`
- `Lumoria App/components/LumoriaPremiumBadge.swift`
- `Lumoria App/views/paywall/InviteLandingView.swift`
- `supabase/migrations/YYYYMMDDHHMMSS_bump_ticket_cap_to_10.sql`
- `lumoria/src/content/changelog/free-tier-limits-and-invite-landing.mdx`

Modified:
- `Lumoria App/services/entitlement/FreeCaps.swift` — `baseTicketCap` 5 → 10
- `Lumoria App/services/entitlement/EntitlementStore.swift` — add `kPaymentsEnabled` constant
- `Lumoria App/services/entitlement/PaywallPresenter.swift` — gate non-limit triggers when `kPaymentsEnabled == false`
- `Lumoria App/views/collections/CollectionsView.swift` — add slot-counter subtitle / `LumoriaUpgradeIncentive` to `header`
- `Lumoria App/components/FormStepCollapsibleItem.swift` — use `LumoriaPremiumBadge(.crown)`
- `Lumoria App/views/settings/PlanManagementView.swift` — hide upgrade CTA, render status-only row
- Wherever the paywall sheet is mounted — switch presented view on `kPaymentsEnabled`
- `Lumoria App/Localizable.xcstrings` — new strings ("X available slots", "Unlock a new memory", "Unlock 2 new slots", "More from Lumoria", "by inviting a friend", body paragraphs, "Share my link", redeemed-state copy, "Early adopter — unlimited memories and tickets", "Free plan", "3 memories, 10 tickets", "+1 memory or +2 tickets when your invite is redeemed")

Untouched (intentionally dormant):
- `Lumoria App/views/paywall/PaywallView.swift` (purchase UI)
- `Lumoria App/views/paywall/PlanCard.swift`
- `Lumoria App/views/paywall/MonthTag.swift`
- `Lumoria App/views/paywall/StepTimelineRow.swift`
- `Lumoria App/views/paywall/TrialExplanationView.swift`
- `Lumoria App/services/purchase/PurchaseService.swift`
- `Lumoria App/Configuration.storekit`

## Edge cases

- **Kill-switch on (`monetisationEnabled == false`):** existing behavior preserved — `hasPremium` returns true, no caps, no paywall, header subtitle hidden.
- **Invite already redeemed and user at cap:** `InviteLandingView` shows redeemed-state copy with no CTA. User must delete a memory/ticket to free a slot.
- **Invite sent but not redeemed, user at cap:** `.sent` state — primary CTA re-shares the same token. The single-invite-per-user constraint at the SQL level is unchanged.
- **Server cap fires after client cap somehow misses it (e.g. profile not yet refreshed):** the existing `MemoriesStore.create` / `TicketsStore.create` error paths surface the `memory_cap_exceeded` / `ticket_cap_exceeded` Postgres errors as red error banners. No changes.
- **User signs in on a device with stale local entitlement:** `EntitlementStore.refresh()` runs on app launch and after sign-in, pulling fresh `grandfathered_at`. No client work needed.

## Test plan

1. **Cap enforcement (free)** — fresh free user: create 3 memories, verify 4th tap on `+` opens `InviteLandingView` instead of new-memory sheet. Same with tickets at 10.
2. **Cap with invite reward** — free user with `invite_reward_kind = 'memory'`: cap is 4. With `'tickets'`: ticket cap is 12.
3. **Grandfathered** — user with `grandfathered_at` set: no subtitle, `+` always opens new-memory sheet, paywall never presents.
4. **Subtitle math** — slots=3 → "3 available slots", slots=1 → "1 available slots" (note: confirm copy — see open question below), slots=0 → pill.
5. **Invite landing states** — render each of `.notSent`, `.sent`, `.redeemed` via preview seeding. Verify CTA labels and tap behavior.
6. **Share sheet** — tap "Share my link" in `.notSent`: `sendInvite()` runs, `ShareSheet` presents with `invite.shareURL`. In `.sent`: no new invite created; `ShareSheet` re-shares existing.
7. **Kill-switch on** — set `monetisationEnabled = false`: header subtitle hidden, `+` always opens new-memory sheet, paywall never presents (regardless of cap state).
8. **Settings status row** — grandfathered user sees crown badge + "Early adopter" copy; free user sees "Free plan" copy. No upgrade button in either case.

## Resolved

- **Subtitle pluralisation** — use xcstrings plural variant: `%lld available slots` with `one` ("1 available slot") and `other` ("%lld available slots") variants. Same treatment for `0` ("No slots available" if we want a distinct copy, otherwise falls into `other`). Decision: keep `other` covering 0 as well — slot==0 case shows the pill, never the text.
- **`InviteLandingView` info button** — opens existing `InviteExplanationView` in a sheet. Existing component, no new copy needed.
