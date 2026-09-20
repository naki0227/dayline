import { describe, expect, it } from "vitest";

import { NotionAPIClient } from "../src/notion-api";

describe("NotionAPIClient", () => {
  it("exchanges a code with Basic auth and the pinned API version", async () => {
    const requests: Request[] = [];
    const client = new NotionAPIClient(
      "client-id",
      "client-secret",
      "https://broker.example/callback",
      async (input, init) => {
        requests.push(new Request(input, init));
        return Response.json({
          access_token: "access",
          refresh_token: "refresh",
          bot_id: "bot",
          workspace_id: "workspace",
          workspace_name: "Name",
          workspace_icon: null,
        });
      },
    );

    const result = await client.exchange("code");
    const request = requests[0];
    expect(request).toBeDefined();
    expect(request?.headers.get("Authorization")).toBe(`Basic ${btoa("client-id:client-secret")}`);
    expect(request?.headers.get("Notion-Version")).toBe("2026-03-11");
    await expect(request?.json()).resolves.toMatchObject({
      grant_type: "authorization_code",
      code: "code",
      redirect_uri: "https://broker.example/callback",
    });
    expect(result.workspaceName).toBe("Name");
  });

  it("maps upstream response bodies to a content-free failure", async () => {
    const client = new NotionAPIClient(
      "client-id",
      "client-secret",
      "https://broker.example/callback",
      async () => new Response("private upstream detail", { status: 401 }),
    );

    await expect(client.exchange("code")).rejects.toMatchObject({
      code: "upstream_unavailable",
      status: 502,
    });
  });

  it("revokes the access token through the official endpoint", async () => {
    const requests: Request[] = [];
    const client = new NotionAPIClient(
      "client-id",
      "client-secret",
      "https://broker.example/callback",
      async (input, init) => {
        requests.push(new Request(input, init));
        return Response.json({ request_id: "request" });
      },
    );

    await client.revoke("access-secret");

    expect(requests[0]?.url).toBe("https://api.notion.com/v1/oauth/revoke");
    await expect(requests[0]?.json()).resolves.toEqual({ token: "access-secret" });
  });
});
