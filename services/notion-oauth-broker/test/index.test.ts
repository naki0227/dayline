import { describe, expect, it } from "vitest";

import { handleRequest } from "../src/index";

describe("broker scaffold", () => {
  it("exposes a content-free health response", async () => {
    const response = handleRequest({ method: "GET", url: "https://broker.example/health" });

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ status: "ok" });
  });

  it("fails closed for unknown routes", async () => {
    const response = handleRequest({ method: "GET", url: "https://broker.example/unknown" });

    expect(response.status).toBe(404);
    expect(await response.text()).toBe("");
  });
});
