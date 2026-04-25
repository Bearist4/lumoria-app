# App Store Connect — Paywall product setup

Manual one-time setup in App Store Connect for the three paywall
products. Mirror these in `Lumoria App/Configuration.storekit` for
local sandbox testing (already done — see that file).

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
  tier mapping; pricing for other regions auto-fills from Apple's
  matrix).
- Family Sharing: **enabled**.
- Add an **Introductory Offer**:
  - Type: **Free**.
  - Duration: **2 weeks**.
  - Eligibility: **New subscribers only**.
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

## 5. Submit alongside the Phase 2 build

The products will be `Ready to Submit` until the binary that uses
them ships. Submit them with the Phase 2 build (the one that adds
the real purchase flow); they get reviewed together.

## Reference

- Spec: `docs/superpowers/specs/2026-04-25-paywall-and-monetisation-design.md`
- Local sandbox: `Lumoria App/Configuration.storekit`
- StoreKit listener / entitlement source: `Lumoria App/services/entitlement/EntitlementStore.swift`
