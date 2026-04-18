// send-push edge function.
//
// Triggered by an AFTER INSERT trigger on public.notifications. Given a
// notification id, looks up the target user's device tokens, signs an
// APNs JWT with the ES256 key configured via project secrets, and POSTs
// one request per token to api.push.apple.com (or sandbox, depending on
// APNS_ENV).
//
// Secrets required (set via `supabase secrets set`):
//   APNS_TEAM_ID     — 10-char Apple Team ID
//   APNS_KEY_ID      — 10-char APNs key id
//   APNS_BUNDLE_ID   — bundle id used as the `apns-topic` header
//   APNS_AUTH_KEY    — full PEM body of the .p8 file (including BEGIN/END lines)
//   APNS_ENV         — "production" | "sandbox"   (default: production)
//
// On 410 Unregistered from APNs the row in device_tokens is deleted.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

interface NotificationRow {
    id: string;
    user_id: string;
    kind: "throwback" | "onboarding" | "news" | "link";
    title: string;
    message: string;
    memory_id: string | null;
    template_kind: string | null;
}

interface DeviceTokenRow {
    token: string;
    environment: "production" | "sandbox";
}

// --- JWT caching -----------------------------------------------------------
// APNs accepts a JWT for up to 60 minutes. Build one lazily and reuse it
// across invocations until it ages out.
let cachedJwt: { token: string; expiresAt: number } | null = null;

async function buildJwt(): Promise<string> {
    if (cachedJwt && cachedJwt.expiresAt > Date.now() + 60_000) {
        return cachedJwt.token;
    }

    const teamId = Deno.env.get("APNS_TEAM_ID")!;
    const keyId  = Deno.env.get("APNS_KEY_ID")!;
    const pem    = Deno.env.get("APNS_AUTH_KEY")!;

    const header  = { alg: "ES256", kid: keyId };
    const iat     = Math.floor(Date.now() / 1000);
    const payload = { iss: teamId, iat };

    const b64url = (buf: ArrayBuffer | Uint8Array) => {
        const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
        let str = "";
        for (const b of bytes) str += String.fromCharCode(b);
        return btoa(str).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
    };
    const encode = (obj: unknown) =>
        b64url(new TextEncoder().encode(JSON.stringify(obj)));

    const signingInput = `${encode(header)}.${encode(payload)}`;

    // Import the .p8 (PKCS#8 ECDSA P-256) into SubtleCrypto.
    const pemBody = pem
        .replace("-----BEGIN PRIVATE KEY-----", "")
        .replace("-----END PRIVATE KEY-----", "")
        .replace(/\s+/g, "");
    const keyBytes = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0));
    const key = await crypto.subtle.importKey(
        "pkcs8",
        keyBytes,
        { name: "ECDSA", namedCurve: "P-256" },
        false,
        ["sign"],
    );

    const signature = await crypto.subtle.sign(
        { name: "ECDSA", hash: "SHA-256" },
        key,
        new TextEncoder().encode(signingInput),
    );

    const jwt = `${signingInput}.${b64url(signature)}`;
    // Refresh 5 minutes before the hard 60-minute limit.
    cachedJwt = { token: jwt, expiresAt: Date.now() + 55 * 60_000 };
    return jwt;
}

// --- APNs send -------------------------------------------------------------

async function sendOne(
    notification: NotificationRow,
    device: DeviceTokenRow,
    jwt: string,
    admin: ReturnType<typeof createClient>,
) {
    const bundleId = Deno.env.get("APNS_BUNDLE_ID")!;
    const apnsEnv  = (Deno.env.get("APNS_ENV") ?? "production").toLowerCase();
    const host = apnsEnv === "sandbox"
        ? "api.sandbox.push.apple.com"
        : "api.push.apple.com";

    const body = {
        aps: {
            alert: {
                title: notification.title,
                body:  notification.message,
            },
            sound: "default",
            "thread-id": notification.kind,
        },
        // Custom payload the iOS delegate reads to deep-link on tap.
        notification_id: notification.id,
        kind: notification.kind,
        memory_id: notification.memory_id,
        template_kind: notification.template_kind,
    };

    const url = `https://${host}/3/device/${device.token}`;
    const res = await fetch(url, {
        method: "POST",
        headers: {
            "authorization":    `bearer ${jwt}`,
            "apns-topic":       bundleId,
            "apns-push-type":   "alert",
            "apns-priority":    "10",
            "content-type":     "application/json",
        },
        body: JSON.stringify(body),
    });

    if (res.status === 410) {
        await admin.from("device_tokens").delete().eq("token", device.token);
    } else if (!res.ok) {
        console.error("[send-push] APNs rejected", {
            status: res.status,
            body:   await res.text(),
        });
    }
}

// --- Handler ---------------------------------------------------------------

Deno.serve(async (req) => {
    if (req.method !== "POST") {
        return new Response("method not allowed", { status: 405 });
    }

    const { notification_id } = await req.json() as { notification_id?: string };
    if (!notification_id) {
        return new Response("missing notification_id", { status: 400 });
    }

    const admin = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: notification, error: notifErr } = await admin
        .from("notifications")
        .select("id, user_id, kind, title, message, memory_id, template_kind")
        .eq("id", notification_id)
        .maybeSingle();

    if (notifErr || !notification) {
        console.error("[send-push] notification lookup failed", notifErr);
        return new Response("not found", { status: 404 });
    }

    const { data: tokens, error: tokErr } = await admin
        .from("device_tokens")
        .select("token, environment")
        .eq("user_id", notification.user_id);

    if (tokErr) {
        console.error("[send-push] token lookup failed", tokErr);
        return new Response("token lookup failed", { status: 500 });
    }

    if (!tokens || tokens.length === 0) {
        // No devices registered — nothing to do.
        return new Response("no tokens", { status: 200 });
    }

    const jwt = await buildJwt();
    await Promise.allSettled(
        tokens.map(t => sendOne(notification as NotificationRow, t, jwt, admin)),
    );

    return new Response("ok", { status: 200 });
});
