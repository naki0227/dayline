const MAXIMUM_BODY_BYTES = 4_096;

export class BrokerFailure extends Error {
  constructor(
    readonly code:
      | "invalid_request"
      | "invalid_session"
      | "expired_session"
      | "access_denied"
      | "rate_limited"
      | "upstream_unavailable",
    readonly status: number,
  ) {
    super(code);
  }
}

export function randomToken(byteCount = 32): string {
  const bytes = new Uint8Array(byteCount);
  crypto.getRandomValues(bytes);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function hmacSha256(value: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function constantTimeEqual(left: string, right: string): boolean {
  const length = Math.max(left.length, right.length);
  let difference = left.length ^ right.length;
  for (let index = 0; index < length; index += 1) {
    difference |= (left.charCodeAt(index) || 0) ^ (right.charCodeAt(index) || 0);
  }
  return difference === 0;
}

export async function readJSON(request: Request): Promise<Record<string, unknown>> {
  const declaredLength = Number(request.headers.get("Content-Length") ?? "0");
  if (!Number.isFinite(declaredLength) || declaredLength > MAXIMUM_BODY_BYTES) {
    throw new BrokerFailure("invalid_request", 413);
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > MAXIMUM_BODY_BYTES) {
    throw new BrokerFailure("invalid_request", 413);
  }
  try {
    const value: unknown = JSON.parse(text);
    if (typeof value !== "object" || value === null || Array.isArray(value)) {
      throw new BrokerFailure("invalid_request", 400);
    }
    return value as Record<string, unknown>;
  } catch (error) {
    if (error instanceof BrokerFailure) throw error;
    throw new BrokerFailure("invalid_request", 400);
  }
}

export function requiredString(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  if (typeof value !== "string" || value.length === 0 || value.length > 2_048) {
    throw new BrokerFailure("invalid_request", 400);
  }
  return value;
}

export function jsonResponse(value: unknown, status = 200): Response {
  return Response.json(value, {
    status,
    headers: securityHeaders(),
  });
}

export function emptyResponse(status: number): Response {
  return new Response(null, { status, headers: securityHeaders() });
}

export function failureResponse(error: unknown): Response {
  const failure =
    error instanceof BrokerFailure ? error : new BrokerFailure("upstream_unavailable", 502);
  return jsonResponse({ error: failure.code }, failure.status);
}

export function redirectResponse(url: string): Response {
  return new Response(null, {
    status: 302,
    headers: { ...securityHeaders(), Location: url },
  });
}

function securityHeaders(): Record<string, string> {
  return {
    "Cache-Control": "no-store",
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
  };
}
