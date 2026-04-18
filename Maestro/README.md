# Lumoria · Maestro E2E

End-to-end tests for the Lumoria iOS app, driven by [Maestro](https://maestro.mobile.dev/).

See [`TEST_PLAN.md`](./TEST_PLAN.md) for the full test inventory, priorities, and rationale.

## Layout

```
Maestro/
  config.yaml              App ID for every flow
  TEST_PLAN.md             Full test plan — strategy, coverage matrix, phasing
  env/
    staging.env.example    Copy to staging.env and fill in
  subflows/
    login.yaml             Reusable login
    open_funnel.yaml       Logged-in → open New Ticket funnel
    discard_funnel.yaml    Confirm-discard the open funnel
  flows/
    smoke/                 S01–S05 · <2 min, run on every PR
    auth/                  A01, A05, A06
    ticket_funnel/         F01, F03, F06, F08
    tickets/               T02, T05
    memories/              M01–M05, M08
    settings/              SET02, SET04, SET08–SET10
    deeplinks/             D01, D03
    regression/            F05 · nightly only
```

## Running locally

1. Install Maestro: `curl -Ls "https://get.maestro.mobile.dev" | bash`
2. Boot an iOS simulator and install the Lumoria build:
   ```sh
   cd "Lumoria App"
   xcodebuild -scheme "Lumoria App" \
              -destination "platform=iOS Simulator,name=iPhone 15" build
   xcrun simctl install booted path/to/Lumoria.app
   ```
3. Set up env:
   ```sh
   cp env/staging.env.example env/staging.env
   # fill in TEST_EMAIL, TEST_PASSWORD, TEST_INVITE_TOKEN
   export TEST_EMAIL_FRESH="qa+lumoria+$(date +%s)@example.com"
   ```
4. Run:
   ```sh
   # Smoke only (PR gate)
   maestro test --env-file env/staging.env \
                --include-tags=smoke flows/

   # Full regression
   maestro test --env-file env/staging.env \
                --include-tags=regression flows/

   # Single flow
   maestro test --env-file env/staging.env \
                flows/ticket_funnel/F03_plane_afterglow_horizontal.yaml
   ```

## Tags

| Tag           | Use                                                |
|---------------|----------------------------------------------------|
| `smoke`       | PR gate. Must stay under ~2 min total.            |
| `regression`  | Nightly full suite.                                |
| `auth`        | Auth-only subset (signup, login, reset).           |
| `funnel`      | New Ticket creation funnel.                        |
| `memories`    | Collections CRUD.                                  |
| `tickets`     | Detail, delete, export, share.                     |
| `settings`    | Settings, profile, notifications, invite.          |
| `deeplinks`   | Universal + custom-scheme invite links.            |
| `flaky`       | Quarantined while being fixed.                     |

## Known caveats

- **`-uitest 1` launch arg** is passed by every flow's `launchApp`. It nulls `.textContentType` on `LumoriaInputField` so iOS Strong Password autofill stops intercepting keystrokes on `SecureField`. Prod builds never see the arg. If you add new `launchApp` steps, include `arguments: { uitest: "YES" }`.
- **No `accessibilityIdentifier`** is set in the app yet. Flows match on visible text and use `below: "<label>"` relative selectors plus `optional: true` fallbacks on `id:` selectors so they start working as soon as IDs land. Prioritize adding IDs to: funnel chrome buttons, every auth field, tab bar items, ticket cards, memory cards, notification toggles, export sheet controls. Flows will stop relying on `optional:` workarounds once those are in.
- **Signup email confirmation** (A01): Supabase sends a confirmation email that Maestro can't click. Either disable email confirmation for the staging project or stop asserting past the "Check your email" alert.
- **Photos permission** (T05): first-run prompt is handled with an `optional` tap on "Allow Access to All Photos". Subsequent runs skip it.
- **Alt app icon** (SET07): can't be verified on the home screen via Maestro. Left as a manual check — not in scaffolded flows.
- **StoreKit / Plan** (SET12): stub only in-app; no flow scaffolded. Add once paywall is wired.
- **Sticker extension**: can't be driven through the main app target. Manual check documented in TEST_PLAN.md §9.
- **Seeded data assumptions**: ticket flows (T02, T05, M08) assume the seeded account already has at least one ticket. Run F03 first, or pre-seed via Supabase fixtures. Empty-state flow (M01) assumes the opposite — use a fresh account.

## CI

GitHub Actions:
- Smoke suite blocks PRs.
- Regression runs nightly, Slack `#eng-mobile` on failure.
- Artifacts (screenshots, `.maestro` logs) retained 14 days.
