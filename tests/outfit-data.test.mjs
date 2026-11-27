import { test } from "node:test";
import assert from "node:assert/strict";
import { getCommerceDisplay } from "../Others/OutfitSearch/src/commerce.js";
import {
  prepareDisplayAssets,
  splitOutfits,
} from "../Others/OutfitSearch/src/outfits.js";
import { normalizeRolimonsPayload } from "../Others/OutfitSearch/server/rolimons.js";
import worker from "../Others/OutfitSearch/worker.js";

test("commerce distinguishes free items, unknown zero prices and resale listings", () => {
  assert.equal(getCommerceDisplay({ price: 0, isForSale: true }).state, "free");
  assert.equal(getCommerceDisplay({ price: 0 }).state, "unknown-zero");
  assert.equal(
    getCommerceDisplay({ isLimited: true, isForSale: false, lowestPrice: 1250 })
      .label,
    "1,250 resale",
  );
  assert.equal(
    getCommerceDisplay({ isLimited: true, hasResellers: false }).state,
    "no-listings",
  );
  assert.equal(
    getCommerceDisplay({ name: "Content Deleted", price: 10 }).state,
    "unavailable",
  );
});

test("animation components collapse into their bundle while emotes remain visible", () => {
  const bundle = { id: 99, name: "Animation pack", price: 250 };
  const assets = [
    { id: 1, assetTypeName: "RunAnimation", parentBundle: bundle },
    { id: 2, assetTypeName: "WalkAnimation", parentBundle: bundle },
    { id: 3, assetTypeName: "EmoteAnimation" },
    { id: 4, assetTypeName: "IdleAnimation" },
  ];
  const display = prepareDisplayAssets(assets);
  assert.deepEqual(
    display.assets.map((asset) => asset.id),
    [1, 3],
  );
  assert.equal(display.groupedBundleComponents, 2);
  assert.equal(display.hiddenStandaloneAnimations, 1);
  assert.equal(
    prepareDisplayAssets(assets, { mode: "animationPack" }).assets.length,
    4,
  );
  assert.equal(
    splitOutfits([{ name: "Roblox Boy" }, { name: "Weekend outfit" }]).saved
      .length,
    1,
  );
});

test("Rolimons rows preserve missing values and item flags", () => {
  const item = normalizeRolimonsPayload({
    items: { 100: ["Item", "IT", 1500, -1, 1500, 3, 2, 1, 0, 1] },
  })[100];
  assert.equal(item.rap, 1500);
  assert.equal(item.value, null);
  assert.equal(item.projected, true);
  assert.equal(item.rare, true);
});

test("outfit Worker retains its fixed routes, CORS and validation without upstream requests", async () => {
  const request = (route, method = "GET") =>
    worker.fetch(
      new Request(`https://outfits.test${route}`, { method }),
      {},
      { waitUntil() {} },
    );
  const health = await request("/api/health");
  assert.equal(health.headers.get("access-control-allow-origin"), "*");
  assert.ok(health.headers.get("x-request-id"));
  assert.equal((await health.json()).providers.roblox.role, "primary");
  assert.equal((await request("/proxy?url=https://example.com")).status, 404);
  assert.equal((await request("/api/report/1", "POST")).status, 405);
  assert.equal((await request("/api/report/1", "OPTIONS")).status, 204);
});
