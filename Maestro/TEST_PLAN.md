# Lumoria — Maestro E2E Test Plan

Scope: end-to-end UI coverage for the Lumoria iOS app (`bearista.Lumoria-App`) via Maestro flows. Covers auth, ticket creation funnel, memories, settings, export/share, deep links, and regression smoke.

---

## 1. Conventions

### File layout
```
Maestro/
  config.yaml
  flows/
    smoke/                        # fast, run on every build (<2 min total)
    auth/                         # signup, login, password reset
    ticket_funnel/                # 6-step creation funnel, per category + template
    memories/                     # collections CRUD
    tickets/                      # detail, export, share, delete
    settings/                     # profile, notifications, appearance, invite
    deeplinks/                    # invite universal + custom scheme
    regression/                   # long, full-coverage
  subflows/                       # reusable pieces (login, logout, seed ticket)
  env/
    staging.env                   # test creds, seeded account
```

### Tagging
- `smoke` — critical path, runs on every PR, <2 min
- `auth`, `funnel`, `memories`, `tickets`, `settings`, `deeplinks`
- `regression` — nightly full suite
- `flaky` — quarantine while fixing

Run: `maestro test flows/ --include-tags=smoke`

### Test data
Seed one stable staging Supabase account in `staging.env`:
```
APP_ID=bearista.Lumoria-App
TEST_EMAIL=qa+lumoria@example.com
TEST_PASSWORD=...
TEST_EMAIL_FRESH=qa+lumoria+${RUN_ID}@example.com   # unique per run for signup
```

Unique emails per signup run avoid Supabase "email already exists" collisions. Delete accounts nightly via Supabase admin API (separate script, not Maestro).

### Reliability notes
- The app has **no `accessibilityIdentifier` set anywhere**. All matchers use visible text. Flows break if copy changes — coordinate with design before renames.
- Before each flow: `launchApp: clearState: true` to reset auth + UserDefaults. Exception: funnel sub-steps that assume a logged-in state use a `login` subflow.
- Screenshots at every step boundary for visual regression review.
- Add `- extendedWaitUntil: visible: "<text>" timeout: 15000` on any Supabase call boundary (signup confirm, login, save).

### Subflow: login
`subflows/login.yaml`
```yaml
appId: ${APP_ID}
---
- launchApp:
    clearState: true
- tapOn: "Log in"
- tapOn:
    id: "email-field"   # fallback: index-based or hint text match
    text: "Email address"
- inputText: ${TEST_EMAIL}
- tapOn: "Password"
- inputText: ${TEST_PASSWORD}
- tapOn: "Log in"
- extendedWaitUntil:
    visible: "All tickets"
    timeout: 15000
```

### Subflow: discard funnel
`subflows/discard_funnel.yaml` — taps X, confirms "Discard" on the abandon alert. Used in teardown.

---

## 2. Smoke suite (runs on every PR)

Must stay under ~2 minutes total. Scope: app launches, core tabs reachable, auth entry visible.

### S01 · Landing renders *(existing `01_landing_smoke.yaml`)*
- Launch with cleared state
- Assert: "Tickets that last forever", "Log in", "Sign up"
- Screenshot `landing`

### S02 · Signup sheet opens *(existing `02_open_signup_sheet.yaml`)*
- Tap "Sign up" → assert "Let's get started", "Create account"
- Screenshot `signup_sheet`

### S03 · Login sheet opens
- Tap "Log in" → assert "Welcome back!", "Log in to Lumoria", "Forgot password?"
- Screenshot `login_sheet`

### S04 · Login → three tabs reachable
- Invoke login subflow
- Assert tab bar: "Memories", "All tickets", "Settings"
- Tap each tab, assert one stable element per tab
- Screenshot `tabs_after_login`

### S05 · Funnel launches
- Login subflow → tap "All tickets" → tap plus icon (funnel trigger)
- Assert: "New ticket", "Select a category"
- Discard → assert back on "All tickets"

---

## 3. Auth suite

