// check-email-exists edge function.
//
// Tells the app whether an email address already has an account so the
// landing flow can morph into the login or signup form. Service-role
// lookup against auth.users by lower(email). IP-rate-limited (10/min
// sliding window) backed by an in-memory map; the function instance
// stays warm long enough that this is sufficient for V1 — swap to
// Deno.kv if we see horizontal scaling.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const RATE_LIMIT = 10;
const WINDOW_MS = 60_000;

// IP -> [timestamps]. Trimmed on each request.
const HITS = new Map<string, number[]>();

export function normalizeEmail(input: string): string {
  return input.trim().toLowerCase();
}

export type Outcome = "ok" | "rate_limited";

export function decide(args: {
  existsInDb: boolean;
  hitsInWindow: number;
}): { outcome: Outcome; exists?: boolean } {
  if (args.hitsInWindow >= RATE_LIMIT) return { outcome: "rate_limited" };
  return { outcome: "ok", exists: args.existsInDb };
}

function recordHit(ip: string): number {
  const now = Date.now();
  const cutoff = now - WINDOW_MS;
  const arr = (HITS.get(ip) ?? []).filter((t) => t > cutoff);
  arr.push(now);
  HITS.set(ip, arr);
  return arr.length;
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

  const ip =
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    req.headers.get("x-real-ip") ??
    "unknown";

  const hits = recordHit(ip);

  let body: { email?: unknown } = {};
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad_request", reason: "invalid_json" });
  }
  if (typeof body.email !== "string") {
    return json(400, { error: "bad_request", reason: "missing_email" });
  }

  const email = normalizeEmail(body.email);
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return json(400, { error: "bad_request", reason: "bad_email_format" });
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Defer to the email_exists() SQL helper (security definer) — same
  // pattern as link_beta_by_email. supabase-js v2 has no public way to
  // filter auth.users from Edge.
  let existsInDb = false;
  try {
    const { data, error } = await admin.rpc("email_exists", { _email: email });
    if (error) {
      console.log("[check-email-exists] rpc failed", error);
      return json(500, { error: "lookup_failed" });
    }
    existsInDb = data === true;
  } catch (e) {
    console.log("[check-email-exists] rpc threw", String(e));
    return json(500, { error: "lookup_failed" });
  }

  const result = decide({ existsInDb, hitsInWindow: hits });
  if (result.outcome === "rate_limited") {
    return json(429, { error: "rate_limited" });
  }
  return json(200, { exists: result.exists ?? false });
}

if (import.meta.main) {
  Deno.serve(handler);
}
