# Paywall Phase 3 — Personalised Hero Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each of the 4 paywall variants its own visual identity — a SwiftUI hero composition + accent colour + refined copy — without changing any other piece of the paywall layout (plan card, CTA, restore, trust copy stay identical).

**Architecture:** A new `views/paywall/heroes/` module with one `View` per variant (`MemoryLimitHero`, `TicketLimitHero`, `MapSuiteHero`, `PremiumContentHero`). A `PaywallVariantStyle` extension on `PaywallTrigger.Variant` exposes accent colour + headline + subhead, so the hero compositions and the existing `PaywallView` body share a single source of truth for variant copy/colour. `PaywallView` swaps its current SF-symbol hero for a `PaywallHero(variant:)` dispatcher view that picks the right composition.

**Tech Stack:** SwiftUI shapes + gradients + `RoundedRectangle` + `MapPolyline`-style curves. No new third-party deps. No new tests (pure visual change).

**Reference:** [`docs/superpowers/specs/2026-04-25-paywall-and-monetisation-design.md`](../specs/2026-04-25-paywall-and-monetisation-design.md) — Section F **Phase 3** entry (illustration sourcing addendum).

---

## File Structure

**iOS — paywall hero module (new):**
- Create: `Lumoria App/views/paywall/PaywallVariantStyle.swift` — `PaywallTrigger.Variant` extension exposing `accent`, `headline`, `subhead`.
- Create: `Lumoria App/views/paywall/heroes/PaywallHero.swift` — dispatcher view that routes to the right composition by variant.
- Create: `Lumoria App/views/paywall/heroes/MemoryLimitHero.swift` — stacked memory cards with a ghosted "+1?".
- Create: `Lumoria App/views/paywall/heroes/TicketLimitHero.swift` — fanned ticket stack.
- Create: `Lumoria App/views/paywall/heroes/MapSuiteHero.swift` — curved dotted polyline + pins.
- Create: `Lumoria App/views/paywall/heroes/PremiumContentHero.swift` — 3×2 template-thumb grid with locks.

**iOS — modified:**
- Modify: `Lumoria App/views/paywall/PaywallView.swift` — replace the current SF-symbol hero with `PaywallHero(variant:)`. Use `PaywallVariantStyle` for headline/subhead too so copy lives in one place.

---

### Task 1: PaywallVariantStyle — single source for variant copy + accent

**Files:**
- Create: `Lumoria App/views/paywall/PaywallVariantStyle.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  PaywallVariantStyle.swift
//  Lumoria App
//
//  Per-variant copy + accent colour. Shared by the hero compositions
//  and PaywallView so the four variants can't drift apart over time.
//

import SwiftUI

extension PaywallTrigger.Variant {

    /// Accent colour applied to the hero radial gradient and the lead
    /// SF symbol of each composition.
    var accent: Color {
        switch self {
        case .memoryLimit:    return Color(red: 0.95, green: 0.51, blue: 0.55) // coral
        case .ticketLimit:    return Color(red: 0.50, green: 0.45, blue: 0.92) // indigo
        case .mapSuite:       return Color(red: 0.21, green: 0.74, blue: 0.78) // teal
        case .premiumContent: return Color(red: 0.95, green: 0.74, blue: 0.27) // amber
        }
    }

    var headline: String {
        switch self {
        case .memoryLimit:    return "Unlimited memories."
        case .ticketLimit:    return "Unlimited tickets."
        case .mapSuite:       return "Your trips, told."
        case .premiumContent: return "The full catalogue."
        }
    }

    var subhead: String {
        switch self {
        case .memoryLimit:
            return "Free covers 3 memories. Premium has no cap."
        case .ticketLimit:
            return "Free covers 5 tickets. Premium has no cap."
        case .mapSuite:
            return "Premium unlocks the timeline scrub, journey path, and full map export."
        case .premiumContent:
            return "Premium unlocks every template, every category, and the iOS sticker pack."
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
git add "Lumoria App/views/paywall/PaywallVariantStyle.swift"
git commit -m "feat(paywall): single source for per-variant accent + copy"
```

---

### Task 2: PaywallHero dispatcher + MemoryLimitHero composition

**Files:**
- Create: `Lumoria App/views/paywall/heroes/PaywallHero.swift`
- Create: `Lumoria App/views/paywall/heroes/MemoryLimitHero.swift`

- [ ] **Step 1: Write PaywallHero**

