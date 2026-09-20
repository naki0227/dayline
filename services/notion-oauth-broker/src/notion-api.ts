import type { NotionOAuthAPI, OAuthTokens } from "./contracts";
import { BrokerFailure } from "./security";

const NOTION_VERSION = "2026-03-11";

type Fetcher = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;

export class NotionAPIClient implements NotionOAuthAPI {
  constructor(
    private readonly clientID: string,
    private readonly clientSecret: string,
    private readonly redirectURI: string,
    private readonly fetcher: Fetcher = fetch,
  ) {}

  async exchange(code: string): Promise<OAuthTokens> {
    const response = await this.request("https://api.notion.com/v1/oauth/token", {
      grant_type: "authorization_code",
      code,
      redirect_uri: this.redirectURI,
    });
    const body = await decodeObject(response);
    return {
      accessToken: readString(body, "access_token"),
      refreshToken: readNullableString(body, "refresh_token"),
      botID: readString(body, "bot_id"),
      workspaceID: readString(body, "workspace_id"),
      workspaceName: readNullableString(body, "workspace_name") ?? "Notion workspace",
      workspaceIcon: readNullableString(body, "workspace_icon"),
    };
  }

  async revoke(accessToken: string): Promise<void> {
    await this.request("https://api.notion.com/v1/oauth/revoke", { token: accessToken });
  }

  private async request(url: string, body: object): Promise<Response> {
    let response: Response;
    try {
      response = await this.fetcher(url, {
        method: "POST",
        headers: {
          Authorization: `Basic ${btoa(`${this.clientID}:${this.clientSecret}`)}`,
          "Content-Type": "application/json",
          "Notion-Version": NOTION_VERSION,
        },
        body: JSON.stringify(body),
      });
    } catch {
      throw new BrokerFailure("upstream_unavailable", 502);
    }
    if (!response.ok) throw new BrokerFailure("upstream_unavailable", 502);
    return response;
  }
}

async function decodeObject(response: Response): Promise<Record<string, unknown>> {
  try {
    const value: unknown = await response.json();
    if (typeof value !== "object" || value === null || Array.isArray(value)) {
      throw new Error("invalid response");
    }
    return value as Record<string, unknown>;
  } catch {
    throw new BrokerFailure("upstream_unavailable", 502);
  }
}

function readString(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  if (typeof value !== "string" || value.length === 0) {
    throw new BrokerFailure("upstream_unavailable", 502);
  }
  return value;
}

function readNullableString(body: Record<string, unknown>, key: string): string | null {
  const value = body[key];
  if (value === null) return null;
  return readString(body, key);
}
