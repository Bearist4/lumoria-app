const CODE_LENGTH = 6;

/** Uniformly-random 6-digit string via crypto.getRandomValues. */
export function generateCode(): string {
  const buf = new Uint32Array(1);
  // 4_000_000_000 is the largest multiple of 1_000_000 ≤ 2^32.
  // Reject samples in the high tail to avoid modulo bias.
  const limit = 4_000_000_000;
  let n: number;
  do {
    crypto.getRandomValues(buf);
    n = buf[0];
  } while (n >= limit);
  return (n % 1_000_000).toString().padStart(CODE_LENGTH, "0");
}

/** SHA-256 hex digest of the plaintext code. */
export async function hashCode(code: string): Promise<string> {
  const data = new TextEncoder().encode(code);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Strips whitespace and common separators users paste. */
export function normalizeCode(input: string): string {
  return input.replace(/[\s\-_.]/g, "");
}

/** True when expiry is null or in the past. */
export function isExpired(expiresAt: string | null): boolean {
  if (!expiresAt) return true;
  return new Date(expiresAt).getTime() <= Date.now();
}