```swift
//
//  PaywallHero.swift
//  Lumoria App
//
//  Dispatcher view — picks the right composition by variant. The
//  hero block sits at the top of PaywallView; below it the rest of
//  the paywall (plan card / CTA / restore / trust copy) stays
//  identical across variants.
//

import SwiftUI

struct PaywallHero: View {
    let variant: PaywallTrigger.Variant

    var body: some View {
        ZStack {
            // Soft radial gradient backdrop in the variant accent.
            RadialGradient(
                colors: [variant.accent.opacity(0.25), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 240
            )
            .frame(height: 280)
            .blur(radius: 20)
            .allowsHitTesting(false)

            VStack(spacing: 16) {
                composition
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)

                Text(variant.headline)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(variant.subhead)
                    .font(.title3)
                    .foregroundStyle(Color.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 24)
        }
    }

    @ViewBuilder
    private var composition: some View {
        switch variant {
        case .memoryLimit:    MemoryLimitHero()
        case .ticketLimit:    TicketLimitHero()
        case .mapSuite:       MapSuiteHero()
        case .premiumContent: PremiumContentHero()
        }
    }
}

#Preview("memoryLimit") {
    PaywallHero(variant: .memoryLimit).padding(24)
}

#Preview("ticketLimit") {
    PaywallHero(variant: .ticketLimit).padding(24)
}

#Preview("mapSuite") {
    PaywallHero(variant: .mapSuite).padding(24)
}

#Preview("premiumContent") {
    PaywallHero(variant: .premiumContent).padding(24)
}
```

- [ ] **Step 2: Write MemoryLimitHero**

```swift
//
//  MemoryLimitHero.swift
//  Lumoria App
//
//  Three filled "memory" cards stacked left-to-right with a ghosted
//  fourth card behind them — visualising the free-tier ceiling.
//

import SwiftUI

struct MemoryLimitHero: View {

    private let accent = PaywallTrigger.Variant.memoryLimit.accent

    var body: some View {
        ZStack {
            // Ghost "4th" card — the locked one.
            card(emoji: "🔒", filled: false)
                .offset(x: 80, y: 12)
                .opacity(0.5)

            // 3 filled memory cards (the free-tier limit).
            card(emoji: "🎟️", filled: true)
                .offset(x: -56, y: -12)
                .rotationEffect(.degrees(-6))

            card(emoji: "✈️", filled: true)
                .offset(x: 0, y: 0)

            card(emoji: "🎵", filled: true)
                .offset(x: 56, y: -8)
                .rotationEffect(.degrees(6))
        }
    }

    private func card(emoji: String, filled: Bool) -> some View {
        let bg: AnyShapeStyle = filled
            ? AnyShapeStyle(LinearGradient(
                colors: [accent.opacity(0.95), accent.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ))
            : AnyShapeStyle(Color.gray.opacity(0.15))
        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(bg)
            .frame(width: 92, height: 124)
            .overlay(
                Text(emoji)
                    .font(.system(size: 36))
                    .opacity(filled ? 1 : 0.6)
            )
            .shadow(color: filled ? accent.opacity(0.35) : .clear,
                    radius: 12, y: 6)
    }
}

#Preview {
    MemoryLimitHero().frame(height: 200).padding(24)
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -5
```

