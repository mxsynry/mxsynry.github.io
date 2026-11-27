import { afterEach, describe, expect, it, vi } from "vitest";
import { initialUpdate, refreshCatalog } from "./index";

afterEach(() => vi.unstubAllGlobals());

describe("current catalog source set", () => {
  it("loads the new bridge routes and keeps upstream-stale data marked cached", async () => {
    vi.stubGlobal("window", { setTimeout, clearTimeout });
    vi.stubGlobal("localStorage", { setItem: vi.fn() });
    const urls: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        urls.push(url);
        const path = new URL(url).pathname;
        const payloads: Record<string, unknown> = {
          "/api/status/exploits": [
            { title: "Example", platform: "Windows", updateStatus: true },
          ],
          "/api/versions/current": {},
          "/api/voxlis/catalog": {
            stale: true,
            cards: [
              {
                slug: "example",
                title: "Example",
                platform: "windows",
                type: "executor",
                status: "updated",
              },
            ],
          },
          "/api/bypass/catalog": {
            executors: [
              {
                name: "Example",
                category: "Windows Executors",
                status: "Working",
              },
            ],
          },
          "/api/pulsery/status": {
            executors: [
              { name: "Example", platforms: ["Windows"], is_working: true },
            ],
          },
        };
        if (!(path in payloads))
          throw new Error(`Unexpected source request: ${url}`);
        return new Response(JSON.stringify(payloads[path]));
      }),
    );
    const result = await refreshCatalog(
      "https://bridge.test",
      initialUpdate(null),
      () => {},
    );
    expect(result.pending).toBe(0);
    expect(result.health.voxlis.state).toBe("cached");
    expect(result.health.bypass.state).toBe("live");
    expect(result.records[0].sources).toEqual([
      "weao",
      "voxlis",
      "pulsery",
      "bypass",
    ]);
    expect(urls).toContain("https://bridge.test/api/voxlis/catalog");
    expect(urls).toContain("https://bridge.test/api/bypass/catalog");
    expect(
      urls.some((url) => /inject|voxlis\/(prices|entry|review)/.test(url)),
    ).toBe(false);
  });
});
