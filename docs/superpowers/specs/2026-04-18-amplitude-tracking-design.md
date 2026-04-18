# Amplitude Tracking — Design Spec

**Date:** 2026-04-18
**Author:** Benjamin Caillet (w/ Claude)
**Status:** Approved for implementation

---

## 1. Goals

1. Instrument the Lumoria iOS app with a world-class Amplitude event tracking plan mapped to the AARRR framework (Acquisition, Activation, Retention, Referral, Revenue).
2. Build and maintain the canonical tracking plan in Notion with events, event properties, user properties, categories, and funnel relations.
3. Ship a secure, type-safe Amplitude SDK integration that never hardcodes credentials, never leaks PII, and is decoupled from view code via a protocol-backed `AnalyticsService`.

## 2. Non-goals (v1)

- **Consent / GDPR sheet.** Infrastructure for opt-out is included (`Amplitude.optOut`), but no UI. App is in closed beta.
- **Amplitude Experiment (A/B testing).**
- **Server-side event forwarding** (Supabase Edge Function → Amplitude HTTP API).
- **Revenue events.** No StoreKit integration yet. Revenue event cases + Notion rows are **scaffolded** (enum cases exist, status = `Backlog`) so instrumentation ships same-day when IAP launches.
- **Separate Amplitude projects per environment.** One project; `environment` event property tags `dev` vs `prod`. Dev data filtered out of all production dashboards.

## 3. Architecture

```
┌─────────────────────────────────────────────────┐
│  SwiftUI Views (auth, funnel, tickets, etc.)    │
│             ↓ calls                             │
│  Analytics.track(.ticketCreated(payload))       │
│             ↓                                   │
│  AnalyticsService (protocol)                    │
│   - AmplitudeAnalyticsService (prod impl)       │
│   - NoopAnalyticsService (previews/tests)       │
│             ↓                                   │
│  AmplitudeSwift SDK (SPM)                       │
│             ↓                                   │
│  Amplitude ingestion                            │
└─────────────────────────────────────────────────┘
```

### 3.1 Type-safe event contract

All events modelled as an `AnalyticsEvent` enum with associated values. No stringly-typed properties at call sites.

```swift
enum AnalyticsEvent {
    case ticketCreated(category: TicketCategoryProp, template: TicketTemplateProp,
                       orientation: OrientationProp, styleId: String?,
                       formFieldCount: Int, hasOriginLocation: Bool,
                       hasDestinationLocation: Bool)
    case memoryCreated(colorFamily: MemoryColorFamilyProp, hasEmoji: Bool, nameLength: Int)
    // …one case per event in the plan
}
```

Each case knows its own Title-Case event name and typed property dict. Misnamed property = compile error.

### 3.2 Wrapper + DI

- `protocol AnalyticsService` — `track(_:)`, `identify(userId:properties:)`, `reset()`, `setOptOut(_:)`.
- `Analytics` — singleton entry point, holds the active `AnalyticsService`.
- `AmplitudeAnalyticsService` — prod impl.
- `NoopAnalyticsService` — previews + unit tests. No network, no SDK init.

View code never imports `AmplitudeSwift`. One seam to swap the backend later.

### 3.3 Universal properties

Attached in the wrapper, not at call sites:

| Property | Source |
|---|---|
| `environment` | `#if DEBUG ? "dev" : "prod"` |
| `app_version` | bundle `CFBundleShortVersionString` |
| `build_number` | bundle `CFBundleVersion` |
| `os_version`, `device_model` | Amplitude SDK auto |
| `locale`, `timezone` | Amplitude SDK auto |
| `brand_slug` | Currently selected app icon family |
| `appearance_mode` | light / dark / system |
| `high_contrast_enabled` | Bool |

### 3.4 API key loading (security)

1. `Amplitude.xcconfig` (gitignored) holds `AMPLITUDE_API_KEY = f4b490c0860c371ec46ed8b90d923de2`.
2. `Amplitude.sample.xcconfig` (committed) is the template for new contributors.
3. Both Debug and Release build configurations reference `Amplitude.xcconfig`.
4. `Info.plist` carries `AMPLITUDE_API_KEY` with `$(AMPLITUDE_API_KEY)` substitution.
5. `AmplitudeAnalyticsService` reads the key from `Bundle.main.infoDictionary`.
6. `.gitignore` ensures the real key never lands in git history.
7. If the key is absent at init, `AmplitudeAnalyticsService` logs a single warning and falls back to no-op behaviour (no crash, no throws).

