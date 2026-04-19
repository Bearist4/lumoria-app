# Lumoria Microinteractions — Design Spec

**Date:** 2026-04-19
**Status:** Approved for implementation plan
**Owner:** Ben

---

## 1. Intent

Give Lumoria a system of microinteractions that makes the app feel premium end-to-end. Three constraints:

1. **Editorial + Luminous.** Every interaction reinforces the brand tension between EB Garamond gravity and luminous lightness.
2. **Unified metaphor.** *Light as Material* — every microinteraction expresses light behaviour (reflection, bloom, exposure, flash). Backed by *physical object* structure for tickets (weight, tear, print) and *editorial motion* restraint in timing.
3. **Scope is app-wide.** Tickets, creation flow, auth, settings, empty states, navigation, share, delete — all get treatment from a single shared system.

## 2. Approach Summary

- **Primary metaphor:** Light as Material.
- **Structural backbone:** Physical object (tickets have weight; tear on delete; print on save).
- **Tone layer:** Editorial motion (timing curves lean restrained — no rushed iOS defaults).

## 3. System Architecture

Three layers of primitives:

### 3.1 Motion tokens — `MotionTokens.swift`

| Token | Curve | Duration | Use |
|-------|-------|----------|-----|
| `.editorial` | ease-out | 320ms | Default transitions, title lifts, nav push/pop |
| `.settle` | spring, response 0.45, damping 0.82 | — | Tickets landing, sheets presenting |
| `.impulse` | spring, response 0.22, damping 0.65 | — | Taps, selection, toggles, small state changes |
| `.expose` | ease-in-out | 620ms | Photographic reveals (save moment) |

### 3.2 Haptic palette — `HapticPalette.swift`

Thin wrapper over SwiftUI `.sensoryFeedback` (iOS 17+). Seven tokens:

| Token | Underlying feedback | Meaning |
|-------|--------------------|---------|
| `.select` | `.selection` | Tap, row highlight, field focus |
| `.confirm` | `.success` | CTA press, share success, refresh crossing threshold |
| `.toggle` | `.impact(.light)` | Switch changes, segmented-control changes |
| `.warn` | `.warning` | Destructive confirmation tap, tear start |
| `.save` | custom pattern — 4 light `.impact(.soft)` ticks at 140ms cadence | Paper-feed print stutter during save |
| `.stamp` | `.impact(.medium)` | Single thud — inspect lift, duplicate split |
| `.shimmer` | `.impact(.rigid)` at very low intensity | Tilt crossing highlight peak |

Debounced at 50ms minimum to avoid chaining.

### 3.3 Template shimmer attribute

New enum added to each ticket template definition:

```swift
enum TicketShimmer {
    case holographic
    case paperGloss
    case softGlow
    case none
}
```

Template assignment:

| Template | Shimmer |
|----------|---------|
| Prism | holographic |
| Studio | holographic |
| Heritage | paperGloss |
| Terminal | paperGloss |
| Orient | paperGloss |
| Express | paperGloss |
| Afterglow | softGlow |
| Night | softGlow |

Rendered by a single shared `TicketShimmerView` driven by CoreMotion — one implementation, four visual modes. Template files stay declarative; no per-template animation code.

## 4. The Ticket Object

### 4.1 Tilt shimmer (CoreMotion-driven)

- Single `CMMotionManager` instance app-wide, updates at 60Hz, reads `deviceMotion.attitude` (roll + pitch).
- Started on foreground, stopped on background.
- `TicketShimmerView` overlays ticket canvas, masked to template shape, blends by `TicketShimmer` mode:
  - **holographic** — angular conic gradient (cyan → magenta → yellow → cyan), opacity 0.35, rotates with roll, hue-shifts with pitch.
  - **paperGloss** — single soft white linear sheen, 30% width, sweeps diagonally with tilt, opacity 0.18.
  - **softGlow** — radial bloom at ticket center, 40pt radius; intensity follows pitch (flat = dim, tilted = brighter).
  - **none** — no overlay rendered.
- Subtle parallax on ticket content: title/subtitle shifts ±3pt against background based on tilt axis.
- Respects `UIAccessibility.isReduceMotionEnabled` — freezes to neutral angle.
- Pauses when ticket off-screen via visibility observer.

### 4.2 Inspect mode

- Long-press (0.3s) on any ticket card → ticket lifts (scale 1.06, shadow deepens), surrounding UI blurs, `.stamp` haptic.
- While held, roll phone → shimmer amplifies 2x.
- Release → ticket settles back with `.settle` spring.
- VoiceOver: exposed as a separate accessibility action `"Inspect ticket"` on each card.

