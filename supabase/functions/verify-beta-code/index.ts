// verify-beta-code edge function.
//
// Verifies a 6-digit redemption code submitted by an authenticated client
// against the SHA-256 hash stored on `waitlist_subscribers`. On success,
// links the row to the calling auth user (sets `supabase_user_id` and
// `linked_at`).
//
// JWT verification mirrors the `delete-account` function: the project
// uses ES256 asymmetric signing keys which the gateway rejects, so we
// disable gateway-level `verify_jwt` and verify with `jose` against the
// project JWKS.
//
// Rate limit: 1 attempt per 24h per auth user. Every attempt (success or
// failure) is logged to `beta_redemption_attempts` for audit.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { createRemoteJWKSet, jwtVerify } from "https://esm.sh/jose@5.9.6";
import { hashCode, isExpired, normalizeCode } from "../_shared/beta_code.ts";

const ATTEMPT_LIMIT = 1;
const WINDOW_HOURS = 24;

let _jwks: ReturnType<typeof createRemoteJWKSet> | null = null;
function getJwks(supabaseUrl: string) {
    if (!_jwks) {
        _jwks = createRemoteJWKSet(
            new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`),
        );
    }
    return _jwks;
}

export interface WaitlistRow {
    id: string;
    email: string;
    code_hash: string | null;
    code_expires_at: string | null;
    supabase_user_id: string | null;
}

export type Outcome =
    | "ok"
    | "rate_limited"
    | "not_found"
    | "expired"
    | "wrong_code"
    | "already_claimed";

export function decide(args: {
    row: WaitlistRow | null;
    submittedHash: string;
    attemptsIn24h: number;
}): { outcome: Outcome } {
    if (args.attemptsIn24h >= ATTEMPT_LIMIT) return { outcome: "rate_limited" };
    if (!args.row) return { outcome: "not_found" };
    if (args.row.supabase_user_id !== null) {
        return { outcome: "already_claimed" };
    }
    if (!args.row.code_hash || isExpired(args.row.code_expires_at)) {
        return { outcome: "expired" };
    }
    if (args.row.code_hash !== args.submittedHash) {
        return { outcome: "wrong_code" };
    }
    return { outcome: "ok" };
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

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!/^bearer\s+/i.test(authHeader)) {
        return json(401, { error: "unauthorized", reason: "missing_bearer" });
    }
    const jwt = authHeader.replace(/^bearer\s+/i, "");

    let userId: string;
    try {
        const { payload } = await jwtVerify(jwt, getJwks(SUPABASE_URL), {
            issuer: `${SUPABASE_URL}/auth/v1`,
        });
        if (typeof payload.sub !== "string") {
            return json(401, { error: "invalid_jwt", reason: "no_sub_claim" });
        }
        userId = payload.sub;
    } catch (e) {
        console.log("[verify-beta-code] jwt verify failed", String(e));
        return json(401, { error: "invalid_jwt", reason: "verify_failed" });
    }

    let body: { email?: unknown; code?: unknown } = {};
    try {
        body = await req.json();
    } catch {
        return json(400, { error: "bad_request", reason: "invalid_json" });
    }
    if (typeof body.email !== "string" || typeof body.code !== "string") {
        return json(400, { error: "bad_request", reason: "missing_fields" });
    }
    const email = body.email.trim().toLowerCase();
    const normalized = normalizeCode(body.code);
    if (!/^[0-9]{6}$/.test(normalized)) {
        return json(400, { error: "bad_request", reason: "bad_code_format" });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { autoRefreshToken: false, persistSession: false },
    });

    // Count attempts in the trailing 24h window.
    const since = new Date(Date.now() - WINDOW_HOURS * 60 * 60 * 1000).toISOString();
    const { count: attemptsIn24h } = await admin
        .from("beta_redemption_attempts")
        .select("id", { count: "exact", head: true })
        .eq("auth_user_id", userId)
        .gt("attempted_at", since);

    // Look up the waitlist row.
    const { data: row } = await admin
        .from("waitlist_subscribers")
        .select("id, email, code_hash, code_expires_at, supabase_user_id")
        .ilike("email", email)
        .maybeSingle();

    const submittedHash = await hashCode(normalized);
    const { outcome } = decide({
        row: row as WaitlistRow | null,
        submittedHash,
        attemptsIn24h: attemptsIn24h ?? 0,
    });

    // Always log the attempt.
    const { error: logErr } = await admin.from("beta_redemption_attempts").insert({
        auth_user_id: userId,
        email_attempted: email,
        success: outcome === "ok",
    });
    if (logErr) {
        console.log("[verify-beta-code] attempt log insert failed", logErr);
    }

    if (outcome === "ok" && row) {
        const { error: updErr } = await admin
            .from("waitlist_subscribers")
            .update({
                supabase_user_id: userId,
                linked_at: new Date().toISOString(),
            })
            .eq("id", row.id);
        if (updErr) {
            console.log("[verify-beta-code] link update failed", updErr);
            return json(500, { error: "link_failed" });
        }
    }

    return json(200, { outcome });
}

if (import.meta.main) {
    Deno.serve(handler);
}
