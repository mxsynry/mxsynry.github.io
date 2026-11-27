import { afterEach, describe, expect, it, vi } from "vitest";
import { fetchBypass } from "./bypass";

afterEach(() => vi.unstubAllGlobals());
function reply(payload: unknown) {
  vi.stubGlobal("window", { setTimeout, clearTimeout });
  const fetcher = vi
    .fn()
    .mockResolvedValue(new Response(JSON.stringify(payload)));
  vi.stubGlobal("fetch", fetcher);
  return fetcher;
}

describe("bypass.tools catalog adapter", () => {
  it("uses the bridge and preserves WEAO attribution without copying sUNC into UNC", async () => {
    const fetcher = reply({
      fetchedAt: "2026-11-21T18:00:00Z",
      executors: [
        {
          id: 3,
          name: "Example",
          category: "Android Executors",
          status: "Not Working",
          price: "Free",
          features: "Free, Key System, Client Mod Warning, UNC, sUNC 96%",
          weao_synced: true,
          version: "2.731.944",
          rbx_version: "2.731.944",
          updated_at: "2026-10-27T00:47:15Z",
        },
      ],
    });
    const {
      records: [record],
    } = await fetchBypass("https://bridge.test");
    expect(fetcher).toHaveBeenCalledWith(
      "https://bridge.test/api/bypass/catalog",
      expect.any(Object),
    );
    expect(record).toMatchObject({
      source: "bypass",
      sourceId: "3",
      platforms: ["android"],
      working: false,
      detection: "unknown",
      type: "Internal",
      free: true,
      sunc: 96,
      unc: null,
      warning: true,
      upstreamSource: "weao",
      version: null,
      robloxVersion: "2.731.944",
      sourceUpdatedAt: "2026-10-27T00:47:15.000Z",
      fetchedAt: "2026-11-21T18:00:00.000Z",
    });
    expect(record.features).toContain("WEAO-synced");
  });

  it("keeps explicit zero percentages and detection separate from working status", async () => {
    reply([
      {
        name: "Example",
        category: "Windows External Exploits",
        status: "Working",
        features: "UNC 0%, sUNC 1000%",
        website_url: "javascript:bad()",
      },
    ]);
    const {
      records: [record],
    } = await fetchBypass("https://bridge.test");
    expect(record).toMatchObject({
      platforms: ["windows"],
      type: "External",
      working: true,
      detection: "unknown",
      unc: 0,
      sunc: null,
      sourceUpdatedAt: null,
    });
    expect(record.links.website).toBeUndefined();
  });

  it("recognizes an explicit detected status and an actual executor release", async () => {
    reply([
      {
        name: "Example",
        category: "Mac Executors",
        status: "Detected",
        version: "1.2.3",
        rbx_version: "version-target",
        features: "UNC 75%, sUNC 82%",
      },
    ]);
    const {
      records: [record],
    } = await fetchBypass("https://bridge.test");
    expect(record).toMatchObject({
      platforms: ["mac"],
      working: true,
      detection: "detected",
      version: "1.2.3",
      unc: 75,
      sunc: 82,
    });
    reply([
      {
        name: "Example",
        category: "Windows Executors",
        version: "version-older",
        rbx_version: "version-target",
      },
    ]);
    expect(
      (await fetchBypass("https://bridge.test")).records[0].version,
    ).toBeNull();
  });

  it("rejects malformed or empty catalog data", async () => {
    reply({ executors: [] });
    await expect(fetchBypass("https://bridge.test")).rejects.toThrow(
      "no usable executor records",
    );
    reply({ cheats: {} });
    await expect(fetchBypass("https://bridge.test")).rejects.toThrow();
  });
});