### 3.5 SDK configuration

- `autocapture: .sessions` only. Screen views, element interactions, and deep-link auto-capture are **disabled**. Per the tracking plan, all user-intent events are manual.
- `defaultTracking: .init(sessions: true)` — session start/end + app lifecycle.
- `flushQueueSize: 30`, `flushIntervalMillis: 30_000` (SDK defaults). Keep until volume dictates otherwise.
- `serverZone`: `.US` (default). Change later if data residency requirements shift.
- `trackingOptions` configured to not capture IP address (strict PII posture; see §5).

### 3.6 Opt-out hook

- `@AppStorage("analytics.optOut") var optedOut: Bool = false`
- `AnalyticsService.setOptOut(_)` → `Amplitude.optOut = newValue`.
- Default: opted-in. A consent sheet can bind to `optedOut` in the future without any plumbing changes.

## 4. Identity

### 4.1 User identification

- **On Login Succeeded / Session Restored** → `Amplitude.setUserId(supabase_user_id)`.
- **On Logout** → `Amplitude.reset()` (clears userId, rotates device ID, detaches subsequent events from the previous user).
- **`user_id` = raw Supabase UUID.** This is a random v4 UUID with no PII, safe to share with Amplitude.

### 4.2 User properties (identify)

Updated via `Amplitude.identify(Identify().set(key, value))` on relevant events. Never sent as event properties.

| Property | Type | Updated when |
|---|---|---|
| `user_id` | UUID | On login |
| `email_domain` | string | On login (e.g. `gmail.com`) |
| `signup_date` | ISO-8601 | On signup verified |
| `environment` | enum | On init |
| `tickets_created_lifetime` | int | `Ticket Created` |
| `memories_created_lifetime` | int | `Memory Created` |
| `last_ticket_category` | enum | `Ticket Created` |
| `last_export_destination` | enum | `Ticket Exported` |
| `invites_sent` | int | `Invite Shared` |
| `invites_redeemed` | int | `Invite Claimed` (as inviter) |
| `app_icon` | string | `App Icon Changed` |
| `appearance_mode` | enum | `Appearance Mode Changed` |
| `high_contrast_enabled` | bool | `High Contrast Toggled` |
| `push_enabled` | bool | `Push Permission Responded` |
| `has_created_first_ticket` | bool | `First Ticket Created` |
| `has_created_first_memory` | bool | `First Memory Created` |
| `days_since_signup` | int | On session start |

## 5. PII & data-minimisation rules

**Never send to Amplitude:**

- Raw email addresses
- Full names, first names, last names
- Avatar URLs or image bytes
- Encrypted memory names/emojis (the ciphertext is meaningless to Amplitude and still semantically sensitive)
- Airport / station / city / venue names
- Flight numbers, train numbers, seat, gate, terminal, cabin, carriage, berth
- Invite tokens (raw)
- Memory / ticket / invite primary-key UUIDs (raw)

**Safe to send:**

| Instead of | Send |
|---|---|
| Full email | `email_domain` (string before `@` is dropped client-side) |
| Memory name | `name_length` (int), `has_emoji` (bool) |
| Airport / station objects | `has_origin_location` (bool), `has_destination_location` (bool) |
| Flight/train form fields | `field_fill_count` (int), per-field `has_*` booleans |
| `memory_id` UUID | `memory_id_hash` — SHA-256 of UUID, first 16 hex chars |
| `ticket_id` UUID | `ticket_id_hash` — same construction |
| `invite_token` | `invite_token_hash` — same construction |

Hashes let us join `Invite Shared` (inviter) with `Invite Claimed` (invitee) in Amplitude without exposing primary keys. Collision probability across ~10^9 UUIDs with 64-bit truncation = negligible.

IP capture is disabled in the SDK `trackingOptions`.

## 6. Tracking plan (events)

**Convention:** Events are Title Case `Object Action`. Properties are `snake_case`.

### 6.1 Acquisition (14)

