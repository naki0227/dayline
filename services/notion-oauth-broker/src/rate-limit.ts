import { DurableObject } from "cloudflare:workers";

import type { Env } from "./worker-env";
import { emptyResponse, jsonResponse } from "./security";
import { evaluateRateLimit, rateLimitExpiration, type RateLimitRecord } from "./rate-limit-policy";

export class OAuthRateLimiter extends DurableObject<Env> {
  async fetch(request: Request): Promise<Response> {
    if (request.method !== "POST") return emptyResponse(404);
    const now = Date.now();
    const record = (await this.ctx.storage.get<RateLimitRecord>("limit")) ?? null;
    const result = evaluateRateLimit(record, now);
    await this.ctx.storage.put("limit", result.next);
    await this.ctx.storage.setAlarm(rateLimitExpiration(result.next));
    return jsonResponse({ allowed: result.allowed }, result.allowed ? 200 : 429);
  }

  async alarm(): Promise<void> {
    await this.ctx.storage.deleteAll();
  }
}
