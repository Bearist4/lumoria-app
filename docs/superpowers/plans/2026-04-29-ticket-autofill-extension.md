# Ticket Autofill — Plane + Train Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing `applyAestheticDefaults()` in `NewTicketFunnel` so plane and train templates fill blank slot-style fields (gate, seat, terminal, car, berth) with template-appropriate random values when the user advances from the form step.

**Architecture:** Add small private static generators next to the existing `randomRef` / `randomTransitTicketNumber` helpers, then replace the plane/train `break` stub in the per-template switch with explicit per-group cases that mirror the concert and underground branches. Reuses `autoFilledFields[]` and the existing success-step notice.

**Tech Stack:** SwiftUI / Swift Testing / `NewTicketFunnel` `@MainActor` `ObservableObject`.

**Spec:** `docs/superpowers/specs/2026-04-29-ticket-autofill-extension-design.md`

---

## File Structure

| File | Responsibility |
|---|---|
| `Lumoria App/views/tickets/new/NewTicketFunnel.swift` | Add 6 private static generators. Replace plane/train switch stub in `applyAestheticDefaults()` with 5 per-group cases. |
| `Lumoria AppTests/NewTicketFunnelAutofillTests.swift` | NEW — 7 Swift Testing cases covering each new branch and the cross-cutting invariants. |
| `Lumoria App/Localizable.xcstrings` | Auto-extracted on next Xcode IDE open (Gate, Seat, Terminal, Car, Berth). No manual edit. |

`applyAestheticDefaults()` is private but `advance()` is internal — tests drive it via `advance()` from `step = .form`, no visibility changes needed.

---

## Task 1: Add generators

**Files:**
- Modify: `Lumoria App/views/tickets/new/NewTicketFunnel.swift` (append next to `randomRef` / `randomTransitTicketNumber`).

- [ ] **Step 1.1: Add the 6 private static generators**

Open `Lumoria App/views/tickets/new/NewTicketFunnel.swift`. Find the existing `private static func randomTransitTicketNumber(length: Int = 10) -> String { ... }` definition (around line 738). Immediately after its closing brace, before the next existing helper (`defaultFare(for:)`), insert:

```swift
    // MARK: - Plane / train slot generators

    /// Plane gate, e.g. "A12", "F32". Letters A–H × 1…60.
    private static func randomGate() -> String {
        let letter = "ABCDEFGH".randomElement()!
        return "\(letter)\(Int.random(in: 1...60))"
    }

    /// Airline-style seat, e.g. "1A", "14C", "27K". Skips letter "I"
    /// per airline convention.
    private static func randomSeatNumberLetter() -> String {
        let row = Int.random(in: 1...40)
        let letter = "ABCDEFGHJK".randomElement()!
        return "\(row)\(letter)"
    }

    /// European-rail style seat — number only, e.g. "47".
    private static func randomSeatNumber() -> String {
        "\(Int.random(in: 1...80))"
    }

    /// Plane terminal label, e.g. "T3". Range T1…T5 covers the
    /// realistic span for the templates we ship.
    private static func randomPlaneTerminal() -> String {
        "T\(Int.random(in: 1...5))"
    }

    /// Train carriage / car number, e.g. "7", "12". Range 1…18 covers
    /// typical European inter-city consist lengths.
    private static func randomCar() -> String {
        "\(Int.random(in: 1...18))"
    }

    /// Sleeper-train berth label.
    private static func randomBerth() -> String {
        ["Lower", "Upper", "Single", "Cabin"].randomElement()!
    }
```

- [ ] **Step 1.2: Build to confirm helpers compile**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1" build 2>&1 | grep -E "error:|BUILD" | head`
Expected: `** BUILD SUCCEEDED **` (no errors). Helpers are unused at this point — that's fine, they're private + Swift won't warn for static helpers.

- [ ] **Step 1.3: Commit**

```bash
cd "Lumoria App" && git add "Lumoria App/views/tickets/new/NewTicketFunnel.swift"
git commit -m "feat(tickets): add plane/train slot value generators"
```

---

## Task 2: Plane basic templates (afterglow / studio / terminal / heritage)

**Files:**
- Create: `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`
- Modify: `Lumoria App/views/tickets/new/NewTicketFunnel.swift` (replace plane/train stub).

- [ ] **Step 2.1: Write the failing test**

Create `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`:

