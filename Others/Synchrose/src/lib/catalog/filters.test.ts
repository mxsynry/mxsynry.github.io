import { describe, expect, it, vi, afterEach } from "vitest";
import { fetchPulsery } from "./sources/pulsery";
import { filterCatalog } from "./index";
import { mergeSourceResults } from "./merge";
import { normalizeDetection } from "../format";
import type { CatalogFilters } from "./model";
const filters: CatalogFilters = {
  search: "",
  platform: "all",
  working: "all",
  detection: "all",
  price: "all",
  source: "all",
  feature: "all",
  sort: "status",
  type: "all",
  key: "all",
  sunc: "all",
};
afterEach(() => vi.unstubAllGlobals());
describe("catalog filters and compatibility values", () => {
  it("keeps the Pulsery ID, rating and score fields through the adapter and merge", async () => {
    vi.stubGlobal("window", { setTimeout, clearTimeout });
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            executors: [
              {
                id: "executor-42",
                name: "Example",
                is_working: true,
                rating: 4.25,
                review_count: 12,
                stability_score: 95,
                myriad_score: 87,
                sunc_percent: "82",
                platforms: ["Windows"],
                type: "External",
              },
            ],
          }),
        ),
      ),
    );
    const result = await fetchPulsery("https://example.test");
    const record = mergeSourceResults({ pulsery: result })[0];
    expect(record.observations[0]).toMatchObject({
      sourceId: "executor-42",
      rating: 4.25,
      reviewCount: 12,
      stability: 95,
      myriad: 87,
    });
    expect(filterCatalog([record], { ...filters, sunc: "80" })).toHaveLength(1);
    expect(filterCatalog([record], { ...filters, sunc: "100" })).toHaveLength(
      0,
    );
    expect(
      filterCatalog([record], { ...filters, key: "keyless" }),
    ).toHaveLength(0);
    expect(
      filterCatalog([record], { ...filters, type: "Internal" }),
    ).toHaveLength(0);
    record.features = ["Verified", "Trending", "RakNet", "Decompiler"];
    record.warning = true;
    record.observations[0].inviteOnly = true;
    expect(
      filterCatalog([record], {
        ...filters,
        tags: ["RakNet", "Decompiler"],
        verified: true,
        trending: true,
      }),
    ).toHaveLength(1);
    expect(
      filterCatalog([record], { ...filters, tags: ["RakNet", "Kernel"] }),
    ).toHaveLength(0);
    expect(
      filterCatalog([record], { ...filters, platforms: ["mac", "windows"] }),
    ).toHaveLength(1);
    expect(
      filterCatalog([record], { ...filters, showInviteOnly: false }),
    ).toHaveLength(0);
    expect(
      filterCatalog([record], { ...filters, showInsecure: false }),
    ).toHaveLength(0);
    expect(filterCatalog([record], { ...filters, warning: true })).toHaveLength(
      1,
    );
  });
  it("keeps software safety labels separate from detection claims", () => {
    expect(normalizeDetection("unsafe")).toBe("unknown");
    expect(normalizeDetection("safe")).toBe("unknown");
    expect(normalizeDetection("malware-free")).toBe("unknown");
    expect(normalizeDetection("undetected")).toBe("undetected");
    expect(normalizeDetection("detected")).toBe("detected");
    expect(normalizeDetection(true)).toBe("detected");
    expect(normalizeDetection(false)).toBe("undetected");
  });
  it("excludes impossible compatibility percentages while preserving zero and full scores", async () => {
    vi.stubGlobal("window", { setTimeout, clearTimeout });
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            executors: [
              { name: "Invalid", sunc_percent: "1000", unc_percent: -1 },
              { name: "Boundaries", sunc_percent: 0, unc_percent: "100%" },
            ],
          }),
        ),
      ),
    );
    const result = await fetchPulsery("https://example.test");
    const records = mergeSourceResults({ pulsery: result });
    expect(records.find((r) => r.name === "Invalid")?.sunc).toBeNull();
    expect(
      records.find((r) => r.name === "Invalid")?.observations[0].unc,
    ).toBeNull();
    expect(records.find((r) => r.name === "Boundaries")?.sunc).toEqual({
      min: 0,
      max: 0,
    });
    expect(
      records.find((r) => r.name === "Boundaries")?.observations[0].unc,
    ).toBe(100);
    expect(filterCatalog(records, { ...filters, sunc: "100" })).toHaveLength(0);
  });
});
