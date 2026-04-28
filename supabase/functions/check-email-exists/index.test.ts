import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { decide, normalizeEmail } from "./index.ts";

Deno.test("normalizeEmail: trims and lowercases", () => {
  assertEquals(normalizeEmail("  Foo@Bar.COM  "), "foo@bar.com");
});

Deno.test("normalizeEmail: empty input stays empty", () => {
  assertEquals(normalizeEmail("   "), "");
});

Deno.test("decide: rate-limited at 10 hits in window", () => {
  const r = decide({ existsInDb: false, hitsInWindow: 10 });
  assertEquals(r.outcome, "rate_limited");
});

Deno.test("decide: not rate-limited under 10 hits", () => {
  const r = decide({ existsInDb: true, hitsInWindow: 9 });
  assertEquals(r.outcome, "ok");
  assertEquals(r.exists, true);
});

Deno.test("decide: ok with exists=false", () => {
  const r = decide({ existsInDb: false, hitsInWindow: 0 });
  assertEquals(r.outcome, "ok");
  assertEquals(r.exists, false);
});
