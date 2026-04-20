// delete-account edge function.
//
// Satisfies App Store Guideline 5.1.1(v) by giving signed-in users a
// server-side path that permanently removes their user row and all
// user-scoped data. Client wires this up from Settings → "Delete my
// account".
//
// Flow:
//   1. Verify the caller's JWT ourselves against the project JWKS. We
//      cannot use the gateway's built-in `verify_jwt` because this
//      project uses ES256 asymmetric signing keys, which the gateway
//      rejects as UNAUTHORIZED_UNSUPPORTED_TOKEN_ALGORITHM. The deploy
//      therefore sets `verify_jwt: false` and does the signature check
//      here with `jose.jwtVerify` + `createRemoteJWKSet`.
//   2. Require an explicit `{ "confirmation": "DELETE" }` body so a
//      replayed or accidentally-fired invocation cannot wipe an account.
//   3. Delete user-scoped rows in dependency order using a service-role
//      client, then call auth.admin.deleteUser.
//
// On failure the function short-circuits — the auth row is only removed
// after every table delete succeeded, so a partial failure never leaves
// an auth user orphaned from their data.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { jwtVerify, createRemoteJWKSet } from "https://esm.sh/jose@5.9.6";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Supabase's asymmetric JWT public keys. Cached by `jose` inside the
// isolate so repeated invocations don't re-fetch on every request.
const JWKS = createRemoteJWKSet(
    new URL(`${SUPABASE_URL}/auth/v1/.well-known/jwks.json`),
);

function json(status: number, body: Record<string, unknown>): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" },
    });
}

Deno.serve(async (req: Request) => {
    console.log("[delete-account] hit", {
        method: req.method,
        hasAuth: req.headers.has("Authorization"),
    });

    if (req.method !== "POST") {
        return json(405, { error: "method_not_allowed" });
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!/^bearer\s+/i.test(authHeader)) {
        return json(401, {
            error: "unauthorized",
            reason: "missing_bearer",
        });
    }
    const jwt = authHeader.replace(/^bearer\s+/i, "");

    let userId: string;
    try {
        const { payload } = await jwtVerify(jwt, JWKS, {
            issuer: `${SUPABASE_URL}/auth/v1`,
        });
        if (typeof payload.sub !== "string") {
            return json(401, { error: "invalid_jwt", reason: "no_sub_claim" });
        }
        userId = payload.sub;
    } catch (e) {
        console.log("[delete-account] jwt verify failed", String(e));
        return json(401, {
            error: "invalid_jwt",
            reason: "verify_failed",
            detail: String(e),
        });
    }

    let body: { confirmation?: string } = {};
    try {
        body = await req.json();
    } catch {
        // fall through to the confirmation check
    }
    if (body.confirmation !== "DELETE") {
        return json(400, { error: "confirmation_required" });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { autoRefreshToken: false, persistSession: false },
    });

    // Grab user metadata so we can remove the avatar ciphertext from
    // storage. If the lookup fails we still proceed with the delete —
    // a stale avatar file is preferable to a half-deleted account.
    let avatarPath: string | undefined;
    try {
        const { data } = await admin.auth.admin.getUserById(userId);
        const meta = data?.user?.user_metadata as Record<string, unknown> | undefined;
        const maybePath = meta?.["avatar_path"];
        if (typeof maybePath === "string" && maybePath.length > 0) {
            avatarPath = maybePath;
        }
    } catch {
        avatarPath = undefined;
    }

    try {
        const { data: userMemories } = await admin
            .from("memories")
            .select("id")
            .eq("user_id", userId);
        const { data: userTickets } = await admin
            .from("tickets")
            .select("id")
            .eq("user_id", userId);

        const memoryIds = (userMemories ?? []).map((m: { id: string }) => m.id);
        const ticketIds = (userTickets ?? []).map((t: { id: string }) => t.id);

        if (memoryIds.length > 0) {
            const { error } = await admin
                .from("memory_tickets")
                .delete()
                .in("memory_id", memoryIds);
            if (error) throw error;
        }
        if (ticketIds.length > 0) {
            const { error } = await admin
                .from("memory_tickets")
                .delete()
                .in("ticket_id", ticketIds);
            if (error) throw error;
        }

        for (const step of [
            () => admin.from("notifications").delete().eq("user_id", userId),
            () => admin.from("tickets").delete().eq("user_id", userId),
            () => admin.from("memories").delete().eq("user_id", userId),
            () => admin.from("device_tokens").delete().eq("user_id", userId),
            () => admin.from("notification_prefs").delete().eq("user_id", userId),
            () => admin.from("announcement_reads").delete().eq("user_id", userId),
            () => admin.from("invites").delete().eq("inviter_id", userId),
        ] as const) {
            const { error } = await step();
            if (error) throw error;
        }

        // Invites this user *claimed* belong to the inviter; just unlink the
        // claim so the inviter's row is preserved.
        {
            const { error } = await admin
                .from("invites")
                .update({ claimed_by: null, claimed_at: null })
                .eq("claimed_by", userId);
            if (error) throw error;
        }

        // Waitlist row is keyed by email — unlink the supabase user pointer
        // rather than deleting the waitlist signup itself.
        {
            const { error } = await admin
                .from("waitlist_subscribers")
                .update({ supabase_user_id: null, linked_at: null })
                .eq("supabase_user_id", userId);
            if (error) throw error;
        }

        if (avatarPath) {
            await admin.storage.from("avatars").remove([avatarPath]);
        }

        const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
        if (deleteError) {
            return json(500, {
                error: "auth_delete_failed",
                detail: deleteError.message,
            });
        }

        console.log("[delete-account] ok", { userId });
        return json(200, { ok: true });
    } catch (e) {
        console.error("[delete-account] delete_failed", String(e));
        return json(500, { error: "delete_failed", detail: String(e) });
    }
});