```swift
//
//  NewTicketFunnelAutofillTests.swift
//  Lumoria AppTests
//

import Foundation
import Testing
@testable import Lumoria_App

@MainActor
@Test func autofill_planeBasic_fillsGateAndSeat_whenBlank() async throws {
    let funnel = NewTicketFunnel()
    funnel.template = .afterglow
    funnel.step = .form
    funnel.form.gate = ""
    funnel.form.seat = ""

    funnel.advance()

    #expect(!funnel.form.gate.isEmpty)
    #expect(!funnel.form.seat.isEmpty)
    #expect(funnel.autoFilledFields.contains("Gate"))
    #expect(funnel.autoFilledFields.contains("Seat"))
}
```

- [ ] **Step 2.2: Run the test — verify it fails**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1" -only-testing:"Lumoria AppTests/autofill_planeBasic_fillsGateAndSeat_whenBlank" 2>&1 | tail -5`

Expected: `** TEST FAILED **`. The afterglow case currently hits the `break` stub in `applyAestheticDefaults()`, so `form.gate`/`form.seat` stay empty.

- [ ] **Step 2.3: Replace the plane/train stub with the basic-plane case**

Open `Lumoria App/views/tickets/new/NewTicketFunnel.swift`. Find the existing block (around line 701):

```swift
        case .afterglow, .studio, .heritage, .terminal, .prism,
             .express, .orient, .night, .post, .glow:
            // Plane / train templates already fall through to "Class",
            // "Business" etc. defaults inside `buildPayload`. Extend
            // here when a template gains new aesthetic placeholders.
            break
```

Replace with:

```swift
        case .afterglow, .studio, .terminal, .heritage:
            if trim(form.gate).isEmpty {
                form.gate = Self.randomGate()
                autoFilledFields.append(String(localized: "Gate"))
            }
            if trim(form.seat).isEmpty {
                form.seat = Self.randomSeatNumberLetter()
                autoFilledFields.append(String(localized: "Seat"))
            }

        case .prism, .express, .orient, .night, .post, .glow:
            // Filled in by subsequent tasks. Stub for now so the switch
            // remains exhaustive while plane/train migrates incrementally.
            break
```

- [ ] **Step 2.4: Re-run the test — verify it passes**

Run: same command as 2.2.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2.5: Commit**

```bash
git add "Lumoria App/views/tickets/new/NewTicketFunnel.swift" "Lumoria AppTests/NewTicketFunnelAutofillTests.swift"
git commit -m "feat(tickets): autofill gate + seat for basic plane templates"
```

---

## Task 3: Prism (plane with terminal)

**Files:**
- Modify: `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`
- Modify: `Lumoria App/views/tickets/new/NewTicketFunnel.swift`

- [ ] **Step 3.1: Append the failing test**

Append to `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`:

```swift
@MainActor
@Test func autofill_prism_alsoFillsTerminal() async throws {
    let funnel = NewTicketFunnel()
    funnel.template = .prism
    funnel.step = .form
    funnel.form.gate = ""
    funnel.form.seat = ""
    funnel.form.terminal = ""

    funnel.advance()

    #expect(!funnel.form.gate.isEmpty)
    #expect(!funnel.form.seat.isEmpty)
    #expect(!funnel.form.terminal.isEmpty)
    #expect(funnel.autoFilledFields == ["Gate", "Seat", "Terminal"])
}
```

- [ ] **Step 3.2: Run the test — verify it fails**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1" -only-testing:"Lumoria AppTests/autofill_prism_alsoFillsTerminal" 2>&1 | tail -5`

Expected: `** TEST FAILED **`. Prism currently sits in the stub case from Task 2.3.

- [ ] **Step 3.3: Add the prism case to the switch**

In `applyAestheticDefaults()`, replace the stub case from Task 2.3:

```swift
        case .prism, .express, .orient, .night, .post, .glow:
            break
```

with:

```swift
        case .prism:
            if trim(form.gate).isEmpty {
                form.gate = Self.randomGate()
                autoFilledFields.append(String(localized: "Gate"))
            }
            if trim(form.seat).isEmpty {
                form.seat = Self.randomSeatNumberLetter()
                autoFilledFields.append(String(localized: "Seat"))
            }
            if trim(form.terminal).isEmpty {
                form.terminal = Self.randomPlaneTerminal()
                autoFilledFields.append(String(localized: "Terminal"))
            }

        case .express, .orient, .night, .post, .glow:
            // Filled in by subsequent tasks.
            break
```