### A01 · Signup happy path
- Landing → "Sign up"
- Fill Name, Email (`TEST_EMAIL_FRESH`), Password (strong: `Test123!abc`), Confirm
- Assert: "Strong" label appears, all 4 checklist bullets satisfied
- Tap "Create account"
- Assert alert: "Check your email"
- Tap "OK" → assert returned to Landing or Login

### A02 · Signup — password strength gating
- Fill weak password (`abc`)
- Assert: "Weak" label, "Create account" button **disabled**
- Improve to fair/good/strong, assert state transitions
- Screenshot each strength level

### A03 · Signup — password mismatch
- Password `Test123!abc`, Confirm `Test123!abd`
- Assert: "Create account" disabled (or inline error if shown)

### A04 · Signup — duplicate email
- Use existing `TEST_EMAIL`
- Submit → assert red error text containing "already" or Supabase error copy

### A05 · Login happy path
- Landing → "Log in" → fill creds → submit
- Assert: tab bar visible, "All tickets" header

### A06 · Login — wrong password
- Correct email, bad password
- Assert: red error, still on login sheet

### A07 · Login — empty fields
- Open login → assert "Log in" button disabled with either field empty

### A08 · Forgot password
- Login sheet → "Forgot password?"
- Assert sheet: "Update your password", "We'll email you a reset link."
- Enter email → "Send reset link"
- Assert: "Check your email" alert

### A09 · Log out
- Login → Settings → (logout control — verify path in app) → confirm
- Assert back on Landing

---

## 4. Ticket creation funnel

Funnel has 6 steps. Test the two available categories (Plane, Train) and representative templates. Locked categories (Park & Gardens, Public Transit, Concert) get a disabled-state check only.

### Subflow: open_funnel
Login → "All tickets" → tap plus icon → assert "New ticket", "Select a category".

### F01 · Abandon alert
- Open funnel → advance to step 2 → tap X
- Assert: "Discard ticket?" + "Keep crafting" / "Discard"
- Tap "Keep crafting" → still on funnel
- Tap X again → "Discard" → back on "All tickets"

### F02 · Locked categories disabled
- Open funnel
- Assert: "Park & Gardens", "Public Transit", "Concert" visible but non-interactive (tap is no-op — advance via visual state check or by asserting the step-2 title does not appear after tap)

### F03 · Plane — Afterglow — horizontal — happy path
- Open funnel
- Step 1: tap "Plane" → assert "Pick a template"
- Step 2: tap "Afterglow" → assert "Choose an orientation"
- Step 3: tap "Horizontal" → assert form step
- Step 4 (form): fill departure airport (e.g. "JFK"), arrival ("LAX"), date, flight number, airline, select cabin (Economy) → "Next" enabled → tap
- Step 5: pick first style variant → "Next"
- Step 6: assert success + "View ticket" (or equivalent CTA)
- Tap CTA → assert on TicketDetailView
- Screenshot each step

### F04 · Plane — Studio — vertical
Same structure as F03, Studio template, vertical orientation.

### F05 · Plane — each template smoke
Parameterized over Terminal, Heritage, Prism. Only asserts template step completion + final success (no deep form validation). Tag `regression`.

### F06 · Train — Express — happy path
- Plane → Train category
- Template: Express
- Form: departure station, arrival station, date, train number, cabin (Business/First/Second)
- Complete through success

### F07 · Train — Orient
Same as F06, Orient template.

### F08 · Train — Night train (sleeper)
- Category: Train → Night template
- Form variant shows berth classes: Lower / Middle / Upper / Single
- Assert each class selectable in dropdown
- Complete through success

### F09 · Form validation — required fields
- Enter form step with empty fields → "Next" disabled
- Fill one field at a time, assert button enables only after all required filled

### F10 · Back button behavior
- Advance to step 4 → tap "Back" three times → assert back on "Select a category"
- Forward data preserved? Assert previously tapped category still selected

### F11 · Template details sheet
- Step 2 → tap info icon on a template → assert sheet opens with template details
- Close sheet → still on template step, no selection applied

### F12 · Style variants live preview
- Reach step 5 → tap each visible style variant → assert preview visually updates (screenshot diff)