| Event | Key properties |
|---|---|
| Session Started | `is_first_session` |
| App Opened | `source` (cold / warm / deep_link) |
| Deep Link Opened | `scheme`, `host`, `kind` (invite / push / other) |
| Invite Link Opened | `invite_token_hash`, `was_authenticated` |
| Signup Started | — |
| Signup Submitted | `email_domain`, `has_name` |
| Signup Failed | `auth_error_type` |
| Signup Verification Sent | `email_domain` |
| Login Submitted | `email_domain` |
| Login Failed | `auth_error_type` |
| Login Succeeded | `email_domain`, `was_from_invite` |
| Password Reset Requested | `email_domain` |
| Session Restored | `had_cache` |
| Logout | — |

### 6.2 Activation (17)

| Event | Key properties |
|---|---|
| New Ticket Started | `entry_point` (gallery / memory / notification) |
| Ticket Category Selected | `ticket_category` |
| Ticket Template Selected | `ticket_category`, `ticket_template` |
| Ticket Orientation Selected | `ticket_template`, `ticket_orientation` |
| Ticket Form Started | `ticket_template` |
| Ticket Form Submitted | `ticket_template`, `field_fill_count`, `has_origin_location`, `has_destination_location` |
| Ticket Style Selected | `ticket_template`, `style_id` |
| Ticket Created | `ticket_category`, `ticket_template`, `ticket_orientation`, `style_id`, `field_fill_count`, `has_origin_location`, `has_destination_location`, `tickets_lifetime` |
| First Ticket Created | inherits all `Ticket Created` props. Fires exactly once per user. |
| Ticket Creation Failed | `funnel_step_reached`, `error_type` |
| Ticket Funnel Abandoned | `funnel_step_reached`, `time_in_funnel_ms` |
| Memory Creation Started | — |
| Memory Created | `memory_color_family`, `has_emoji`, `name_length` |
| First Memory Created | inherits. Fires once. |
| Profile Edit Started | — |
| Profile Saved | `name_changed`, `avatar_changed` |
| Avatar Uploaded | `source` (camera / library) |

### 6.3 Retention (22)

| Event | Key properties |
|---|---|
| Ticket Opened | `ticket_category`, `ticket_template`, `source` (gallery / memory / notification) |
| Ticket Edited | `ticket_category`, `ticket_template`, `fields_changed_count` |
| Ticket Deleted | `ticket_category`, `ticket_template`, `was_in_memory` |
| Ticket Duplicated | `ticket_category` |
| Gallery Sort Applied | `sort_type` (date / category) |
| Gallery Refreshed | `ticket_count` |
| Memory Opened | `source` (grid / notification / deep_link), `ticket_count` |
| Memory Edited | `name_changed`, `emoji_changed`, `color_changed` |
| Memory Deleted | `ticket_count` |
| Ticket Added To Memory | `memory_id_hash`, `new_ticket_count` |
| Ticket Removed From Memory | `memory_id_hash` |
| Export Sheet Opened | `ticket_category`, `ticket_template` |
| Export Destination Selected | `export_destination` |
| Camera Roll Export Configured | `include_background`, `include_watermark`, `export_resolution`, `export_crop`, `export_format` |
| Ticket Exported | `export_destination`, `export_resolution`, `export_crop`, `export_format`, `include_background`, `include_watermark`, `duration_ms` |
| Ticket Export Failed | `export_destination`, `error_type` |
| Ticket Shared Via IM | `platform` (whatsapp / messenger / discord) |
| Settings Opened | — |
| Appearance Mode Changed | `appearance_mode` |
| App Icon Changed | `icon_name` |
| High Contrast Toggled | `enabled` |
| Notification Prefs Changed | `notification_type`, `enabled` |

### 6.4 Referral (8)

| Event | Key properties |
|---|---|
| Invite Page Viewed | `state` (not_sent / sent / redeemed) |
| Invite Generated | `is_first_time` |
| Invite Shared | `channel` (system_share / copy_link) |
| Invite Link Received | `invite_token_hash`, `was_authenticated` |
| Invite Claimed | `invite_token_hash`, `role` (inviter / invitee), `time_to_claim_ms` |
| Invite Auto Claimed | `invite_token_hash` |
| Notification Center Opened | `unread_count` |
| Push Opened | `notification_kind`, `deep_link_target` |

### 6.5 Revenue (6, status = Backlog)

Scaffolded only. No call sites yet.

