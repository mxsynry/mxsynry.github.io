import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import captures from "./__fixtures__/har-catalogs.json";
import worker from "../../../../worker.js";
import { fetchVoxlis } from "./voxlis";
import { fetchBypass } from "./bypass";

beforeEach(() => {
  vi.stubGlobal("window", { setTimeout, clearTimeout });
  vi.stubGlobal("caches", {
    default: {
      match: vi.fn().mockResolvedValue(undefined),
      put: vi.fn().mockResolvedValue(undefined),
    },
  });
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url, init) => {
      if (url === "https://voxlis.net/api/directory/roblox")
        return new Response(JSON.stringify(captures.voxlis));
      if (url === "https://bypass.tools/api/executors")
        return new Response(JSON.stringify(captures.bypass));
      if (url.startsWith("https://bridge.test/api/"))
        return worker.fetch(
          new Request(url, init),
          {},
          { waitUntil: () => {} },
        );
      throw new Error(`Unexpected request ${url}`);
    }),
  );
});
afterEach(() => vi.unstubAllGlobals());

describe("sanitized public responses from the November 27 HARs", () => {
  it("loads all 19 Voxlis products and their 20 platform observations through the Worker", async () => {
    const result = await fetchVoxlis("https://bridge.test");
    expect(result.records).toHaveLength(20);
    expect(new Set(result.records.map((record) => record.name)).size).toBe(19);
    expect(
      result.records.filter((record) => record.working === false),
    ).toHaveLength(1);
    expect(
      result.records.every(
        (record) => record.fetchedAt && record.source === "voxlis",
      ),
    ).toBe(true);
    expect(result.records.some((record) => record.suncDetails?.testedAt)).toBe(
      true,
    );
    expect(result.records.some((record) => record.myriadDetails?.url)).toBe(
      true,
    );
  });

  it("loads all 40 bypass.tools records without forwarding captured key or scrap fields", async () => {
    const result = await fetchBypass("https://bridge.test");
    expect(result.records).toHaveLength(40);
    expect(
      result.records.filter((record) => record.working === true),
    ).toHaveLength(23);
    expect(
      result.records.filter((record) => record.working === false),
    ).toHaveLength(17);
    const payload = await (
      await worker.fetch(
        new Request("https://bridge.test/api/bypass/catalog"),
        {},
        { waitUntil: () => {} },
      )
    ).json();
    expect(JSON.stringify(payload)).not.toContain("sunc_key");
    expect(JSON.stringify(payload)).not.toContain("sunc_scrap");
  });
});
