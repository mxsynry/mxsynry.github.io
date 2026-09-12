import { describe, expect, it } from "vitest";
import { mergeSourceResults } from "./consensus";
import type { SourceId, SourceRecord, SourceResult } from "./domain";

function observation(source: SourceId, overrides: Partial<SourceRecord> = {}): SourceRecord {
  return {
    source, name: "Example X", platforms: ["windows"], working: true,
    detection: "undetected", version: "1.0", robloxVersion: null,
    price: "Free", free: true, sunc: 100, unc: null, type: "External",
    features: [], description: null, links: {}, warning: false,
    sourceUpdatedAt: null, fetchedAt: "2026-01-01T00:00:00.000Z", ...overrides
  };
}

function result(source: SourceId, records: SourceRecord[]): SourceResult {
  return { source, records, fetchedAt: "2026-01-01T00:00:00.000Z" };
}

describe("mergeSourceResults", () => {
  it("preserves observations while deriving a consensus", () => {
    const records = mergeSourceResults({
      weao: result("weao", [observation("weao")]),
      inject: result("inject", [observation("inject", { name: "Example-X" })])
    });
    expect(records).toHaveLength(1);
    expect(records[0]?.working).toBe("working");
    expect(records[0]?.sources).toEqual(["weao", "inject"]);
    expect(records[0]?.observations).toHaveLength(2);
  });

  it("exposes disagreements instead of selecting one source", () => {
    const [record] = mergeSourceResults({
      weao: result("weao", [observation("weao")]),
      pulsery: result("pulsery", [observation("pulsery", { working: false, detection: "detected", sunc: 82 })])
    });
    expect(record?.working).toBe("mixed");
    expect(record?.detection).toBe("mixed");
    expect(record?.sunc).toEqual({ min: 82, max: 100 });
    expect(record?.conflicts.map((conflict) => conflict.field)).toEqual(expect.arrayContaining(["working", "detection", "sunc"]));
  });
});
