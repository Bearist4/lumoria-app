// resend-beta-code edge function.
//
// Generates a fresh 6-digit code (or first one for legacy rows without
// any code yet), updates the row's code_hash + expiry, and emails the
// plaintext to the address keyed off the calling user's auth email.
//
// Auth: required. Mirrors verify-beta-code — JWT verified via JWKS
// because the project uses ES256 asymmetric keys that the gateway-level
// verify_jwt rejects.
//
// Anti-enumeration: silent success when the auth email isn't on the
// waitlist (no membership leak). Anti-spam: per-email 1-hour cooldown
// keyed off `code_generated_at` directly on the DB row.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { createRemoteJWKSet, jwtVerify } from "https://esm.sh/jose@5.9.6";
import { Resend } from "https://esm.sh/resend@4";
import { generateCode, hashCode } from "../_shared/beta_code.ts";

const CODE_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const COOLDOWN_MS = 60 * 60 * 1000;

let _jwks: ReturnType<typeof createRemoteJWKSet> | null = null;
function getJwks(supabaseUrl: string) {
    if (!_jwks) {
        _jwks = createRemoteJWKSet(
            new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`),
        );
    }
    return _jwks;
}

function json(status: number, body: Record<string, unknown>): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" },
    });
}

export async function handler(req: Request): Promise<Response> {
    if (req.method !== "POST") {
        return json(405, { error: "method_not_allowed" });
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
    const RESEND_FROM = Deno.env.get("RESEND_FROM_ADDRESS") ?? "hello@lumoria.com";

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!/^bearer\s+/i.test(authHeader)) {
        return json(401, { error: "unauthorized", reason: "missing_bearer" });
    }
    const jwt = authHeader.replace(/^bearer\s+/i, "");

    let userEmail: string;
    try {
        const { payload } = await jwtVerify(jwt, getJwks(SUPABASE_URL), {
            issuer: `${SUPABASE_URL}/auth/v1`,
        });
        if (typeof payload.email !== "string" || payload.email.length === 0) {
            return json(401, { error: "invalid_jwt", reason: "no_email_claim" });
        }
        userEmail = payload.email.trim().toLowerCase();
    } catch (e) {
        console.log("[resend-beta-code] jwt verify failed", String(e));
        return json(401, { error: "invalid_jwt", reason: "verify_failed" });
    }

    let body: { email?: unknown } = {};
    try {
        body = await req.json();
    } catch {
        // Body is optional — silently fall through to JWT email.
    }

    let lookupEmail = userEmail;
    if (typeof body.email === "string" && body.email.trim().length > 0) {
        const trimmed = body.email.trim().toLowerCase();
        if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(trimmed)) {
            return json(400, { error: "bad_request", reason: "bad_email_format" });
        }
        lookupEmail = trimmed;
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { autoRefreshToken: false, persistSession: false },
    });

    // Look up the row. Silent OK if it doesn't exist — never confirm or
    // deny waitlist membership.
    const { data: row } = await admin
        .from("waitlist_subscribers")
        .select("id, email, code_generated_at")
        .ilike("email", lookupEmail)
        .maybeSingle();

    if (!row) return json(200, { ok: true });

    // Per-email cooldown: refuse if a code was generated less than an
    // hour ago. Silent — same response as success — so that callers
    // can't probe the cooldown window.
    if (row.code_generated_at) {
        const lastMs = new Date(row.code_generated_at as string).getTime();
        if (Date.now() - lastMs < COOLDOWN_MS) {
            return json(200, { ok: true });
        }
    }

    const plaintext = generateCode();
    const codeHash = await hashCode(plaintext);
    const generatedAt = new Date().toISOString();
    const expiresAt = new Date(Date.now() + CODE_TTL_MS).toISOString();

    const { error: updErr } = await admin
        .from("waitlist_subscribers")
        .update({
            code_hash: codeHash,
            code_expires_at: expiresAt,
            code_generated_at: generatedAt,
        })
        .eq("id", row.id);

    if (updErr) {
        console.log("[resend-beta-code] update failed", updErr);
        return json(500, { error: "update_failed" });
    }

    try {
        const resend = new Resend(RESEND_API_KEY);
        await resend.emails.send({
            from: RESEND_FROM,
            to: lookupEmail,
            subject: "Your Lumoria beta code",
            html: buildEmailHtml(plaintext),
        });
    } catch (e) {
        console.log("[resend-beta-code] resend send error", String(e));
        // Email failed but the new code is now active — return ok so the
        // user can retry; they can also tap Resend again after the
        // cooldown if needed.
    }

    return json(200, { ok: true });
}

function buildEmailHtml(code: string): string {
    return `<!DOCTYPE html>
<html lang="en"><body style="margin:0;padding:0;background:#fff;font-family:Georgia,serif;">
<table width="100%" cellpadding="0" cellspacing="0">
  <tr><td align="center" style="padding:64px 24px;">
    <table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;">
      <tr><td style="padding-bottom:32px;font-size:18px;font-weight:600;letter-spacing:0.06em;text-transform:uppercase;">Lumoria</td></tr>
      <tr><td style="padding-bottom:24px;"><h1 style="margin:0;font-size:34px;font-weight:600;line-height:1.2;letter-spacing:-0.01em;">Your beta code</h1></td></tr>
      <tr><td style="padding-bottom:32px;font-size:17px;line-height:1.65;color:#404040;">
        Enter this code in the Lumoria app to claim your beta access. It expires in 30 days.
      </td></tr>
      <tr><td align="center" style="padding-bottom:32px;">
        <div style="font-family:'SF Mono',Menlo,Consolas,monospace;font-size:42px;font-weight:600;letter-spacing:0.4em;color:#000;padding:24px 32px;background:#f5f5f5;border-radius:12px;display:inline-block;">${code}</div>
      </td></tr>
      <tr><td style="border-top:1px solid #e5e5e5;padding-top:32px;font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:13px;line-height:1.6;color:#737373;">
        Didn't request this? You can ignore this email.
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>`;
}

if (import.meta.main) {
    Deno.serve(handler);
}
