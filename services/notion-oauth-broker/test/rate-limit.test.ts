import { describe, expect, it } from "vitest";

import { evaluateRateLimit } from "../src/rate-limit-policy";

describe("start rate limiting", () => {
  it("allows ten starts in one window and rejects the eleventh", () => {
    let record = null;
    for (let count = 1; count <= 11; count += 1) {
      const result = evaluateRateLimit(record, 1_000);
      record = result.next;
      expect(result.allowed).toBe(count <= 10);
    }
  });

  it("opens a new window after sixty seconds", () => {
    const result = evaluateRateLimit({ startedAt: 1_000, count: 10 }, 61_000);
    expect(result).toEqual({ allowed: true, next: { startedAt: 61_000, count: 1 } });
  });
});
