import { describe, expect, it } from "vitest";

import type {
  BrokerConfiguration,
  NotionOAuthAPI,
  OAuthTokens,
  SessionRecord,
  SessionRepository,
} from "../src/contracts";
import { OAuthSessionService } from "../src/session-service";

const configuration: BrokerConfiguration = {
  clientID: "client-id",
  redirectURI: "https://broker.example/v1/notion/oauth/callback",
  allowedCallbackURL: "dayline://oauth/notion",
  sessionLifetimeMilliseconds: 600_000,
  completionReplayMilliseconds: 120_000,
};

const tokens: OAuthTokens = {
  accessToken: "access-secret",
  refreshToken: "refresh-secret",
  botID: "bot-id",
  workspaceID: "workspace-id",
  workspaceName: "Dayline Workspace",
  workspaceIcon: null,
};

describe("OAuthSessionService", () => {
  it("completes once and revokes with a separate capability", async () => {
    const repository = new MemoryRepository();
    const notion = new NotionProbe();
    const service = makeService(repository, notion);

    const authorizationURL = new URL(await service.start("session-id", "dayline://oauth/notion"));
    expect(authorizationURL.searchParams.get("state")).toBe("session-id");
    expect(authorizationURL.searchParams.get("client_id")).toBe("client-id");
    expect(authorizationURL.searchParams.get("owner")).toBe("user");

    const callback = new URL(await service.authorize("authorization-code", false));
    expect(callback.toString()).toBe("dayline://oauth/notion?session_id=session-id&result=success");
    expect(notion.exchangedCodes).toEqual(["authorization-code"]);

    const connection = await service.complete();
    expect(connection).toEqual({
      ...tokens,
      connectionID: "session-id",
      revocationToken: "revocation-capability",
    });
    await expect(service.complete()).resolves.toEqual(connection);
    await service.expire();
    await expect(service.complete()).rejects.toMatchObject({ code: "invalid_session" });

    await expect(service.revoke("wrong-capability")).rejects.toMatchObject({
      code: "access_denied",
    });
    expect(repository.record).not.toBeNull();
    await service.revoke("revocation-capability");
    expect(notion.revokedTokens).toEqual(["access-secret"]);
    expect(repository.record).toBeNull();
  });

  it("does not exchange a code when the user denies access", async () => {
    const repository = new MemoryRepository();
    const notion = new NotionProbe();
    const service = makeService(repository, notion);
    await service.start("session-id", "dayline://oauth/notion");

    const callback = await service.authorize(null, true);

    expect(callback).toBe("dayline://oauth/notion?session_id=session-id&result=denied");
    expect(notion.exchangedCodes).toEqual([]);
    expect(repository.record).toBeNull();
  });

  it("rejects open redirects and expired sessions", async () => {
    const repository = new MemoryRepository();
    const notion = new NotionProbe();
    let now = 1_000;
    const service = new OAuthSessionService(
      repository,
      notion,
      configuration,
      { token: () => "revocation-capability" },
      { now: () => now },
    );

    await expect(service.start("session", "attacker://callback")).rejects.toMatchObject({
      code: "invalid_request",
    });
    await service.start("session", "dayline://oauth/notion");
    now += configuration.sessionLifetimeMilliseconds;

    await expect(service.authorize("code", false)).rejects.toMatchObject({
      code: "expired_session",
    });
    expect(repository.record).toBeNull();
  });
});

class MemoryRepository implements SessionRepository {
  record: SessionRecord | null = null;
  alarm: number | null = null;

  async read(): Promise<SessionRecord | null> {
    return this.record;
  }

  async write(record: SessionRecord): Promise<void> {
    this.record = structuredClone(record);
  }

  async clear(): Promise<void> {
    this.record = null;
  }

  async expireAt(timestamp: number): Promise<void> {
    this.alarm = timestamp;
  }
}

class NotionProbe implements NotionOAuthAPI {
  readonly exchangedCodes: string[] = [];
  readonly revokedTokens: string[] = [];

  async exchange(code: string): Promise<OAuthTokens> {
    this.exchangedCodes.push(code);
    return tokens;
  }

  async revoke(accessToken: string): Promise<void> {
    this.revokedTokens.push(accessToken);
  }
}

function makeService(repository: MemoryRepository, notion: NotionProbe): OAuthSessionService {
  return new OAuthSessionService(
    repository,
    notion,
    configuration,
    { token: () => "revocation-capability" },
    { now: () => 1_000 },
  );
}