- [ ] **Step 3.4: Re-run the test — verify it passes**

Run: same command as 3.2.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3.5: Commit**

```bash
git add "Lumoria App/views/tickets/new/NewTicketFunnel.swift" "Lumoria AppTests/NewTicketFunnelAutofillTests.swift"
git commit -m "feat(tickets): autofill terminal on prism in addition to gate + seat"
```

---

## Task 4: Train number-only seat (post / glow / orient)

**Files:**
- Modify: `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`
- Modify: `Lumoria App/views/tickets/new/NewTicketFunnel.swift`

- [ ] **Step 4.1: Append the failing test**

Append to `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`:

```swift
@MainActor
@Test func autofill_trainNumberOnlySeat_forPost() async throws {
    let funnel = NewTicketFunnel()
    funnel.template = .post
    funnel.step = .form
    funnel.trainForm.car = ""
    funnel.trainForm.seat = ""

    funnel.advance()

    #expect(!funnel.trainForm.car.isEmpty)
    #expect(!funnel.trainForm.seat.isEmpty)
    let seat = funnel.trainForm.seat
    #expect(seat.range(of: "^[0-9]+$", options: .regularExpression) != nil,
            "expected number-only seat for post, got \(seat)")
    #expect(funnel.autoFilledFields == ["Car", "Seat"])
}
```

- [ ] **Step 4.2: Run the test — verify it fails**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1" -only-testing:"Lumoria AppTests/autofill_trainNumberOnlySeat_forPost" 2>&1 | tail -5`

Expected: `** TEST FAILED **`.

- [ ] **Step 4.3: Add the post/glow/orient case**

In `applyAestheticDefaults()`, replace the stub case from Task 3.3:

```swift
        case .express, .orient, .night, .post, .glow:
            break
```

with:

```swift
        case .post, .glow, .orient:
            if trim(trainForm.car).isEmpty {
                trainForm.car = Self.randomCar()
                autoFilledFields.append(String(localized: "Car"))
            }
            if trim(trainForm.seat).isEmpty {
                trainForm.seat = Self.randomSeatNumber()
                autoFilledFields.append(String(localized: "Seat"))
            }

        case .express, .night:
            // Filled in by subsequent tasks.
            break
```

- [ ] **Step 4.4: Re-run the test — verify it passes**

Run: same command as 4.2.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4.5: Commit**

```bash
git add "Lumoria App/views/tickets/new/NewTicketFunnel.swift" "Lumoria AppTests/NewTicketFunnelAutofillTests.swift"
git commit -m "feat(tickets): autofill car + numeric seat for post/glow/orient"
```

---

## Task 5: Train number+letter seat (express)

**Files:**
- Modify: `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`
- Modify: `Lumoria App/views/tickets/new/NewTicketFunnel.swift`

- [ ] **Step 5.1: Append the failing test**

Append to `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`:

```swift
@MainActor
@Test func autofill_trainNumberLetterSeat_forExpress() async throws {
    let funnel = NewTicketFunnel()
    funnel.template = .express
    funnel.step = .form
    funnel.trainForm.car = ""
    funnel.trainForm.seat = ""

    funnel.advance()

    #expect(!funnel.trainForm.car.isEmpty)
    let seat = funnel.trainForm.seat
    // ABCDEFGHJK alphabet — skips I per airline convention.
    #expect(seat.range(of: "^[0-9]+[A-HJK]$", options: .regularExpression) != nil,
            "expected number+letter seat for express, got \(seat)")
    #expect(funnel.autoFilledFields == ["Car", "Seat"])
}
```

- [ ] **Step 5.2: Run the test — verify it fails**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1" -only-testing:"Lumoria AppTests/autofill_trainNumberLetterSeat_forExpress" 2>&1 | tail -5`

Expected: `** TEST FAILED **`.

- [ ] **Step 5.3: Add the express case**

In `applyAestheticDefaults()`, replace the stub case from Task 4.3:

```swift
        case .express, .night:
            break
```

with:

```swift
        case .express:
            if trim(trainForm.car).isEmpty {
                trainForm.car = Self.randomCar()
                autoFilledFields.append(String(localized: "Car"))
            }
            if trim(trainForm.seat).isEmpty {
                trainForm.seat = Self.randomSeatNumberLetter()
                autoFilledFields.append(String(localized: "Seat"))
            }

        case .night:
            // Filled in by Task 6.
            break
```

