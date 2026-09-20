import { DurableObject } from "cloudflare:workers";

import type {
  BrokerConfiguration,
  Clock,
  RandomSource,
  SessionRecord,
  SessionRepository,
} from "./contracts";
import { NotionAPIClient } from "./notion-api";
import { OAuthSessionService } from "./session-service";
import type { Env } from "./worker-env";
import {
  BrokerFailure,
  emptyResponse,
  failureResponse,
  jsonResponse,
  randomToken,
  readJSON,
  redirectResponse,
  requiredString,
} from "./security";

const SESSION_LIFETIME_MILLISECONDS = 10 * 60 * 1_000;
const COMPLETION_REPLAY_MILLISECONDS = 2 * 60 * 1_000;

export class OAuthSession extends DurableObject<Env> {
  async fetch(request: Request): Promise<Response> {
    try {
      const service = this.service();
      const path = new URL(request.url).pathname;
      if (request.method === "POST" && path === "/start") {
        const body = await readJSON(request);
        const sessionID = requiredString(body, "session_id");
        const callbackURL = requiredString(body, "callback_url");
        const authorizationURL = await service.start(sessionID, callbackURL);
        return jsonResponse({ authorization_url: authorizationURL, session_id: sessionID });
      }
      if (request.method === "POST" && path === "/authorize") {
        const body = await readJSON(request);
        const code = optionalString(body, "code");
        const denied = body.denied === true;
        return redirectResponse(await service.authorize(code, denied));
      }
      if (request.method === "POST" && path === "/complete") {
        const connection = await service.complete();
        return jsonResponse({
          access_token: connection.accessToken,
          refresh_token: connection.refreshToken,
          bot_id: connection.botID,
          workspace_id: connection.workspaceID,
          workspace_name: connection.workspaceName,
          workspace_icon: connection.workspaceIcon,
          connection_id: connection.connectionID,
          revocation_token: connection.revocationToken,
        });
      }
      if (request.method === "POST" && path === "/revoke") {
        const body = await readJSON(request);
        await service.revoke(requiredString(body, "revocation_token"));
        return emptyResponse(204);
      }
      return emptyResponse(404);
    } catch (error) {
      return failureResponse(error);
    }
  }

  async alarm(): Promise<void> {
    await this.service().expire();
  }

  private service(): OAuthSessionService {
    return new OAuthSessionService(
      new DurableSessionRepository(this.ctx.storage),
      new NotionAPIClient(
        requiredEnvironment(this.env.NOTION_CLIENT_ID),
        requiredEnvironment(this.env.NOTION_CLIENT_SECRET),
        requiredEnvironment(this.env.NOTION_REDIRECT_URI),
      ),
      configuration(this.env),
      systemRandom,
      systemClock,
    );
  }
}

class DurableSessionRepository implements SessionRepository {
  constructor(private readonly storage: DurableObjectStorage) {}

  async read(): Promise<SessionRecord | null> {
    return (await this.storage.get<SessionRecord>("session")) ?? null;
  }

  async write(record: SessionRecord): Promise<void> {
    await this.storage.put("session", record);
  }

  async clear(): Promise<void> {
    await this.storage.deleteAll();
  }

  async expireAt(timestamp: number): Promise<void> {
    await this.storage.setAlarm(timestamp);
  }
}

const systemRandom: RandomSource = { token: () => randomToken() };
const systemClock: Clock = { now: () => Date.now() };

function configuration(env: Env): BrokerConfiguration {
  const redirectURI = requiredEnvironment(env.NOTION_REDIRECT_URI);
  const allowedCallbackURL = requiredEnvironment(env.DAYLINE_CALLBACK_URL);
  if (new URL(redirectURI).protocol !== "https:") {
    throw new BrokerFailure("upstream_unavailable", 503);
  }
  if (allowedCallbackURL !== "dayline://oauth/notion") {
    throw new BrokerFailure("upstream_unavailable", 503);
  }
  return {
    clientID: requiredEnvironment(env.NOTION_CLIENT_ID),
    redirectURI,
    allowedCallbackURL,
    sessionLifetimeMilliseconds: SESSION_LIFETIME_MILLISECONDS,
    completionReplayMilliseconds: COMPLETION_REPLAY_MILLISECONDS,
  };
}

function requiredEnvironment(value: string): string {
  if (!value) throw new BrokerFailure("upstream_unavailable", 503);
  return value;
}

function optionalString(body: Record<string, unknown>, key: string): string | null {
  const value = body[key];
  if (value === undefined || value === null) return null;
  if (typeof value !== "string" || value.length === 0 || value.length > 2_048) {
    throw new BrokerFailure("invalid_request", 400);
  }
  return value;
}