Expected: BUILD SUCCEEDED. (Compiles even though `TicketLimitHero` / `MapSuiteHero` / `PremiumContentHero` don't exist yet — the dispatcher's switch will error if not all cases are present; we'll add the others in Tasks 3–5.)

If the dispatcher fails to compile because of missing variant cases, replace the `composition` body temporarily with `MemoryLimitHero()` for all four cases and revert in Task 5.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/paywall/heroes/PaywallHero.swift" \
        "Lumoria App/views/paywall/heroes/MemoryLimitHero.swift"
git commit -m "feat(paywall): PaywallHero dispatcher + memoryLimit composition"
```

---

### Task 3: TicketLimitHero composition

**Files:**
- Create: `Lumoria App/views/paywall/heroes/TicketLimitHero.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  TicketLimitHero.swift
//  Lumoria App
//
//  Five fanned ticket-shaped tiles representing the free-tier ticket
//  cap, with a sixth ghosted ticket behind them as the "more"
//  affordance.
//

import SwiftUI

struct TicketLimitHero: View {

    private let accent = PaywallTrigger.Variant.ticketLimit.accent

    var body: some View {
        ZStack {
            // Ghost "6th" ticket peeking out behind.
            ticket(filled: false)
                .rotationEffect(.degrees(8))
                .offset(x: 0, y: 16)
                .opacity(0.4)

            // The 5 free tickets, fanned.
            ForEach(0..<5, id: \.self) { i in
                let angle = Double(i - 2) * 6.0
                let xOffset = CGFloat(i - 2) * 12
                ticket(filled: true)
                    .rotationEffect(.degrees(angle))
                    .offset(x: xOffset, y: 0)
            }
        }
    }

    private func ticket(filled: Bool) -> some View {
        let bg: AnyShapeStyle = filled
            ? AnyShapeStyle(LinearGradient(
                colors: [accent.opacity(0.95), accent.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
              ))
            : AnyShapeStyle(Color.gray.opacity(0.15))
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(bg)
            .frame(width: 80, height: 130)
            .overlay(
                VStack(spacing: 8) {
                    Capsule()
                        .fill(Color.white.opacity(filled ? 0.6 : 0.3))
                        .frame(width: 32, height: 4)
                    Capsule()
                        .fill(Color.white.opacity(filled ? 0.4 : 0.2))
                        .frame(width: 48, height: 4)
                    Spacer()
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(filled ? 0.85 : 0.4))
                        .padding(.bottom, 12)
                }
                .padding(.top, 18)
            )
            .shadow(color: filled ? accent.opacity(0.3) : .clear,
                    radius: 8, y: 4)
    }
}

#Preview {
    TicketLimitHero().frame(height: 200).padding(24)
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
git add "Lumoria App/views/paywall/heroes/TicketLimitHero.swift"
git commit -m "feat(paywall): ticketLimit hero — fanned ticket stack"
```

---

### Task 4: MapSuiteHero composition

**Files:**
- Create: `Lumoria App/views/paywall/heroes/MapSuiteHero.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  MapSuiteHero.swift
//  Lumoria App
//
//  Curved dotted polyline with three pin dots — mirrors the look of
//  the actual MemoryMapView story-mode journey path so users
//  recognise the feature in the wild.
//

import SwiftUI

struct MapSuiteHero: View {

    private let accent = PaywallTrigger.Variant.mapSuite.accent

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                // Stylised map base — a soft rounded-corner field.
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(accent.opacity(0.08))

                // Faint grid lines for the "map" texture.
                Path { p in
                    let step: CGFloat = 24
                    var x: CGFloat = step
                    while x < w {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                        x += step
                    }
                    var y: CGFloat = step
                    while y < h {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                        y += step
                    }
                }
                .stroke(accent.opacity(0.15), lineWidth: 0.5)

                // Curved dotted journey path through three pin points.
                Path { p in
                    p.move(to: CGPoint(x: w * 0.15, y: h * 0.7))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.5, y: h * 0.3),
                        control: CGPoint(x: w * 0.3, y: h * 0.05)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.85, y: h * 0.65),
                        control: CGPoint(x: w * 0.7, y: h * 0.05)
                    )
                }
                .stroke(
                    accent,
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round,
                        dash: [2, 8]
                    )
                )

                // Three pin dots along the curve.
                pin(at: CGPoint(x: w * 0.15, y: h * 0.7))
                pin(at: CGPoint(x: w * 0.5,  y: h * 0.3))
                pin(at: CGPoint(x: w * 0.85, y: h * 0.65))
            }
        }
        .padding(.horizontal, 16)
    }

    private func pin(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .shadow(color: accent.opacity(0.4), radius: 6, y: 2)
            Circle()
                .fill(accent)
                .frame(width: 14, height: 14)
        }
        .position(point)
    }
}

#Preview {
    MapSuiteHero().frame(height: 200).padding(24)
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
git add "Lumoria App/views/paywall/heroes/MapSuiteHero.swift"
git commit -m "feat(paywall): mapSuite hero — curved journey path with pins"
```

---

### Task 5: PremiumContentHero composition

**Files:**
- Create: `Lumoria App/views/paywall/heroes/PremiumContentHero.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  PremiumContentHero.swift
//  Lumoria App
//
//  3×2 grid of small ticket-template thumbnails — first two unlocked,
//  remaining four locked. Visualises the "full catalogue" message:
//  free users get a couple of templates, paying users get every one.
//

import SwiftUI

struct PremiumContentHero: View {

    private let accent = PaywallTrigger.Variant.premiumContent.accent

    private let tiles: [(symbol: String, locked: Bool, tint: Color)] = [
        ("airplane.circle.fill",      false, .blue),
        ("tram.circle.fill",          false, .red),
        ("music.note.list",           true,  .pink),
        ("ticket.fill",               true,  .purple),
        ("fork.knife.circle.fill",    true,  .orange),
        ("film.fill",                 true,  .indigo),
    ]

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]

        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(tiles.indices, id: \.self) { i in
                tile(tiles[i])
            }
        }
        .frame(maxWidth: 280)
    }

    private func tile(_ t: (symbol: String, locked: Bool, tint: Color)) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(t.tint.opacity(t.locked ? 0.12 : 0.18))
                .aspectRatio(1, contentMode: .fit)

            Image(systemName: t.symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(t.tint.opacity(t.locked ? 0.5 : 1))

            if t.locked {
                ZStack {
                    Circle().fill(.white)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent)
                }
                .frame(width: 22, height: 22)
                .offset(x: 22, y: -22)
                .shadow(radius: 2, y: 1)
            }
        }
    }
}