| Event | Key properties |
|---|---|
| Plan Viewed | — |
| Paywall Viewed | `source` (settings / upsell / onboarding) |
| Plan Selected | `plan_id`, `price_cents`, `currency` |
| Checkout Started | `plan_id` |
| Subscription Started | `plan_id`, `price_cents`, `currency`, `trial_days` |
| Subscription Cancelled | `plan_id`, `reason` |

### 6.6 System (8)

| Event | Key properties |
|---|---|
| SDK Initialized | — |
| Push Permission Requested | — |
| Push Permission Responded | `granted` |
| Push Received | `notification_kind`, `in_foreground` |
| Notification Tapped | `notification_kind`, `source` (center / system_banner) |
| Notification Marked Read | `notification_kind` |
| Legal Link Opened | `link_type` (tos / privacy / support) |
| Profile Viewed | — |

### 6.7 Error (3)

| Event | Key properties |
|---|---|
| App Error | `domain`, `code`, `view_context` |
| Network Error | `endpoint_category`, `status_code`, `error_type` |
| Data Sync Failed | `resource_type`, `reason` |

**Total: ~78 events.**

## 7. Funnel relations

Represented as self-relations on the Events DB in Notion (`Triggered By` / `Triggers`).

### 7.1 Signup funnel

```
Signup Started → Signup Submitted → Signup Verification Sent → Login Succeeded → Session Started (first)
```

### 7.2 Ticket creation funnel

```
New Ticket Started
  → Ticket Category Selected
  → Ticket Template Selected
  → Ticket Orientation Selected
  → Ticket Form Started
  → Ticket Form Submitted
  → Ticket Style Selected       (only if template has multiple styles)
  → Ticket Created
  → Export Sheet Opened         (optional)
  → Ticket Exported             (optional)
```

Abandonment is captured by `Ticket Funnel Abandoned` with `funnel_step_reached` — fires on `onDisappear` of `NewTicketFunnelView` unless `Ticket Created` already fired.

### 7.3 Referral funnel

```
Invite Generated → Invite Shared → Invite Link Received → Signup Submitted → Invite Claimed
```

Join Invite Shared (inviter) ↔ Invite Claimed (invitee) on `invite_token_hash`.

### 7.4 First-time activation funnel

```
Signup Verification Sent → Login Succeeded → New Ticket Started → Ticket Created → First Ticket Created
```

## 8. Property vocabulary (enums)

Swift enums mirror the Notion `Enum Values` column 1:1.

```swift
enum TicketCategoryProp: String { case plane, train, parks_gardens, public_transit, concert }
enum TicketTemplateProp: String { case afterglow, studio, terminal, heritage, prism,
                                       express, orient, night }
enum OrientationProp: String { case horizontal, vertical }
enum ExportDestinationProp: String { case camera_roll, whatsapp, messenger, discord,
                                         instagram, twitter, threads, snapchat, facebook }
enum ExportFormatProp: String { case png, jpg }
enum ExportCropProp: String { case full, square }
enum ExportResolutionProp: String { case x1 = "1x", x2 = "2x", x3 = "3x" }
enum NotificationKindProp: String { case throwback, onboarding, news, link }
enum MemoryColorFamilyProp: String { case orange, blue, pink, red, yellow, green /* … */ }
enum AppearanceModeProp: String { case system, light, dark }
enum AuthErrorTypeProp: String { case invalid_credentials, email_in_use,
                                     weak_password, network, unknown }
enum FunnelStepProp: String { case category, template, orientation, form, style, success }
```

## 9. Notion structure

Three databases under the same parent page, built with the Notion MCP after implementation so `Impl Notes` columns can point to real file paths.

### 9.1 Events DB (existing, extended)

`collection://34610dea-1b05-8071-b23e-000b76646219`

| Column | Type | Notes |
|---|---|---|
| Name | Title | Object Action, Title Case |
| Status | Select | Planned / Implemented / Deprecated / Backlog |
| Category | Multi-select | Auth, Onboarding, Deep Link, Ticket Funnel, Ticket Management, Memories, Export & Share, Invites & Referral, Profile, Settings, Notifications, System, Error |
| AARRR Stage | Select | Acquisition / Activation / Retention / Referral / Revenue / System |
| Priority | Select | P0 / P1 / P2 |
| Description | Rich text | What fires this + why we care |
| Trigger | Select | User action / System / Error |
| Surface | Rich text | Screen(s) / component where it fires |
| Properties | Relation → Event Properties DB | |
| Triggered By | Relation (self) | Predecessor events |
| Triggers | Relation (self) | Reverse — Notion auto-derives if `Triggered By` is dual-synced |
| Owner | People / Rich text | |
| Impl Notes | Rich text | File path + function hint |
| Added | Created time (auto) | |