### 4.3 Edge catch

- When tilt angle crosses the steepest highlight point on the shimmer, fire `.shimmer` haptic once.

### 4.4 Tap on ticket card

- `.select` haptic + 12ms depression (scale 0.98) + `.impulse` spring release → route to detail view.

## 5. Signature Moments

### 5.1 Save (print / emboss) — the hero moment

- Canvas enters blank: ticket shape outline only, 1px border in category color.
- Content prints top-down in 4 horizontal bands, 140ms each (total ~560ms):
  1. Header (route/date)
  2. Primary content (title, names)
  3. Stats/details
  4. Footer + perforation
- Each band landing fires one `.save` haptic tick (4 ticks total = paper-feed stutter).
- On final band: ticket does a 2° z-axis settle (spring), shimmer initialises with a single full surface sweep to "bless" the ticket, then goes dormant.
- Copy: "Saved." Nothing else.
- Reduce-motion fallback: crossfade 300ms + single `.confirm` haptic.

### 5.2 Share

- Tap share → ticket scales to 0.94, shimmer freezes.
- 7-point star ghosts out from ticket toward share sheet handle (200ms, `.editorial`).
- Share sheet slides up with `.settle` spring; `.confirm` haptic on present.

### 5.3 Delete

- Destructive confirmation dialog first (clarity over motion).
- On confirm: ticket tears along its perforation line (shape-specific — top edge for plane, side for train), two halves fall and fade over 450ms (ease-in).
- `.warn` haptic at tear start, silence after.
- Surrounding cards in list settle up with `.settle` spring.

### 5.4 Duplicate

- A second ticket slides out from underneath the original, offset 16pt.
- `.stamp` haptic on emergence.
- Original stays in place; duplicate becomes selected and routes to edit.

### 5.5 Export / download

- Single full-surface shimmer sweep left→right (420ms) while file writes.
- `.confirm` haptic on completion.
- 7-point star badge briefly appears at ticket corner — fades after 800ms.

## 6. Navigation + Transitions

### 6.1 NavigationStack

- Push: destination slides from right with `.editorial` curve, source shifts −30pt and fades to 0.88 opacity (parallax depth). 320ms.
- Pop: reverse, same curve.

### 6.2 Tabs

- Crossfade 180ms + `.impulse` haptic. No slide.

### 6.3 Sheets

- Present: `.settle` spring. Handle appears 60ms after sheet body. `.impulse` haptic on present.
- Drag dismiss: sheet follows finger 1:1 below threshold, snaps past. Background blur eases back progressively from ~40% drag.
- Detent changes (medium ↔ large): `.impulse` haptic on snap.

### 6.4 Full-screen cover (auth, onboarding)

- Open: content fades up from 8pt below with `.editorial`, background orbs/image scale 1.04 → 1.0.
- Close: reverse. Never default iOS full-screen-cover slide.

### 6.5 In-screen transitions

- Category selection → template grid: selected tile's color washes as soft background, other tiles crossfade out, template grid fades in from below. `.select` haptic on tap.
- Template grid → details form: selected template lifts (scale 1.02) and travels to top-of-screen preview slot; form fields stagger-fade in top-down (40ms between each).
- Form field focus: 4pt border scales in around field, label shifts up 2pt. `.select` haptic.

### 6.6 Pull-to-refresh

- Custom control. 7-point star appears at center of pull distance.
- Rotates 1 full turn per 60pt pulled; glows brighter as threshold approaches.
- Crossing threshold → `.confirm` haptic + single pulse.
- On release: list refreshes, star fades.

### 6.7 Scroll behavior

- Default iOS physics preserved.
- Shimmer pause/resume gated on viewport: ticket unpauses only when its card reaches vertical center of viewport. All other cards are shimmer-dormant.

## 7. Creation Flow

### 7.1 Category picker

- Tile tap: scale to 1.04, saturate to 100%. Other tiles desaturate to 40% for 200ms before transitioning.

### 7.2 Template picker

- Selected tile's ticket preview tilts 8° toward viewer for 260ms (shimmer catches the motion), settles flat, then screen advances.

### 7.3 Details form

- Autocomplete chips (airline/airport/station) slide in from right with 30ms stagger.
- Color wells pulse once when opened.
- Date picker confirm → `.impulse` haptic.
- Live preview card at top: every field edit crossfades that zone only (180ms), not the whole ticket. Text inputs debounced 200ms.
- While editing, ticket "breathes" (scale 0.998 ↔ 1.002 over 4s) — draft indicator.