---

## 5. Memories (collections)

### M01 · Empty state
- Fresh login, no memories
- Memories tab → assert: "Your gallery starts here", helper text, "Memories" header
- Screenshot `memories_empty`

### M02 · Create memory
- Memories tab → tap "new memory" icon (plus)
- Assert NewMemoryView sheet
- Fill name, pick emoji, pick color
- Save → assert card appears in grid with correct name + emoji

### M03 · Open memory detail
- Tap memory card → assert MemoryDetailView with correct title, themed background
- Back → returns to Memories grid

### M04 · Edit memory
- MemoryDetailView → menu → "Edit" → change name → save
- Assert new name reflected in detail view and in grid

### M05 · Delete memory (with confirmation)
- Card context menu → "Delete"
- Assert confirmation alert
- Cancel → still present. Confirm → card removed

### M06 · Add ticket to memory from memory detail
- Prereq: at least one ticket exists (run F03 subflow)
- MemoryDetailView → menu → "Add existing ticket…"
- Assert sheet with ticket list → pick one → assert ticket now appears in memory

### M07 · Create new ticket inside memory
- MemoryDetailView → menu → "Add new ticket"
- Assert full-screen funnel opens
- Run through F03 → assert new ticket lands in this memory

### M08 · Remove ticket from memory
- Open ticket detail (via memory) → assert "Remove from memory…" visible
- Tap → confirm → assert ticket no longer in memory but still in All tickets

---

## 6. Ticket detail, export, share, delete

### T01 · Open ticket detail
- All tickets → tap first ticket → assert preview + details card
- Scroll → assert blur header applies

### T02 · Delete ticket
- Detail → menu → "Delete" → assert alert "Delete this ticket?"
- Cancel → still present. Confirm → returns to All tickets, ticket gone

### T03 · Create memory from ticket (no existing memories)
- Ticket detail → assert "Create memory…" button visible
- Tap → NewMemoryView sheet → create → assert association

### T04 · Add to memory (memories exist)
- Ticket detail → assert both "Create memory…" and "Add to memory…" visible
- Tap "Add to memory…" → pick memory → assert attached

### T05 · Export — Camera Roll — PNG 2x
- Ticket detail → menu → Export / Share action
- Phase A: assert social/IM locked, Camera roll enabled
- Tap Camera roll → Phase B
- Set Format=PNG, Resolution=2x
- Tap Export → grant Photos permission (first run)
- Assert success toast / dismissal

### T06 · Export — JPEG 3x
Variant of T05 with JPEG + 3x.

### T07 · Native share sheet
- Ticket detail → share → assert iOS share sheet visible (assertVisible "AirDrop" or "Copy")
- Dismiss

### T08 · Locked export destinations
- Phase A: assert social/IM buttons present but non-interactive

---

## 7. Settings

### SET01 · Settings landing
- Settings tab → assert "Settings" header, all rows: Notifications, Appearance, Referral (or "Invite"), Plan, Terms, Privacy, Contact
- Scroll → footer version visible

### SET02 · Profile edit — name
- Settings → profile card → ProfileView
- Change name → Save
- Assert returned to Settings, new name reflected

### SET03 · Profile edit — avatar
- ProfileView → tap avatar → Photos picker
- Pick image → AvatarCropSheet → confirm
- Save → assert new avatar renders

### SET04 · Notifications toggles
- Settings → Notifications
- If system auth denied: assert banner visible
- Toggle each row (Friend accepted invite, New templates, On this day, Memory milestones)
- Assert toggle state persists after backgrounding (`stopApp`/`launchApp` without `clearState`)

### SET05 · Appearance — theme
- Settings → Appearance → toggle Light/Dark/System
- Assert theme applied (screenshot diff on known element)

### SET06 · Appearance — high contrast
- Toggle "High contrast" → assert trait applied (screenshot diff)

### SET07 · Appearance — app icon
- Appearance → app icon grid → tap "Noir"
- Assert iOS system alert about icon change (tap OK)
- Leave app, check home screen icon changed — not automatable in Maestro; document as manual check
- In-app: assert Noir tile marked selected