### 9.2 Event Properties DB (new)

| Column | Type |
|---|---|
| Name | Title (snake_case) |
| Type | Select — string / int / bool / enum / timestamp |
| Enum Values | Rich text — comma-separated |
| Description | Rich text |
| Example | Rich text |
| PII | Checkbox — if true, MUST NEVER ship to Amplitude |
| Required | Select — Required / Optional |
| Used In | Relation → Events DB (back-link) |

### 9.3 User Properties DB (new)

| Column | Type |
|---|---|
| Name | Title |
| Type | Select |
| Description | Rich text |
| Example | Rich text |
| Updated By | Relation → Events DB — which events cause this to update |

## 10. Implementation order

### Phase 1 — SDK + infra
1. Add `amplitude-swift` via SPM (latest stable v1.x).
2. Create `Amplitude.xcconfig` (gitignored) + `Amplitude.sample.xcconfig` (committed template).
3. Wire xcconfig into Debug + Release build configs.
4. Add `AMPLITUDE_API_KEY` to `Info.plist` via `$(AMPLITUDE_API_KEY)` substitution.
5. Add `Amplitude.xcconfig` to `.gitignore`.

### Phase 2 — Wrapper
6. `services/analytics/AnalyticsEvent.swift` — enum, case per event.
7. `services/analytics/AnalyticsProperty.swift` — typed enums.
8. `services/analytics/AnalyticsService.swift` — protocol + `Analytics` singleton.
9. `services/analytics/AmplitudeAnalyticsService.swift` — prod impl.
10. `services/analytics/NoopAnalyticsService.swift` — previews / tests.
11. `services/analytics/AnalyticsIdentity.swift` — SHA-256-16 hasher, email-domain extract.
12. Init in `Lumoria_AppApp.swift` before first view render. Fire `SDK Initialized`.

### Phase 3 — Instrumentation
13. Auth (`AuthManager`, LogIn / SignUp / ForgotPassword).
14. Deep links (`handleIncomingURL` in app delegate).
15. New Ticket funnel + abandonment detection.
16. Ticket detail + gallery.
17. Export (`ExportSheet`).
18. Memories.
19. Invites (`InvitesStore`, `InviteView`).
20. Settings screens.
21. Notifications (`PushNotificationService`, `NotificationCenterView`).
22. Error plumbing.

### Phase 4 — Verify
23. Simulator → Amplitude User Lookup → confirm `environment=dev` events arrive.
24. Release build locally → confirm `environment=prod` tagging.
25. Smoke-test funnels in Amplitude Funnel Analysis.

### Phase 5 — Notion population
26. Events DB: add ~78 rows.
27. Event Properties DB.
28. User Properties DB.
29. Link relations (Events ↔ Properties, self-relations for funnels).

## 11. Testing

- Unit tests for `AnalyticsIdentity` hash + email-domain extraction (deterministic inputs/outputs).
- `NoopAnalyticsService` used in all SwiftUI `#Preview` blocks.
- Manual smoke: real device → Debug build → verify every instrumented flow surfaces in Amplitude User Lookup within 60s.

## 12. Open questions

None at spec-approval time. If Notion population uncovers property ambiguities, resolve inline and update this doc.

## 13. Risks

| Risk | Mitigation |
|---|---|
| API key committed to git | xcconfig gitignored + reviewed in PR. `Amplitude.sample.xcconfig` makes the pattern discoverable. |
| PII leak via property values | Typed enums + spec §5 rules. PII checkbox column in Notion Properties DB is the canonical source of truth. |
| Event volume explosion | Wrapper-level rate logging can be added if an event ever spams. Default SDK batching (30 events / 30s) is ample. |
| Dev events pollute prod dashboards | `environment` property filter applied to every saved chart/cohort. Onboarding of this convention documented in `docs/analytics/README.md` (follow-up). |
| SDK init before Info.plist is available | SDK init is synchronous and reads `Bundle.main.infoDictionary` — Info.plist is always present at launch. |
