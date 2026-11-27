import { afterEach, describe, expect, it, vi } from "vitest";
import { fetchVoxlis } from "./voxlis";

afterEach(() => vi.unstubAllGlobals());
function reply(payload: unknown) {
  vi.stubGlobal("window", { setTimeout, clearTimeout });
  const fetcher = vi
    .fn()
    .mockResolvedValue(new Response(JSON.stringify(payload)));
  vi.stubGlobal("fetch", fetcher);
  return fetcher;
}

describe("current Voxlis directory adapter", () => {
  it("uses one catalog request and keeps each platform's own status, build and score", async () => {
    const fetcher = reply({
      cards: [
        {
          slug: "example",
          title: "Example",
          sunc: { score: 99 },
          variants: [
            {
              id: "ios:executor",
              platform: "ios",
              type: "executor",
              status: "updated",
              version: "2.710.706",
              pricing: { access: "free", free: true },
              sunc: { score: 98 },
            },
            {
              id: "android:executor",
              platform: "android",
              type: "executor",
              status: "outdated",
              version: "2.721.1108",
              sunc: { score: 100 },
            },
            {
              id: "windows:external",
              platform: "windows",
              type: "external",
              status: "pending",
            },
          ],
        },
      ],
    });
    const result = await fetchVoxlis("https://bridge.test");
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(fetcher).toHaveBeenCalledWith(
      "https://bridge.test/api/voxlis/catalog",
      expect.any(Object),
    );
    expect(
      result.records.map((r) => [r.platforms[0], r.working, r.sunc]),
    ).toEqual([
      ["ios", true, 98],
      ["android", false, 100],
      ["windows", null, null],
    ]);
    expect(new Set(result.records.map((r) => r.sourceId)).size).toBe(3);
    expect(result.records[0]).toMatchObject({
      version: null,
      robloxVersion: "2.710.706",
      free: true,
      type: "Internal",
    });
    expect(result.records[2].type).toBe("External");
  });

  it("preserves audit category, historical builds and dates, inline review and source timestamps", async () => {
    reply({
      checkedAt: "2026-11-21T18:00:00Z",
      bridgeFetchedAt: "2026-11-21T18:01:00Z",
      stale: true,
      cards: [
        {
          slug: "example",
          title: "Example",
          keyed: false,
          variants: [
            {
              id: "windows:executor",
              platform: "windows",
              type: "executor",
              status: "updated",
              version: "version-target",
              pricing: { available: false, access: "free", free: false },
              review: "**Published** review.\n\nSecond paragraph.",
              sunc: {
                score: 59,
                metadata: {
                  version: "2.1.5",
                  executor: "Example/3.0",
                  testedAt: "2026-08-24T23:29:44Z",
                },
              },
              myriad: {
                audit: {
                  kind: "v",
                  rating: 100,
                  url: "https://myriad.tools/view/v/example",
                  executorVersion: "3.0",
                  generated: "2026-11-02T13:50:22Z",
                  checked: 158,
                  secured: 158,
                  vulnerable: 0,
                  ambiguous: 0,
                  excluded: 0,
                },
              },
            },
          ],
          updateHistory: [
            { platform: "windows", updatedAt: "2026-11-17T21:36:39Z" },
            { platform: "android", updatedAt: "2026-11-20T00:00:00Z" },
          ],
        },
      ],
    });
    const result = await fetchVoxlis("https://bridge.test");
    const [record] = result.records;
    expect(result.stale).toBe(true);
    expect(record).toMatchObject({
      working: true,
      free: true,
      price: "Free",
      version: null,
      robloxVersion: "version-target",
      myriad: 100,
      fetchedAt: "2026-11-21T18:01:00.000Z",
      sourceUpdatedAt: "2026-11-17T21:36:39.000Z",
      sourceCheckedAt: "2026-11-21T18:00:00.000Z",
      suncDetails: {
        suiteVersion: "2.1.5",
        executor: "Example/3.0",
        testedAt: "2026-08-24T23:29:44.000Z",
      },
      myriadDetails: {
        category: "vulnerabilities",
        executorVersion: "3.0",
        checked: 158,
        secured: 158,
        vulnerable: 0,
        ambiguous: 0,
        excluded: 0,
      },
    });
    expect(record.reviewNotes).toBe(
      "**Published** review.\n\nSecond paragraph.",
    );
  });

  it("does not fabricate benchmarks, update times, detection or unsafe links for external listings", async () => {
    reply({
      cards: [
        {
          slug: "external",
          title: "External",
          platform: "windows",
          type: "external",
          insecure: true,
          status: "updated",
          sunc: { score: null, label: "External" },
          websiteUrls: ["javascript:alert(1)"],
        },
      ],
    });
    const {
      records: [record],
    } = await fetchVoxlis("https://bridge.test");
    expect(record).toMatchObject({
      sunc: null,
      unc: null,
      myriad: null,
      sourceUpdatedAt: null,
      detection: "unknown",
      warning: true,
    });
    expect(record.links.website).toBeUndefined();
  });

  it("rejects the retired prices response instead of reporting an empty live source", async () => {
    reply({ freeProducts: ["example"] });
    await expect(fetchVoxlis("https://bridge.test")).rejects.toThrow();
  });
});
