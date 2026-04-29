import { assertEquals, assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { generateCode, hashCode, isExpired, normalizeCode } from "./beta_code.ts";

Deno.test("generateCode returns 6 numeric digits", () => {
  for (let i = 0; i < 50; i++) {
    const code = generateCode();
    assertMatch(code, /^[0-9]{6}$/);
  }
});

Deno.test("hashCode is stable and SHA-256 hex (64 chars)", async () => {
  const a = await hashCode("123456");
  const b = await hashCode("123456");
  assertEquals(a, b);
  assertEquals(a.length, 64);
});

Deno.test("hashCode differs for different inputs", async () => {
  const a = await hashCode("123456");
  const b = await hashCode("123457");
  if (a === b) throw new Error("hash collision on adjacent codes");
});

Deno.test("normalizeCode strips whitespace and dashes", () => {
  assertEquals(normalizeCode(" 123 456 "), "123456");
  assertEquals(normalizeCode("123-456"), "123456");
  assertEquals(normalizeCode("123456"), "123456");
});

Deno.test("isExpired", () => {
  const past = new Date(Date.now() - 1000).toISOString();
  const future = new Date(Date.now() + 60_000).toISOString();
  assertEquals(isExpired(past), true);
  assertEquals(isExpired(future), false);
  assertEquals(isExpired(null), true);
});
