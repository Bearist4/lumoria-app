import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { decide, type WaitlistRow } from "./index.ts";

const fresh: WaitlistRow = {
  id: "row-1",
  email: "user@example.com",
  code_hash: "fakehash",
  code_expires_at: new Date(Date.now() + 60_000).toISOString(),
  supabase_user_id: null,
};

Deno.test("decide: rate limited at 5 failed attempts", () => {
  const r = decide({ row: fresh, submittedHash: "fakehash", failedAttemptsInWindow: 5 });
  assertEquals(r.outcome, "rate_limited");
});

Deno.test("decide: not rate limited under 5 failed attempts", () => {
  const r = decide({ row: fresh, submittedHash: "fakehash", failedAttemptsInWindow: 4 });
  assertEquals(r.outcome, "ok");
});

Deno.test("decide: no row for email", () => {
  const r = decide({ row: null, submittedHash: "x", failedAttemptsInWindow: 0 });
  assertEquals(r.outcome, "not_found");
});

Deno.test("decide: expired", () => {
  const expired = { ...fresh, code_expires_at: new Date(Date.now() - 1).toISOString() };
  const r = decide({ row: expired, submittedHash: "fakehash", failedAttemptsInWindow: 0 });
  assertEquals(r.outcome, "expired");
});

Deno.test("decide: wrong code", () => {
  const r = decide({ row: fresh, submittedHash: "wrong", failedAttemptsInWindow: 0 });
  assertEquals(r.outcome, "wrong_code");
});

Deno.test("decide: already linked to someone else", () => {
  const linked = { ...fresh, supabase_user_id: "other-user" };
  const r = decide({ row: linked, submittedHash: "fakehash", failedAttemptsInWindow: 0 });
  assertEquals(r.outcome, "already_claimed");
});

Deno.test("decide: success", () => {
  const r = decide({ row: fresh, submittedHash: "fakehash", failedAttemptsInWindow: 0 });
  assertEquals(r.outcome, "ok");
});

Deno.test("decide: missing code_hash on row", () => {
  const noHash = { ...fresh, code_hash: null };
  const r = decide({ row: noHash, submittedHash: "anything", failedAttemptsInWindow: 0 });
  assertEquals(r.outcome, "expired"); // treat as no valid code
});