### SET08 · Invite — generate & copy
- Settings → Referral → Invite
- State "not sent" → tap generate
- Assert URL visible, "Copy new link" button
- Tap Copy → assert toast "Link copied"

### SET09 · Invite — share
- Tap share → native share sheet visible → dismiss

### SET10 · Invite — revoke
- Tap Revoke → assert confirmation dialog
- Cancel → state preserved. Confirm → state returns to "not sent"

### SET11 · External links
- Tap Terms / Privacy / Contact → assert Safari / Mail opens (use `assertVisible` in Safari app via `launchApp`, or just confirm app backgrounded)

### SET12 · Plan placeholder
- Settings → Plan → assert placeholder view renders without crash (until StoreKit wired up)

---

## 8. Deep links

### D01 · Invite universal link — logged out
- Launch fresh (no auth)
- Run: `- openLink: "https://getlumoria.app/invite/TEST_TOKEN_123"`
- Assert: lands on Landing (token stashed). Sign in → assert invite claimed (inspect Memories or redeemed state — exact surface TBD)

### D02 · Invite universal link — logged in
- Login subflow → openLink with test token
- Assert: claim occurs, success toast or redirect

### D03 · Custom scheme
- `- openLink: "lumoria://invite/TEST_TOKEN_456"`
- Same assertions as D01/D02

### D04 · Invalid token
- Open invite link with garbage token
- Assert: graceful failure (no crash, error toast)

---

## 9. Sticker extension

Not directly testable via Maestro on the main app bundle. Plan:
- Manual test: install app → create 1+ horizontal ticket → install on device → open Messages → find Lumoria sticker pack → assert ticket appears.
- Automated proxy: add a debug screen in main app that renders the `StickerRenderView` visible and run pixel asserts against a golden image.

---

## 10. Regression suite (nightly)

Full run: auth (A01–A09) + funnel (F01–F12, parameterized) + memories (M01–M08) + tickets (T01–T08) + settings (SET01–SET12) + deep links (D01–D04).

Target duration: <20 min on M-series Mac runner. Parallelize by category (Maestro Cloud or multiple simulators).

---

## 11. Known gaps / manual test items

- **App icon change confirmation** (SET07): can only verify in-app state, not home screen.
- **StoreKit paywall** (SET12): stub only. Wire up `storeKitConfig` once implemented.
- **Sticker extension**: rasterization correctness verified manually.
- **Photos permission first-grant dialog**: handled by `- tapOn: "Allow Access to All Photos"` the first run; subsequent runs skip. Add conditional logic.
- **Email confirmation click**: Supabase confirm-email link can't be completed in Maestro. Either disable confirmation for staging project or test only the pre-confirm success state.

---

## 12. CI integration

- GitHub Actions on macOS runner
- Cache simulator + Xcode build between runs
- Build app once → upload `.app` → Maestro runs against cached build
- On smoke failure: block PR. On regression failure: Slack `#eng-mobile`.
- Store screenshots + `.maestro` logs as run artifacts (retain 14 days).

Local dev:
```
cd "Lumoria App"
xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" build
xcrun simctl install booted path/to/Lumoria.app
cd Maestro
maestro test flows/ --include-tags=smoke
```

---

## 13. Priority / phasing

**Phase 1 (week 1):** smoke (S01–S05), auth (A01, A05, A06), login subflow.
**Phase 2 (week 2):** funnel happy paths (F03, F06, F08), abandon (F01), delete ticket (T02).
**Phase 3 (week 3):** memories CRUD (M01–M05, M08), export (T05).
**Phase 4 (week 4):** settings (SET02, SET04, SET08–SET10), deep links (D01, D03).
**Phase 5 (ongoing):** parameterize templates (F05), regression nightly, flake triage.

Before Phase 1 merges: add `accessibilityIdentifier` to the following high-churn elements to stabilize matchers — funnel Next/Back/X buttons, each auth field, tab bar items, ticket card in grid, memory card in grid. Text matchers stay as fallback.