- [ ] **Step 5.4: Re-run the test — verify it passes**

Run: same command as 5.2.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5.5: Commit**

```bash
git add "Lumoria App/views/tickets/new/NewTicketFunnel.swift" "Lumoria AppTests/NewTicketFunnelAutofillTests.swift"
git commit -m "feat(tickets): autofill car + alphanumeric seat for express"
```

---

## Task 6: Sleeper train (night — fills berth, not seat)

**Files:**
- Modify: `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`
- Modify: `Lumoria App/views/tickets/new/NewTicketFunnel.swift`

- [ ] **Step 6.1: Append the failing test**

Append to `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`:

```swift
@MainActor
@Test func autofill_night_fillsBerth_notSeat() async throws {
    let funnel = NewTicketFunnel()
    funnel.template = .night
    funnel.step = .form
    funnel.trainForm.car = ""
    funnel.trainForm.seat = ""
    funnel.trainForm.berth = ""

    funnel.advance()

    #expect(!funnel.trainForm.car.isEmpty)
    #expect(funnel.trainForm.seat.isEmpty,
            "night uses berth, not seat — seat must stay blank")
    #expect(["Lower", "Upper", "Single", "Cabin"].contains(funnel.trainForm.berth))
    #expect(funnel.autoFilledFields == ["Car", "Berth"])
    #expect(!funnel.autoFilledFields.contains("Seat"))
}
```

- [ ] **Step 6.2: Run the test — verify it fails**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1" -only-testing:"Lumoria AppTests/autofill_night_fillsBerth_notSeat" 2>&1 | tail -5`

Expected: `** TEST FAILED **`.

- [ ] **Step 6.3: Add the night case**

In `applyAestheticDefaults()`, replace the stub case from Task 5.3:

```swift
        case .night:
            // Filled in by Task 6.
            break
```

with:

```swift
        case .night:
            if trim(trainForm.car).isEmpty {
                trainForm.car = Self.randomCar()
                autoFilledFields.append(String(localized: "Car"))
            }
            if trim(trainForm.berth).isEmpty {
                trainForm.berth = Self.randomBerth()
                autoFilledFields.append(String(localized: "Berth"))
            }
```

- [ ] **Step 6.4: Re-run the test — verify it passes**

Run: same command as 6.2.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6.5: Commit**

```bash
git add "Lumoria App/views/tickets/new/NewTicketFunnel.swift" "Lumoria AppTests/NewTicketFunnelAutofillTests.swift"
git commit -m "feat(tickets): autofill car + berth for night sleeper template"
```

---

## Task 7: Cross-cutting regressions

**Files:**
- Modify: `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`

- [ ] **Step 7.1: Append the regression tests**

Append to `Lumoria AppTests/NewTicketFunnelAutofillTests.swift`:

```swift
@MainActor
@Test func autofill_skipsAlreadyFilledFields() async throws {
    let funnel = NewTicketFunnel()
    funnel.template = .afterglow
    funnel.step = .form
    funnel.form.gate = "F32"
    funnel.form.seat = ""

    funnel.advance()

    #expect(funnel.form.gate == "F32",
            "user-entered value must never be overwritten")
    #expect(!funnel.form.seat.isEmpty)
    #expect(funnel.autoFilledFields == ["Seat"],
            "only blank fields should be reported as auto-filled")
}

@MainActor
@Test func autofill_listsExactlyNewlyFilledLabels_inOrder() async throws {
    let funnel = NewTicketFunnel()
    funnel.template = .prism
    funnel.step = .form
    funnel.form.gate = ""
    funnel.form.seat = "11A"   // pre-filled — not in autoFilledFields
    funnel.form.terminal = ""

    funnel.advance()

    #expect(funnel.autoFilledFields == ["Gate", "Terminal"],
            "labels appear in the order the switch processes them, " +
            "skipping pre-filled slots")
}
```

- [ ] **Step 7.2: Run the regression tests**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1" -only-testing:"Lumoria AppTests/autofill_skipsAlreadyFilledFields" -only-testing:"Lumoria AppTests/autofill_listsExactlyNewlyFilledLabels_inOrder" 2>&1 | tail -5`

Expected: `** TEST SUCCEEDED **`. These should pass without code changes — implementations from Tasks 2 & 3 already guard with `if trim(...).isEmpty`.

