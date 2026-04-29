# Ticket Autofill — Extend To Plane + Train Templates

**Date:** 2026-04-29
**Status:** Design — pending implementation

## Problem

`NewTicketFunnel.applyAestheticDefaults()` already fills blank optional
fields with template-appropriate placeholder copy on form submit, then
surfaces the list of touched fields via `autoFilledFields[]` so
`SuccessStep` can show a "✨ We filled in X, Y for you" notice. Today
the function only handles the concert template and the public-transport
templates (underground / sign / infoscreen / grid). Plane and train
templates fall through a `break` stub, so a user who skips slot-style
fields like gate, seat, car, berth, or terminal ends up with empty
labels on an otherwise polished ticket.

The goal is to extend the existing pattern to plane and train templates
so a casual user — who often doesn't remember their gate or seat — still
gets a finished-looking ticket. Required fields are gated by
`canAdvance` upstream and are never touched here.

## Approach

Extend `applyAestheticDefaults()` in place. Reuse the established
surface (`autoFilledFields[]`, success-step notice, edit-time
re-population). Add a small set of private static random generators
next to the existing `randomRef` / `randomTransitTicketNumber` helpers.

We considered pulling generators into a separate service or building a
declarative per-template config table, but neither buys enough today —
the existing pattern is already template-keyed, generators are tiny,
and the edge cases per template are low enough that an inline switch
remains the cheapest thing to read.

## Scope

**Templates and fields filled when blank:**

| Template group | Templates | Fields | Format |
|---|---|---|---|
| Plane (basic) | afterglow, studio, terminal, heritage | `gate`, `seat` | gate `A12` / seat `14A` |
| Plane (extended) | prism | `gate`, `seat`, `terminal` | + terminal `T3` |
| Train (number-only seat) | post, glow, orient | `car`, `seat` | car `7` / seat `47` |
| Train (number+letter seat) | express | `car`, `seat` | car `7` / seat `14A` |
| Train (sleeper) | night | `car`, `berth` | car `7` / berth `Lower` |
| Concert | concert | (existing) | unchanged |
| Public transport | underground, sign, infoscreen, grid | (existing) | unchanged |

**Out of scope:**

- Filling required fields. `canAdvance` already gates those upstream.
- Filling `airline`, `flightNumber`, `cabinClass`, `trainType`,
  `trainNumber`, `company`. These are either required or large
  identifying fields where a synthesized value reads as fake.
- `boardingTime`. Per existing project memory, plane boarding time is
  auto-derived as `departs − 30 min` and is not a manual field.
- Adding new fields to template models. We only fill what the model
  already has.
- New autofill UX. The existing success-step notice is reused verbatim.

## Architecture

### Generators

Added as private static methods on `NewTicketFunnel`, alongside the
existing `randomRef` / `randomTransitTicketNumber`:

```swift
private static func randomGate() -> String {
    let letter = "ABCDEFGH".randomElement()!
    return "\(letter)\(Int.random(in: 1...60))"
}

private static func randomSeatNumberLetter() -> String {
    let row = Int.random(in: 1...40)
    let letter = "ABCDEFGHJK".randomElement()!  // skips I, airline convention
    return "\(row)\(letter)"
}

private static func randomSeatNumber() -> String {
    "\(Int.random(in: 1...80))"
}

private static func randomPlaneTerminal() -> String {
    "T\(Int.random(in: 1...5))"
}

private static func randomCar() -> String {
    "\(Int.random(in: 1...18))"
}

private static func randomBerth() -> String {
    ["Lower", "Upper", "Single", "Cabin"].randomElement()!
}
```

### Switch additions to `applyAestheticDefaults()`

Replaces the existing
`case .afterglow, .studio, .heritage, .terminal, .prism, .express, .orient, .night, .post, .glow: break`
stub with explicit per-group cases. The concert and public-transport
branches stay as they are.

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

case .post, .glow, .orient:
    if trim(trainForm.car).isEmpty {
        trainForm.car = Self.randomCar()
        autoFilledFields.append(String(localized: "Car"))
    }
    if trim(trainForm.seat).isEmpty {
        trainForm.seat = Self.randomSeatNumber()
        autoFilledFields.append(String(localized: "Seat"))
    }

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
    if trim(trainForm.car).isEmpty {
        trainForm.car = Self.randomCar()
        autoFilledFields.append(String(localized: "Car"))
    }
    if trim(trainForm.berth).isEmpty {
        trainForm.berth = Self.randomBerth()
        autoFilledFields.append(String(localized: "Berth"))
    }
```

### Behaviour

- Trigger and surface are unchanged: same call site in `advance()`,
  same `autoFilledFields[]` array, same `SuccessStep` notice.
- Edit time: when an existing ticket is being edited and the user
  clears one of these fields, `updateExisting` re-runs
  `applyAestheticDefaults()` and a fresh value is generated. This
  matches the current concert + transit behaviour.
- Required fields remain untouched — gated by `canAdvance`.
- Generators are template-pure (no I/O, no UserDefaults), so multiple
  calls in the same advance produce independent values.

## Files touched

| File | Change |
|---|---|
| `Lumoria App/views/tickets/new/NewTicketFunnel.swift` | Replace plane/train stub in `applyAestheticDefaults()`. Add 6 private static generators. |
| `Lumoria AppTests/NewTicketFunnelAutofillTests.swift` | NEW — coverage for the new branches. |
| `Lumoria App/Localizable.xcstrings` | Auto-extracted on next Xcode build for the new field labels (Gate, Seat, Terminal, Car, Berth). |

## Tests

In a new `NewTicketFunnelAutofillTests.swift` file using Swift Testing:

- `applyAestheticDefaults_planeFillsGateAndSeat_whenBlank`
  Set template to `.afterglow`, leave `form.gate` and `form.seat` blank,
  call advance from form. Expect both populated, `autoFilledFields ==
  ["Gate", "Seat"]`.
- `applyAestheticDefaults_prismAlsoFillsTerminal`
  Same as above with `.prism`, expect terminal also filled.
- `applyAestheticDefaults_skipsAlreadyFilledFields`
  Pre-fill `form.seat = "11A"`. Advance. Expect `form.seat == "11A"`
  unchanged and `autoFilledFields` does not contain `"Seat"`.
- `applyAestheticDefaults_trainNumberOnlySeat_forPost`
  Set `.post`, blank seat. Assert resulting seat matches `^\d+$`.
- `applyAestheticDefaults_trainNumberLetterSeat_forExpress`
  Set `.express`, blank seat. Assert resulting seat matches
  `^\d+[A-HJK]$` — same alphabet `randomSeatNumberLetter` uses (ABCDEFGHJK, skips I per airline convention).
- `applyAestheticDefaults_nightFillsBerth_notSeat`
  Set `.night`, blank everything. Expect `trainForm.berth` populated
  from the four-value set, `trainForm.seat` left blank,
  `autoFilledFields` does not contain `"Seat"`.
- `autoFilledFields_listsExactlyTheNewlyFilledLabels`
  Pre-fill some fields and leave others blank, verify the array
  matches exactly the blank-then-filled subset (no duplicates, correct
  order: Gate before Seat before Terminal etc).

Generator-format invariants double as regression tests against accidental
format drift later.

## Rollout

Single PR, behind no flag. Risk surface is contained to ticket
creation; existing tickets are unaffected (autofill only runs on
form-step advance and on explicit edit, never on read). Concert and
public-transport flows are not touched.
