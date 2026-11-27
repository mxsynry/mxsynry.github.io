import { afterEach, describe, expect, it, vi } from "vitest";
import { initialUpdate, readSnapshot } from "./index";

afterEach(() => vi.unstubAllGlobals());

describe("catalog evidence cache migration", () => {
  it("does not reuse old normalized safety claims or invented source timestamps", () => {
    const legacy = JSON.stringify({
      version: 1,
      savedAt: new Date().toISOString(),
      results: {
        pulsery: {
          source: "pulsery",
          records: [{ name: "Legacy", detection: "undetected" }],
        },
      },
    });
    vi.stubGlobal("localStorage", {
      getItem: (key: string) =>
        key === "synchrose:source-snapshot:v1" ? legacy : null,
    });
    expect(initialUpdate(readSnapshot()).records).toEqual([]);
  });
  it("drops cached Inject reports when the catalog source set changes", () => {
    const legacy = JSON.stringify({
      version: 2,
      savedAt: new Date().toISOString(),
      results: {
        inject: { source: "inject", records: [{ name: "Retired source" }] },
      },
    });
    vi.stubGlobal("localStorage", {
      getItem: (key: string) =>
        key === "synchrose:source-snapshot:v2" ? legacy : null,
    });
    expect(readSnapshot()).toBeNull();
    expect(initialUpdate(readSnapshot()).health).toHaveProperty("bypass");
    expect(initialUpdate(readSnapshot()).health).not.toHaveProperty("inject");
  });
});