If a test fails: stop and inspect — most likely cause is a missing `if trim(...).isEmpty` guard on one of the per-template branches.

- [ ] **Step 7.3: Commit**

```bash
git add "Lumoria AppTests/NewTicketFunnelAutofillTests.swift"
git commit -m "test(tickets): regression coverage for autofill skip + ordering"
```

---

## Task 8: Full suite verification + manual smoke

- [ ] **Step 8.1: Run the entire AutofillTests file**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1" -only-testing:"Lumoria AppTests/NewTicketFunnelAutofillTests" 2>&1 | tail -5`

Expected: `** TEST SUCCEEDED **`. All 7 tests pass:
- autofill_planeBasic_fillsGateAndSeat_whenBlank
- autofill_prism_alsoFillsTerminal
- autofill_trainNumberOnlySeat_forPost
- autofill_trainNumberLetterSeat_forExpress
- autofill_night_fillsBerth_notSeat
- autofill_skipsAlreadyFilledFields
- autofill_listsExactlyNewlyFilledLabels_inOrder

- [ ] **Step 8.2: Run the broader test suite to confirm no regressions**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1" -only-testing:"Lumoria AppTests" 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|failed" | tail -3`

Expected: `** TEST SUCCEEDED **`. If a flaky pre-existing test fails (e.g. `StickerRenderLifecycleTests`), retry once before investigating.

- [ ] **Step 8.3: Manual smoke in the simulator**

Open Xcode, run on iPhone 17 Pro. Walk:

1. New ticket → Plane → Afterglow → fill required fields, leave gate + seat blank → Next.
2. On the success step, the "✨ We filled in Gate, Seat for you" notice appears.
3. Save the ticket and open it from the gallery — gate and seat render in their slots.
4. Repeat once with Train → Night, leaving car + berth blank → expect "Car, Berth" notice.

If anything looks wrong, open a follow-up; don't patch in this PR unless it's a one-line copy fix.

- [ ] **Step 8.4: Final commit (if any non-code touch-ups)**

If Steps 8.1–8.3 pass cleanly, no commit needed — the per-task commits are the deliverable.

---

## Self-review

**Spec coverage:**

- Generators (afterglow gate `A12`, seat `14A`, terminal `T3`, train car `7`, seats `47` / `14A`, berth `Lower|…`) — ✓ Task 1.
- Plane basic group (afterglow / studio / terminal / heritage) — ✓ Task 2.
- Prism (gate + seat + terminal) — ✓ Task 3.
- Train number-only seat (post / glow / orient) — ✓ Task 4.
- Train number+letter seat (express) — ✓ Task 5.
- Night (car + berth, no seat) — ✓ Task 6.
- Required fields untouched — ✓ tests don't set required fields and `advance()` would refuse on `canAdvance`; behaviour preserved by leaving the existing concert / underground branches alone.
- Skip-already-filled invariant — ✓ Task 7 + per-task implementations all use `if trim(...).isEmpty`.
- `autoFilledFields` ordering & exact membership — ✓ Task 7.
- `boardingTime` not synthesized (per memory) — ✓ no generator added, no branch sets `form.boardingTime`.
- Edit-time re-population (`updateExisting` calls `applyAestheticDefaults()`) — ✓ untouched, the existing call site at line 1267 picks up the new branches automatically.
- Out-of-scope (airline / flightNumber / cabinClass / trainType) — ✓ no generator added, no branch sets those fields.
- Unit tests for each branch + cross-cutting invariants — ✓ Tasks 2–7.

**Placeholder scan:** none. Every step has full code or an exact command + expected output.

**Type consistency:**
- Generator names: `randomGate`, `randomSeatNumberLetter`, `randomSeatNumber`, `randomPlaneTerminal`, `randomCar`, `randomBerth` — same names referenced across Tasks 1–6. ✓
- Field accessors: `form.gate`, `form.seat`, `form.terminal` (FlightFormInput); `trainForm.car`, `trainForm.seat`, `trainForm.berth` (TrainFormInput) — match the actual struct fields confirmed during the brainstorming exploration. ✓
- Localization keys: `"Gate"`, `"Seat"`, `"Terminal"`, `"Car"`, `"Berth"` — used identically across implementation and test assertions. ✓
- `autoFilledFields` ordering: assertions in Tasks 3, 4, 5, 6, 7 match the in-order `if … append` pattern in their respective switch cases. ✓
