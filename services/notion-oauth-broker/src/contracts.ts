export interface OAuthTokens {
  readonly accessToken: string;
  readonly refreshToken: string | null;
  readonly botID: string;
  readonly workspaceID: string;
  readonly workspaceName: string;
  readonly workspaceIcon: string | null;
}

export interface SessionRecord extends OAuthTokens {
  readonly sessionID: string;
  readonly callbackURL: string;
  readonly phase: "pending" | "authorized" | "delivered";
  readonly createdAt: number;
  readonly replayUntil: number | null;
  readonly revocationToken: string | null;
  readonly revocationDigest: string | null;
}

export interface CompletedConnection extends OAuthTokens {
  readonly connectionID: string;
  readonly revocationToken: string;
}

export interface SessionRepository {
  read(): Promise<SessionRecord | null>;
  write(record: SessionRecord): Promise<void>;
  clear(): Promise<void>;
  expireAt(timestamp: number): Promise<void>;
}

export interface NotionOAuthAPI {
  exchange(code: string): Promise<OAuthTokens>;
  revoke(accessToken: string): Promise<void>;
}

export interface BrokerConfiguration {
  readonly clientID: string;
  readonly redirectURI: string;
  readonly allowedCallbackURL: string;
  readonly sessionLifetimeMilliseconds: number;
  readonly completionReplayMilliseconds: number;
}

export interface RandomSource {
  token(): string;
}

export interface Clock {
  now(): number;
}
