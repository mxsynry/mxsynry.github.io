import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import worker from "../../worker.js";

const cache = { match: vi.fn(), put: vi.fn() };
beforeEach(() => {
  cache.match.mockResolvedValue(undefined);
  cache.put.mockResolvedValue(undefined);
  vi.stubGlobal("caches", { default: cache });
});
afterEach(() => {
  vi.unstubAllGlobals();
  vi.clearAllMocks();
});
const request = (path, method = "GET") =>
  new Request(`https://bridge.test${path}`, { method });
const context = { waitUntil: (task) => void task };

describe("fixed public source bridge", () => {
  it("uses the current Voxlis directory and preserves source metadata and inline reviews", async () => {
    const payload = {
      cards: [{ slug: "example", title: "Example", review: "Published notes" }],
      stale: true,
      checkedAt: "2026-11-21T18:00:00Z",
      fetchedAt: "2026-11-21T18:01:00Z",
    };
    const fetcher = vi
      .fn()
      .mockResolvedValue(new Response(JSON.stringify(payload)));
    vi.stubGlobal("fetch", fetcher);
    const response = await worker.fetch(
      request("/api/voxlis/catalog"),
      {},
      context,
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("access-control-allow-origin")).toBe("*");
    expect(fetcher).toHaveBeenCalledWith(
      "https://voxlis.net/api/directory/roblox",
      expect.objectContaining({ method: "GET" }),
    );
    expect(await response.json()).toMatchObject({
      ...payload,
      bridgeFetchedAt: expect.any(String),
    });
  });

  it("only fetches the fixed bypass.tools feed and exposes the fields used by the adapter", async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify([
          {
            id: 3,
            name: "Example",
            status: "Working",
            category: "Windows Executors",
            features: "UNC, sUNC 96%",
            weao_synced: true,
            sunc_key: "not-forwarded",
            sunc_scrap: "not-forwarded",
            website_url: "javascript:bad()",
          },
        ]),
      ),
    );
    vi.stubGlobal("fetch", fetcher);
    const response = await worker.fetch(
      request("/api/bypass/catalog?url=https://unrelated.test"),
      {},
      context,
    );
    expect(fetcher).toHaveBeenCalledWith(
      "https://bypass.tools/api/executors",
      expect.objectContaining({ method: "GET" }),
    );
    const payload = await response.json();
    expect(payload.executors[0]).toMatchObject({
      id: "3",
      name: "Example",
      weao_synced: true,
      website_url: "",
    });
    expect(payload.executors[0]).not.toHaveProperty("sunc_key");
    expect(payload.executors[0]).not.toHaveProperty("sunc_scrap");
    expect(response.headers.get("access-control-allow-origin")).toBe("*");
  });

  it("returns a visible error for an unexpected upstream shape", async () => {
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue(new Response(JSON.stringify({ freeProducts: [] }))),
    );
    const response = await worker.fetch(
      request("/api/voxlis/catalog"),
      {},
      context,
    );
    expect(response.status).toBe(502);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(await response.json()).toMatchObject({
      ok: false,
      error: expect.stringContaining("unexpected directory"),
    });
  });

  it("does not serve retired source routes or act as an open proxy", async () => {
    const fetcher = vi.fn();
    vi.stubGlobal("fetch", fetcher);
    for (const path of [
      "/api/voxlis/prices",
      "/api/voxlis/entry?slug=example",
      "/api/voxlis/review?folder=example",
      "/api/inject/catalog",
      "/proxy?url=https://unrelated.test",
    ]) {
      expect((await worker.fetch(request(path), {}, context)).status).toBe(404);
    }
    expect(
      (await worker.fetch(request("/api/bypass/catalog", "POST"), {}, context))
        .status,
    ).toBe(405);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("advertises only the current catalog routes and keeps Pulsery reviews", async () => {
    const payload = await (
      await worker.fetch(request("/api/health"), {}, context)
    ).json();
    expect(payload.routes).toEqual([
      "/api/voxlis/catalog",
      "/api/bypass/catalog",
      "/api/pulsery/status",
      "/api/pulsery/reviews?executor=NAME",
    ]);
  });
});
