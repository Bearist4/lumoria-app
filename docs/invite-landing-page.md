# Invite landing page — `getlumoria.app/invite/{token}`

Build a public page that handles inbound invite links from the Lumoria iOS app.
The token in the URL is an opaque lookup key — never show it, never decode it,
never hit Supabase from this page. Its only jobs: open the app if installed,
send the visitor to the App Store if not, and preserve the token through the
round-trip.

## Route

- Path: `/invite/:token`
- Token format: 10 chars, Crockford base32 (`23456789ABCDEFGHJKMNPQRSTVWXYZ`)
- If the path doesn't match, 404 or redirect to `/`.

## Behavior by platform

### iOS (Safari / in-app browser)

1. If the app is installed, iOS will hand the URL directly to Lumoria **before**
   this page loads (because of the Associated Domains + AASA). No web work
   needed for that case.
2. If the app is **not** installed, this page loads. Show:
   - The "You're invited" hero (see Content).
   - Primary CTA → App Store link
     (`https://apps.apple.com/app/id{APP_STORE_ID}`).
   - A secondary "Already have Lumoria?" link that opens
     `lumoria://invite/{token}` (custom-scheme fallback).
   - Use Apple Smart App Banner too:
     ```html
     <meta name="apple-itunes-app"
           content="app-id={APP_STORE_ID}, app-argument=lumoria://invite/{token}">
     ```

### Android / desktop / other

Show the same hero with:
- A note that Lumoria is iOS-only today.
- A waitlist CTA (link to the marketing page).

## Token handoff (critical)

The invitee may install the app, open it, and **then** need to claim the
token. To cover that:

- The iOS app re-reads the token from the URL on `onOpenURL`. So a visitor
  who installs, then taps the original link again, is covered.
- Belt-and-braces: if the visitor lands on this page from mobile Safari, set
  a cookie or localStorage key `pending_invite_token = {token}` (30-day TTL).
  It's harmless if unused — but lets a future "paste your invite token" flow
  in the app read it if we ever add one.

No server-side storage, no Supabase call, no account lookup. The token is
validated inside the app against the `invites` table via the `claim_invite`
RPC.

## AASA — Apple App Site Association

Host at **`https://getlumoria.app/.well-known/apple-app-site-association`**.
Must be served:
- Over HTTPS, at the exact path above.
- With `Content-Type: application/json` (no `.json` extension in the URL).
- Without redirects.

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["{TEAM_ID}.com.lumoria.app"],
        "components": [
          { "/": "/invite/*", "comment": "Invite links" }
        ]
      }
    ]
  }
}
```

Replace `{TEAM_ID}` with the Apple Developer Team ID and
`com.lumoria.app` with the actual bundle identifier.

Verify with:
```
curl -I https://getlumoria.app/.well-known/apple-app-site-association
```

Apple caches AASA aggressively — changes can take hours to propagate.

## Content

**Hero**
- Headline: *You're invited.*
- Subhead: *Someone thinks you'd love collecting your travels here.*
- Brand: Lumoria wordmark (EB Garamond Semibold, i-dot replaced by 7-point
  star — use the logotype SVG from the brand kit).

**Primary CTA**
- iOS visitors: *Get Lumoria* → App Store.
- Other platforms: *Join the waitlist* → `/waitlist` or marketing site.

**Secondary link**
- iOS visitors only, below the CTA: *Already installed? Open Lumoria* →
  `lumoria://invite/{token}`.

**Footer**
- Small print: *Your invite link expires once redeemed.*
- Privacy + Terms links.

Keep the page single-screen on mobile. No forms, no feature lists, no
navigation chrome beyond the CTA. Voice follows `lumoria` brand guidelines —
warm, concise, visual, no logistics language.

## Tech notes

- Static page is fine. No server logic required — the token is a pass-through.
- Cache: `Cache-Control: public, max-age=300`. Per-token caching is safe
  because the page is identical across tokens except for the `app-argument`
  meta and the `lumoria://` link.
- Do **not** embed the token in any analytics event — treat it as a
  one-shot secret even though the table is RLS-protected.

## Related code in the iOS app

- `InviteLink` (host, scheme, token parser)
- `PendingInviteTokenStore` (UserDefaults key: `pending_invite_token`)
- `InvitesStore.claim(token:)` (RPC call, invitee side)
- `claim_invite(p_token text)` Postgres RPC

When the web page is live and AASA is verified, no app-side change is needed.