#Preview {
    PremiumContentHero().frame(height: 200).padding(24)
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -5
```

Expected: BUILD SUCCEEDED. All four hero compositions now compile against the dispatcher's exhaustive switch.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/views/paywall/heroes/PremiumContentHero.swift"
git commit -m "feat(paywall): premiumContent hero — locked template grid"
```

---

### Task 6: Wire PaywallHero into PaywallView

**Files:**
- Modify: `Lumoria App/views/paywall/PaywallView.swift`

- [ ] **Step 1: Replace the SF-symbol hero block**

Locate the `hero` computed property in `PaywallView` (currently uses `Image(systemName: heroSymbol)` + `Text(headline)` + `Text(subhead)`) and replace it with a single `PaywallHero` call. Also delete the now-redundant `heroSymbol`, `headline`, and `subhead` helpers — `PaywallVariantStyle` is the source of truth now.

The full target shape of the property:

```swift
private var hero: some View {
    PaywallHero(variant: trigger.variant)
}
```

Remove from the file:

```swift
private var heroSymbol: String { ... }
private var headline: String { ... }
private var subhead: String { ... }
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run the existing paywall test suites to confirm no regressions**

```bash
xcodebuild test \
  -scheme "Lumoria App" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:"Lumoria AppTests/EntitlementStoreTests" \
  -only-testing:"Lumoria AppTests/EntitlementStoreMonetisationOffTests" \
  -only-testing:"Lumoria AppTests/CapLogicTests" \
  -only-testing:"Lumoria AppTests/AppSettingsServiceTests" \
  -only-testing:"Lumoria AppTests/ProfileDecodingTests" \
  2>&1 | grep -E "\*\* TEST" | tail -3
```

Expected: `** TEST SUCCEEDED **` (17 tests).

- [ ] **Step 4: Manual smoke check (simulator)**

The kill-switch is OFF on the live DB so the paywall won't present in the running app. Two paths to preview:

1. Open `PaywallHero.swift` and run the four `#Preview` blocks (Xcode preview canvas) — verify each variant renders with its accent + composition.
2. Or temporarily flip the kill-switch on the local sandbox profile, hit a gated CTA, eyeball each variant by triggering memory cap / ticket cap / "See plans" from Settings.

Goal: each variant looks visually distinct; the rest of the paywall (plan card / CTA / restore / trust copy) is unchanged from Phase 2.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/paywall/PaywallView.swift"
git commit -m "feat(paywall): wire PaywallHero into PaywallView, drop SF-symbol hero"
```

---

## Self-Review

- **Spec coverage:**
  - Phase 3 "4 hero blocks (illustration + headline + subhead) for memoryLimit / ticketLimit / mapSuite / premiumContent" → Tasks 2–5 (one composition per variant) + Task 1 (single source for headline/subhead). ✓
  - "Wire each gated CTA to its trigger" → already done in Phase 1/2 (PaywallTrigger.variant routing); Task 6 only swaps the hero block contents. ✓
  - Per-variant accent + radial gradient backdrop addendum → Task 1 (accent on Variant) + Task 2 (PaywallHero backdrop). ✓
- **Placeholder scan:** No "TODO" / "TBD" / vague verbs. Each step shows the actual code or the actual command.
- **Type consistency:** `PaywallTrigger.Variant.memoryLimit` etc. spelled identically in Tasks 1–6. The accent colour values are typed as `Color(red:green:blue:)` literals in Task 1 and re-read by `var accent: Color` in Tasks 2–5. The dispatcher switch in Task 2 covers all four variant cases — Task 5 closes the exhaustiveness gap.
- **Ambiguity check:** Task 6 says "delete the now-redundant `heroSymbol`, `headline`, and `subhead` helpers" — exact symbol names that exist in the current PaywallView. Step 1 also gives the exact target shape of the replacement property.

## Out of scope (Phase 3)

- Custom designer-supplied illustrations (post-Phase 3 polish — swap the SwiftUI compositions for raster/SVG art when assets ship).
- Per-variant analytics (`paywallViewed(source:)` already fires in Phase 2; no extra event needed).
- Phase 4 invite-as-reward UI.

## Phase 3 deliverable on completion

Each of the four paywall variants renders a visually distinct hero block — coral memory-card stack, indigo fanned ticket pile, teal map-curve, amber locked template grid — with a soft radial accent backdrop and the same headline/subhead it had at the end of Phase 2. The rest of the paywall layout is unchanged. No new tests, no schema changes, no analytics events.
