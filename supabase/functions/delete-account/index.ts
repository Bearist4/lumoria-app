// delete-account edge function.
//
// Satisfies App Store Guideline 5.1.1(v) by giving signed-in users a
// server-side path that permanently removes their user row and all
// user-scoped data. Client wires this up from Settings → "Delete my
// account".
//
// Flow:
//   1. Verify the caller's JWT with the anon client and extract user_id.
//   2. Require an explicit `{ "confirmation": "DELETE" }` body so a
//      replayed or accidentally-fired invocation cannot wipe an account.
//   3. Delete user-scoped rows in dependency order using a service-role
//      client, then call auth.admin.deleteUser.
//
// On failure the function short-circuits — the auth row is only removed
// after every table delete succeeded, so a partial failure never leaves
// an auth user orphaned from their data.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(status: number, body: Record<string, unknown>): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" },
    });
}

Deno.serve(async (req: Request) => {
    if (req.method !== "POST") {
        return json(405, { error: "method_not_allowed" });
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
        return json(401, { error: "unauthorized" });
    }
    const jwt = authHeader.slice("Bearer ".length);

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: `Bearer ${jwt}` } },
        auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
        return json(401, { error: "invalid_jwt" });
    }
    const userId = userData.user.id;
    const avatarPath = (userData.user.user_metadata as Record<string, unknown> | null)
        ?.["avatar_path"] as string | undefined;

    let body: { confirmation?: string } = {};
    try {
        body = await req.json();
    } catch {
        // empty / malformed body falls through to the confirmation check
    }
    if (body.confirmation !== "DELETE") {
        return json(400, { error: "confirmation_required" });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { autoRefreshToken: false, persistSession: false },
    });

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

        return json(200, { ok: true });
    } catch (e) {
        return json(500, { error: "delete_failed", detail: String(e) });
    }
});
