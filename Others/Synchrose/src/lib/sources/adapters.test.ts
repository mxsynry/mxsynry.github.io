import { describe, expect, it, vi } from "vitest";
import { fetchInject } from "./inject";
import { fetchPulsery } from "./pulsery";
import { fetchVoxlis } from "./voxlis";
import { fetchWeao } from "./weao";

function jsonResponse(value: unknown): Response {
  return new Response(JSON.stringify(value), {
    status: 200,
    headers: { "content-type": "application/json" }
  });
}

describe("source adapters", () => {
  it("normalizes a WEAO status response and matches the current version", async () => {
    vi.stubGlobal("fetch", vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      return url.includes("/versions/")
        ? jsonResponse({ Windows: { version: " Roblox 1.0 " } })
        : jsonResponse([{
            title: "Example",
            platform: "Windows",
            updateStatus: true,
            rbxversion: "Roblox 1.0",
            cost: "Free",
            detected: false
          }]);
    }));

    const result = await fetchWeao("");

    expect(result.records).toHaveLength(1);
    expect(result.records[0]).toMatchObject({
      name: "Example",
      platforms: ["windows"],
      working: true,
      free: true,
      detection: "undetected"
    });
  });

  it("normalizes one Inject record per advertised platform", async () => {
    vi.stubGlobal("fetch", vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      return url.includes("/versions/")
        ? jsonResponse({ Windows: { version: "Roblox 1.0" } })
        : jsonResponse({ data: {
            Example: {
              Platforms: { Windows: { Versions: { Roblox: "Roblox 1.0", Software: "2.0" } } },
              Attributes: { Windows: { About: "A test record", Type: "External" } },
              Cost: { Windows: "Free" }
            }
          } });
    }));

    const result = await fetchInject("");

    expect(result.records).toHaveLength(1);
    expect(result.records[0]).toMatchObject({
      name: "Example",
      platforms: ["windows"],
      working: true,
      free: true,
      type: "External"
    });
  });

  it("normalizes a Pulsery status response", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => jsonResponse({ executors: [{
      id: "example",
      name: "Example",
      platforms: ["Windows"],
      is_working: true,
      is_detected: false,
      price_text: "Free",
      updated: "2026-09-01T00:00:00.000Z"
    }] })));

    const result = await fetchPulsery("https://worker.example");

    expect(result.records[0]).toMatchObject({
      source: "pulsery",
      name: "Example",
      platforms: ["windows"],
      working: true,
      free: true,
      detection: "undetected"
    });
  });

  it("joins Voxlis catalog entries with their price data", async () => {
    vi.stubGlobal("fetch", vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.endsWith("/prices")) return jsonResponse({ example: { offers: [{ price: 5, currency: "USD", days: -1 }] } });
      return jsonResponse({ folder: "example", info: { name: "Example", platform: "Windows" } });
    }));

    const result = await fetchVoxlis("https://worker.example");

    expect(result.records[0]).toMatchObject({
      source: "voxlis",
      name: "Example",
      platforms: ["windows"],
      price: "$5 lifetime",
      free: false
    });
  });
});
