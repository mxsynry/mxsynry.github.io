import { afterEach, describe, expect, it, vi } from "vitest";
import { fetchVoxlis } from "./voxlis";
import { fetchBypass } from "./bypass";

afterEach(() => vi.unstubAllGlobals());
const local = "https://site.test";
const oldBridge = "https://old-bridge.test";
const vox = {
  cards: [
    {
      slug: "example",
      title: "Example",
      platform: "windows",
      status: "updated",
    },
  ],
};
const bypass = {
  executors: [
    { name: "Example", category: "Windows Executors", status: "Working" },
  ],
};
const reply = (payload: unknown, status = 200) =>
  new Response(JSON.stringify(payload), { status });

function browser() {
  vi.stubGlobal("window", {
    setTimeout,
    clearTimeout,
    location: { origin: local },
  });
}

describe("catalog hosting fallbacks", () => {
  it("recovers from the deployed old bridge's 404 using the site's bundled bridge", async () => {
    browser();
    const fetcher = vi.fn(async (url: string) => {
      if (url.startsWith(oldBridge))
        return reply({ ok: false, error: "Not found." }, 404);
      if (url === `${local}/api/voxlis/catalog`) return reply(vox);
      if (url === `${local}/api/bypass/catalog`) return reply(bypass);
      throw new Error(`Unexpected request ${url}`);
    });
    vi.stubGlobal("fetch", fetcher);
    const [voxlis, listing] = await Promise.all([
      fetchVoxlis(oldBridge),
      fetchBypass(oldBridge),
    ]);
    expect(voxlis.records).toHaveLength(1);
    expect(listing.records).toHaveLength(1);
    expect(voxlis.stale).toBe(false);
    expect(listing.stale).not.toBe(true);
    expect(
      fetcher.mock.calls.some(([url]) => url.startsWith("./catalog/")),
    ).toBe(false);
  });

  it("uses dated saved catalogs on static hosts and keeps their health and records cached", async () => {
    browser();
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        const source = url.includes("voxlis") ? "voxlis" : "bypass";
        if (!url.startsWith("./catalog/")) return reply({}, 404);
        return reply({
          ...(source === "voxlis" ? vox : bypass),
          snapshot: { source, fetchedAt: "2026-11-27T19:02:29Z" },
        });
      }),
    );
    for (const result of await Promise.all([
      fetchVoxlis(oldBridge),
      fetchBypass(oldBridge),
    ])) {
      expect(result.stale).toBe(true);
      expect(result.records[0].stale).toBe(true);
      expect(result.message).toContain("2026-11-27T19:02:29.000Z");
    }
  });

  it("recovers from a static host returning HTML for an API path", async () => {
    browser();
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) =>
        url.startsWith("./catalog/")
          ? reply({
              ...vox,
              snapshot: { source: "voxlis", fetchedAt: "2026-11-27T19:02:29Z" },
            })
          : new Response("<!doctype html><title>Site</title>"),
      ),
    );
    expect((await fetchVoxlis(oldBridge)).stale).toBe(true);
  });

  it("rejects a saved catalog for the wrong provider instead of reporting a live source", async () => {
    browser();
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) =>
        url.startsWith("./catalog/")
          ? reply({
              ...vox,
              snapshot: { source: "bypass", fetchedAt: "2026-11-27T19:02:29Z" },
            })
          : reply({}, 404),
      ),
    );
    await expect(fetchVoxlis(oldBridge)).rejects.toThrow(
      "Deploy the current site bridge",
    );
  });
});
