import type {
  BrokerConfiguration,
  Clock,
  CompletedConnection,
  NotionOAuthAPI,
  RandomSource,
  SessionRecord,
  SessionRepository,
} from "./contracts";
import { BrokerFailure, constantTimeEqual, sha256 } from "./security";

const emptyTokens = {
  accessToken: "",
  refreshToken: null,
  botID: "",
  workspaceID: "",
  workspaceName: "",
  workspaceIcon: null,
} as const;

export class OAuthSessionService {
  constructor(
    private readonly repository: SessionRepository,
    private readonly notion: NotionOAuthAPI,
    private readonly configuration: BrokerConfiguration,
    private readonly random: RandomSource,
    private readonly clock: Clock,
  ) {}

  async start(sessionID: string, callbackURL: string): Promise<string> {
    if (callbackURL !== this.configuration.allowedCallbackURL) {
      throw new BrokerFailure("invalid_request", 400);
    }
    if (await this.repository.read()) throw new BrokerFailure("invalid_session", 409);
    const createdAt = this.clock.now();
    await this.repository.write({
      ...emptyTokens,
      sessionID,
      callbackURL,
      phase: "pending",
      createdAt,
      replayUntil: null,
      revocationToken: null,
      revocationDigest: null,
    });
    await this.repository.expireAt(createdAt + this.configuration.sessionLifetimeMilliseconds);
    return authorizationURL(this.configuration, sessionID);
  }

  async authorize(code: string | null, denied: boolean): Promise<string> {
    const record = await this.requireCurrent("pending");
    if (denied) {
      const callback = callbackURL(record, "denied");
      await this.repository.clear();
      return callback;
    }
    if (!code) throw new BrokerFailure("invalid_request", 400);
    const tokens = await this.notion.exchange(code);
    const revocationToken = this.random.token();
    await this.repository.write({
      ...record,
      ...tokens,
      phase: "authorized",
      revocationToken,
      revocationDigest: await sha256(revocationToken),
    });
    return callbackURL(record, "success");
  }

  async complete(): Promise<CompletedConnection> {
    const record = await this.repository.read();
    if (!record) throw new BrokerFailure("invalid_session", 404);
    const now = this.clock.now();
    if (record.phase === "authorized") {
      if (now >= record.createdAt + this.configuration.sessionLifetimeMilliseconds) {
        await this.repository.clear();
        throw new BrokerFailure("expired_session", 410);
      }
    } else if (
      record.phase !== "delivered" ||
      record.replayUntil === null ||
      now >= record.replayUntil
    ) {
      throw new BrokerFailure("invalid_session", 409);
    }
    if (!record.revocationToken || !record.revocationDigest) {
      throw new BrokerFailure("invalid_session", 409);
    }
    const connection: CompletedConnection = {
      accessToken: record.accessToken,
      refreshToken: record.refreshToken,
      botID: record.botID,
      workspaceID: record.workspaceID,
      workspaceName: record.workspaceName,
      workspaceIcon: record.workspaceIcon,
      connectionID: record.sessionID,
      revocationToken: record.revocationToken,
    };
    if (record.phase === "authorized") {
      const replayUntil = now + this.configuration.completionReplayMilliseconds;
      await this.repository.write({ ...record, phase: "delivered", replayUntil });
      await this.repository.expireAt(replayUntil);
    }
    return connection;
  }

  async revoke(candidate: string): Promise<void> {
    const record = await this.repository.read();
    if (!record) return;
    if (record.phase !== "delivered" || !record.revocationDigest) {
      throw new BrokerFailure("invalid_session", 409);
    }
    const candidateDigest = await sha256(candidate);
    if (!constantTimeEqual(candidateDigest, record.revocationDigest)) {
      throw new BrokerFailure("access_denied", 403);
    }
    await this.notion.revoke(record.accessToken);
    await this.repository.clear();
  }

  async expire(): Promise<void> {
    const record = await this.repository.read();
    if (record?.phase === "delivered") {
      await this.repository.write({
        ...record,
        refreshToken: null,
        revocationToken: null,
        replayUntil: null,
      });
    } else {
      await this.repository.clear();
    }
  }

  private async requireCurrent(phase: SessionRecord["phase"]): Promise<SessionRecord> {
    const record = await this.repository.read();
    if (!record) throw new BrokerFailure("invalid_session", 404);
    if (this.clock.now() >= record.createdAt + this.configuration.sessionLifetimeMilliseconds) {
      await this.repository.clear();
      throw new BrokerFailure("expired_session", 410);
    }
    if (record.phase !== phase) throw new BrokerFailure("invalid_session", 409);
    return record;
  }
}

function authorizationURL(configuration: BrokerConfiguration, sessionID: string): string {
  const url = new URL("https://api.notion.com/v1/oauth/authorize");
  url.searchParams.set("client_id", configuration.clientID);
  url.searchParams.set("redirect_uri", configuration.redirectURI);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("owner", "user");
  url.searchParams.set("state", sessionID);
  return url.toString();
}

function callbackURL(record: SessionRecord, result: "success" | "denied"): string {
  const url = new URL(record.callbackURL);
  url.searchParams.set("session_id", record.sessionID);
  url.searchParams.set("result", result);
  return url.toString();
}