## 8. Auth

### 8.1 AuthView entrance

- Logogram drops in from 12pt above with `.settle`.
- Star in logogram pulses once (scale 1 → 1.15 → 1) at landing.
- Tagline fades in 180ms after. Total entrance ~700ms.

### 8.2 Field focus

- Same pattern as creation form.

### 8.3 Primary CTA

- Press: button depresses (scale 0.97), releases with `.confirm` haptic.
- On success: label crossfades to a 7-point star that pulses once before route advances.

### 8.4 Log out confirm

- Destructive dialog. `.warn` haptic on destructive tap. No additional motion.

## 9. Settings

- Row tap: `.select` haptic + 60ms highlight wash in neutral gray.
- Toggles: `.toggle` haptic on change, 160ms spring on thumb.
- "Made with Lumoria" footer: logogram star rotates 360° over 8s, once on view appear, then idles.

## 10. Empty States

- Single centered 7-point star with permanent `softGlow` shimmer (the only always-on shimmer surface).
- Copy below: "Your memories start here."
- Tap anywhere on empty state → star scale-pulses once, then routes to creation flow.

## 11. Marketing / Landing Surfaces

- Aurora orbs drift continuously (existing behavior).
- When a ticket is hero-on-screen, orbs slow to 40% speed; resume on ticket scroll-away.

## 12. Accessibility + Performance Guardrails

### 12.1 Reduce Motion

- Tilt shimmer → frozen at neutral angle, parallax disabled.
- Inspect-mode lift → opacity flash only (no scale).
- Save "print" sequence → crossfade 300ms + single `.confirm` haptic.
- Share star-ghost → sheet appears directly.
- Delete tear → straight fade-out.
- Pull-refresh star rotation → static star with opacity pulse.
- Sheet/modal springs → linear 200ms ease.
- Template "hello" tilt on selection → skipped.
- Empty-state `softGlow` → static.

### 12.2 Reduce Transparency / Increase Contrast (HC Light / HC Dark)

- Shimmer overlays disabled entirely (matches existing aurora-orbs-disabled brand rule).
- Parallax disabled — content flat.

### 12.3 VoiceOver

- Shimmer and haptics are decorative — no accessibility announcements.
- Inspect mode exposed as separate accessibility action `"Inspect ticket"` per card (not gated on long-press).
- Save / share / delete announce state transitions: "Saved." / "Shared." / "Deleted."
- Empty-state star rotation hidden from accessibility tree.

### 12.4 Low Power Mode (`ProcessInfo.isLowPowerModeEnabled`)

- CoreMotion updates throttle 60Hz → 20Hz.
- Tilt shimmer disabled (static highlight only).
- Aurora orbs freeze.
- Haptics and transitions stay (cheap).

### 12.5 Device tier

- A12 and below: holographic shimmer downgrades to paperGloss regardless of template attribute.
- Metal-based shimmer (if adopted) must fall back to gradient-layer rendering on GPU pressure.

### 12.6 Performance rules

- Single `CMMotionManager` instance app-wide, started on foreground, stopped on background.
- Shimmer layer uses `.drawingGroup()` (Metal rasterization) with `.allowsHitTesting(false)`.
- No shimmer on cards outside viewport (visibility gate).
- Haptic calls debounced at 50ms minimum.
- Target: 60fps minimum on iPhone 12, 120fps on ProMotion devices.

## 13. Copy / Voice

- All new UI strings added to `Localizable.xcstrings`.
- Signature moments reuse existing brand voice ("Saved.", "It's yours now.", etc.) — no new copy invented for microinteractions.
- No sound effects anywhere in the app (explicit decision).

## 14. Out of Scope

- Custom sound palette (confirmed: silent app).
- Haptic choreography beyond the seven defined tokens.
- Marketing-specific motion (aurora orbs beyond the existing drift + ticket-aware slowdown).
- Widget / Live Activity motion (will need its own spec when those ship).
- Custom export video motion (separate feature).

## 15. Open Questions for Implementation

- Whether shimmer renders via SwiftUI `Canvas` + `drawingGroup()` or a dedicated Metal shader. Decision deferred to implementation plan based on perf profiling on iPhone 12 baseline.
- Exact stagger curve + delay tuning for save print sequence — prototype and tune.
- Whether tear animation on delete uses particle-free shape splitting (preferred) or a simple two-half fall.

---

*Next step: writing-plans skill to produce implementation plan.*
