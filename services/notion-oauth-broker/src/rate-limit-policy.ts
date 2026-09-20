const WINDOW_MILLISECONDS = 60_000;
const MAXIMUM_STARTS_PER_WINDOW = 10;

export interface RateLimitRecord {
  readonly startedAt: number;
  readonly count: number;
}

export function evaluateRateLimit(
  record: RateLimitRecord | null,
  now: number,
): { readonly allowed: boolean; readonly next: RateLimitRecord } {
  if (!record || now >= record.startedAt + WINDOW_MILLISECONDS) {
    return { allowed: true, next: { startedAt: now, count: 1 } };
  }
  const count = record.count + 1;
  return { allowed: count <= MAXIMUM_STARTS_PER_WINDOW, next: { ...record, count } };
}

export function rateLimitExpiration(record: RateLimitRecord): number {
  return record.startedAt + WINDOW_MILLISECONDS;
}
