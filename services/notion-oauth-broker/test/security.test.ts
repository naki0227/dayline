import { describe, expect, it } from "vitest";

import { hmacSha256 } from "../src/security";

describe("rate-limit key derivation", () => {
  it("uses keyed SHA-256 instead of a stable plain address hash", async () => {
    const first = await hmacSha256("minute:203.0.113.1", "a".repeat(32));
    const second = await hmacSha256("minute:203.0.113.1", "b".repeat(32));

    expect(first).toHaveLength(64);
    expect(first).not.toBe(second);
  });
});
