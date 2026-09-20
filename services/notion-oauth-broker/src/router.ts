import type { Env } from "./worker-env";
import {
  BrokerFailure,
  emptyResponse,
  failureResponse,
  hmacSha256,
  jsonResponse,
  randomToken,
  readJSON,
  requiredString,
} from "./security";

const SESSION_PATTERN = /^[A-Za-z0-9_-]{43}$/;

export async function handleRequest(request: Request, env: Env): Promise<Response> {
  try {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return jsonResponse({ status: "ok" });
    }
    if (request.method === "POST" && url.pathname === "/v1/notion/oauth/sessions") {
      await enforceStartRateLimit(request, env);
      const body = await readJSON(request);
      const callbackURL = requiredString(body, "callback_url");
      const sessionID = randomToken();
      return sessionStub(env, sessionID).fetch(
        internalRequest("/start", { callback_url: callbackURL, session_id: sessionID }),
      );
    }
    if (request.method === "GET" && url.pathname === "/v1/notion/oauth/callback") {
      const sessionID = requiredSession(url.searchParams.get("state"));
      const code = url.searchParams.get("code");
      const denied = url.searchParams.has("error");
      if (!code && !denied) throw new BrokerFailure("invalid_request", 400);
      return sessionStub(env, sessionID).fetch(internalRequest("/authorize", { code, denied }));
    }
    if (request.method === "POST" && url.pathname === "/v1/notion/oauth/sessions/complete") {
      const body = await readJSON(request);
      const sessionID = requiredSession(requiredString(body, "session_id"));
      return sessionStub(env, sessionID).fetch(internalRequest("/complete", {}));
    }
    if (request.method === "POST" && url.pathname === "/v1/notion/oauth/connections/revoke") {
      const body = await readJSON(request);
      const connectionID = requiredSession(requiredString(body, "connection_id"));
      const revocationToken = requiredString(body, "revocation_token");
      return sessionStub(env, connectionID).fetch(
        internalRequest("/revoke", { revocation_token: revocationToken }),
      );
    }
    return emptyResponse(404);
  } catch (error) {
    return failureResponse(error);
  }
}

const worker: ExportedHandler<Env> = {
  fetch(request, env): Promise<Response> {
    return handleRequest(request, env);
  },
};

export default worker;

async function enforceStartRateLimit(request: Request, env: Env): Promise<void> {
  const clientAddress = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const secret = env.RATE_LIMIT_KEY_SECRET;
  if (secret.length < 32) throw new BrokerFailure("upstream_unavailable", 503);
  const minuteBucket = Math.floor(Date.now() / 60_000);
  const key = await hmacSha256(`${minuteBucket}:${clientAddress}`, secret);
  const response = await env.OAUTH_RATE_LIMITS.getByName(key).fetch(
    new Request("https://internal/check", { method: "POST" }),
  );
  if (response.status === 429) throw new BrokerFailure("rate_limited", 429);
  if (!response.ok) throw new BrokerFailure("upstream_unavailable", 503);
}

function sessionStub(env: Env, sessionID: string): DurableObjectStub {
  return env.OAUTH_SESSIONS.getByName(sessionID);
}

function requiredSession(value: string | null): string {
  if (!value || !SESSION_PATTERN.test(value)) {
    throw new BrokerFailure("invalid_session", 400);
  }
  return value;
}

function internalRequest(path: string, body: object): Request {
  return new Request(`https://internal${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}
