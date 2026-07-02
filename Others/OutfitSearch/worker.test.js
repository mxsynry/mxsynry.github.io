import { describe, it, expect } from "vitest";
import {
  ASSET_TYPE_NAMES,
  normalizeAsset,
  mergeAssetDetails,
  normalizeBundle,
  isFallbackAssetName,
  pickAssetName,
  firstNumber,
  firstPositiveNumber,
  firstNonEmptyString,
  slugify,
  assertId,
  unique,
  uniqueBy,
  mapBy,
  chunks,
  duplicateCounts,
  thumbnailKind,
  errorPayload,
  extractEmotesFromPayload,
  chooseBestBundle,
  shouldResolveParentBundle,
  getAssetTypeName,
  mapSettledLimit,
} from "./worker.js";

describe("ASSET_TYPE_NAMES", () => {
  it("maps known type IDs correctly", () => {
    expect(ASSET_TYPE_NAMES[8]).toBe("Hat");
    expect(ASSET_TYPE_NAMES[11]).toBe("Shirt");
    expect(ASSET_TYPE_NAMES[12]).toBe("Pants");
    expect(ASSET_TYPE_NAMES[18]).toBe("Face");
    expect(ASSET_TYPE_NAMES[41]).toBe("Hair Accessory");
    expect(ASSET_TYPE_NAMES[61]).toBe("Emote Animation");
  });
});

describe("normalizeAsset", () => {
  it("extracts id from various fields", () => {
    expect(normalizeAsset({ id: 42 }).id).toBe(42);
    expect(normalizeAsset({ assetId: 42 }).id).toBe(42);
    expect(normalizeAsset({ Id: 42 }).id).toBe(42);
    expect(normalizeAsset({ AssetId: 42 }).id).toBe(42);
  });

  it("sets name from various fields", () => {
    expect(normalizeAsset({ id: 1, name: "Hat" }).name).toBe("Hat");
    expect(normalizeAsset({ id: 1, Name: "Hat" }).name).toBe("Hat");
    expect(normalizeAsset({ id: 1, assetName: "Hat" }).name).toBe("Hat");
  });

  it("falls back to Asset {id} when no name", () => {
    expect(normalizeAsset({ id: 42 }).name).toBe("Asset 42");
  });

  it("extracts creator info", () => {
    const result = normalizeAsset({ id: 1, creatorName: "Roblox", creatorId: 1 });
    expect(result.creatorName).toBe("Roblox");
    expect(result.creatorId).toBe(1);
  });

  it("extracts creator from nested creator object", () => {
    const result = normalizeAsset({ id: 1, creator: { name: "Bob", id: 5 } });
    expect(result.creatorName).toBe("Bob");
    expect(result.creatorId).toBe(5);
  });

  it("resolves assetType from type ID", () => {
    const result = normalizeAsset({ id: 1, assetTypeId: 8 });
    expect(result.assetTypeName).toBe("Hat");
  });

  it("resolves assetType from nested object", () => {
    const result = normalizeAsset({ id: 1, assetType: { name: "Face", id: 18 } });
    expect(result.assetTypeName).toBe("Face");
  });

  it("handles string assetType", () => {
    const result = normalizeAsset({ id: 1, assetType: "Shirt" });
    expect(result.assetTypeName).toBe("Shirt");
  });

  it("extracts price from various fields", () => {
    expect(normalizeAsset({ id: 1, price: 100 }).price).toBe(100);
    expect(normalizeAsset({ id: 1, priceInRobux: 200 }).price).toBe(200);
    expect(normalizeAsset({ id: 1, Price: 300 }).price).toBe(300);
  });

  it("extracts lowestPrice (positive only)", () => {
    expect(normalizeAsset({ id: 1, lowestPrice: 50 }).lowestPrice).toBe(50);
    expect(normalizeAsset({ id: 1, lowestPrice: 0 }).lowestPrice).toBeNull();
    expect(normalizeAsset({ id: 1, lowestPrice: -1 }).lowestPrice).toBeNull();
  });

  it("detects limited items", () => {
    expect(normalizeAsset({ id: 1, isLimited: true }).isLimited).toBe(true);
    expect(normalizeAsset({ id: 1, itemRestrictions: ["Limited"] }).isLimited).toBe(true);
    expect(normalizeAsset({ id: 1, collectibleItemId: "abc" }).isLimited).toBe(true);
  });

  it("detects free items by price", () => {
    expect(normalizeAsset({ id: 1, price: 0 }).isFree).toBe(true);
    expect(normalizeAsset({ id: 1, priceStatus: "Free" }).isFree).toBe(true);
    expect(normalizeAsset({ id: 1, price: 100 }).isFree).toBe(false);
  });

  it("preserves parentBundle and purchasable fields", () => {
    const bundle = { id: 10 };
    const result = normalizeAsset({ id: 1, parentBundle: bundle, purchasableType: "Bundle" });
    expect(result.parentBundle).toEqual(bundle);
    expect(result.purchasableType).toBe("Bundle");
  });
});

describe("mergeAssetDetails", () => {
  it("merges two asset detail objects", () => {
    const base = { id: 1, name: "Hat", price: 100 };
    const extra = { id: 1, creatorName: "Roblox" };
    const result = mergeAssetDetails(base, extra);
    expect(result.id).toBe(1);
    expect(result.name).toBe("Hat");
    expect(result.price).toBe(100);
    expect(result.creatorName).toBe("Roblox");
  });

  it("prefers non-fallback name from extra", () => {
    const base = { id: 1, name: "Asset 1" };
    const extra = { id: 1, name: "Cool Hat" };
    const result = mergeAssetDetails(base, extra);
    expect(result.name).toBe("Cool Hat");
  });

  it("keeps base name when extra name is a fallback", () => {
    const base = { id: 1, name: "Cool Hat" };
    const extra = { id: 1, name: "Asset 1" };
    const result = mergeAssetDetails(base, extra);
    expect(result.name).toBe("Cool Hat");
  });

  it("prefers extra price using nullish coalescing", () => {
    const base = { id: 1, price: 100 };
    const extra = { id: 1, price: 200 };
    expect(mergeAssetDetails(base, extra).price).toBe(200);
  });

  it("falls back to base price when extra is null", () => {
    const base = { id: 1, price: 100 };
    const extra = { id: 1, price: null };
    expect(mergeAssetDetails(base, extra).price).toBe(100);
  });

  it("merges collectible fields", () => {
    const base = { id: 1, collectibleItemId: "abc" };
    const extra = { id: 1 };
    expect(mergeAssetDetails(base, extra).collectibleItemId).toBe("abc");
  });

  it("resolves best asset type name", () => {
    const base = { id: 1 };
    const extra = { id: 1, assetType: { name: "Hat", id: 8 } };
    expect(mergeAssetDetails(base, extra).assetTypeName).toBe("Hat");
  });
});

describe("normalizeBundle", () => {
  it("normalizes a full bundle payload", () => {
    const bundle = {
      id: 100,
      name: "Walk Pack",
      bundleType: "BodyParts",
      creator: { name: "Roblox", id: 1 },
      product: { priceInRobux: 75, id: 999 },
      description: "A bundle",
    };
    const result = normalizeBundle(bundle);
    expect(result.id).toBe(100);
    expect(result.name).toBe("Walk Pack");
    expect(result.creatorName).toBe("Roblox");
    expect(result.price).toBe(75);
    expect(result.productId).toBe(999);
    expect(result.url).toContain("/bundles/100/walk-pack");
    expect(result.detailsSource).toBe("bundle-details");
  });

  it("handles missing fields gracefully", () => {
    const result = normalizeBundle({ id: 1 });
    expect(result.id).toBe(1);
    expect(result.name).toBe("Bundle 1");
    expect(result.creatorName).toBeNull();
    expect(result.price).toBeNull();
    expect(result.isFree).toBe(false);
  });

  it("detects free bundles by price 0", () => {
    const result = normalizeBundle({ id: 1, price: 0 });
    expect(result.isFree).toBe(true);
  });
});

describe("isFallbackAssetName (worker)", () => {
  it("returns true for empty/null/undefined", () => {
    expect(isFallbackAssetName("", 1)).toBe(true);
    expect(isFallbackAssetName(null, 1)).toBe(true);
    expect(isFallbackAssetName(undefined, 1)).toBe(true);
  });

  it('returns true for bare "Asset"', () => {
    expect(isFallbackAssetName("Asset", 1)).toBe(true);
    expect(isFallbackAssetName("asset", 1)).toBe(true);
  });

  it('returns true for "Asset {id}"', () => {
    expect(isFallbackAssetName("Asset 42", 42)).toBe(true);
  });

  it("returns false for real names", () => {
    expect(isFallbackAssetName("Cool Hat", 1)).toBe(false);
  });
});

describe("pickAssetName", () => {
  it("picks first non-fallback name", () => {
    expect(pickAssetName(1, { name: "Asset 1" }, { name: "Cool Hat" })).toBe("Cool Hat");
  });

  it("falls back to Asset {id}", () => {
    expect(pickAssetName(42, { name: "Asset 42" }, {})).toBe("Asset 42");
  });

  it("picks from first item when it has real name", () => {
    expect(pickAssetName(1, { name: "First" }, { name: "Second" })).toBe("First");
  });
});

describe("firstNumber", () => {
  it("returns the first finite number", () => {
    expect(firstNumber(undefined, null, "", 42)).toBe(42);
  });

  it("returns null when no valid number found", () => {
    expect(firstNumber(undefined, null, "")).toBeNull();
  });

  it("accepts 0", () => {
    expect(firstNumber(0, 5)).toBe(0);
  });

  it("skips NaN", () => {
    expect(firstNumber("abc", 42)).toBe(42);
  });

  it("skips Infinity", () => {
    expect(firstNumber(Infinity, 42)).toBe(42);
  });
});

describe("firstPositiveNumber", () => {
  it("returns the first positive finite number", () => {
    expect(firstPositiveNumber(undefined, 0, -1, 42)).toBe(42);
  });

  it("skips zero", () => {
    expect(firstPositiveNumber(0, 5)).toBe(5);
  });

  it("returns null when none found", () => {
    expect(firstPositiveNumber(0, -1, null)).toBeNull();
  });
});

describe("firstNonEmptyString", () => {
  it("returns first non-empty trimmed string", () => {
    expect(firstNonEmptyString(null, "", "  ", "hello")).toBe("hello");
  });

  it("returns empty string when none found", () => {
    expect(firstNonEmptyString(null, undefined, "")).toBe("");
  });

  it("trims the result", () => {
    expect(firstNonEmptyString("  hello  ")).toBe("hello");
  });
});

describe("slugify", () => {
  it("lowercases and replaces non-alphanumeric with hyphens", () => {
    expect(slugify("Walk Pack")).toBe("walk-pack");
    expect(slugify("Cool Hat!")).toBe("cool-hat");
  });

  it("strips leading/trailing hyphens", () => {
    expect(slugify("--hello--")).toBe("hello");
  });

  it('defaults to "bundle" for empty input', () => {
    expect(slugify("")).toBe("bundle");
    expect(slugify(null)).toBe("bundle");
  });

  it("handles special characters", () => {
    expect(slugify("ÜberCool @ Test")).toBe("bercool-test");
  });
});

describe("assertId", () => {
  it("throws for non-integer", () => {
    expect(() => assertId(1.5)).toThrow("Invalid");
  });

  it("throws for zero", () => {
    expect(() => assertId(0)).toThrow("Invalid");
  });

  it("throws for negative", () => {
    expect(() => assertId(-1)).toThrow("Invalid");
  });

  it("throws for non-finite", () => {
    expect(() => assertId(NaN)).toThrow("Invalid");
    expect(() => assertId(Infinity)).toThrow("Invalid");
  });

  it("does not throw for valid positive integer", () => {
    expect(() => assertId(1)).not.toThrow();
    expect(() => assertId(999999)).not.toThrow();
  });

  it("includes custom label in error message", () => {
    expect(() => assertId(-1, "user ID")).toThrow("Invalid user ID");
  });

  it("sets error status to 400", () => {
    try {
      assertId(0);
    } catch (err) {
      expect(err.status).toBe(400);
    }
  });
});

describe("unique", () => {
  it("deduplicates and filters non-finite values", () => {
    expect(unique([1, 2, 2, 3, NaN, Infinity])).toEqual([1, 2, 3]);
  });

  it("handles empty array", () => {
    expect(unique([])).toEqual([]);
  });
});

describe("uniqueBy (worker)", () => {
  it("deduplicates by key function", () => {
    expect(uniqueBy([{ id: 1 }, { id: 2 }, { id: 1 }], x => x.id)).toHaveLength(2);
  });

  it("filters out null/undefined keys", () => {
    expect(uniqueBy([{ id: null }, { id: 1 }], x => x.id)).toHaveLength(1);
  });
});

describe("mapBy", () => {
  it("creates a map from array using key function", () => {
    const items = [{ id: 1, name: "a" }, { id: 2, name: "b" }];
    const result = mapBy(items, x => x.id);
    expect(result[1]).toEqual({ id: 1, name: "a" });
    expect(result[2]).toEqual({ id: 2, name: "b" });
  });

  it("later items overwrite earlier for same key", () => {
    const items = [{ id: 1, name: "first" }, { id: 1, name: "second" }];
    const result = mapBy(items, x => x.id);
    expect(result[1].name).toBe("second");
  });

  it("skips null/undefined keys", () => {
    const result = mapBy([{ id: null }], x => x.id);
    expect(Object.keys(result)).toHaveLength(0);
  });
});

describe("chunks", () => {
  it("splits array into chunks of given size", () => {
    expect(chunks([1, 2, 3, 4, 5], 2)).toEqual([[1, 2], [3, 4], [5]]);
  });

  it("returns single chunk for small arrays", () => {
    expect(chunks([1, 2], 5)).toEqual([[1, 2]]);
  });

  it("handles empty array", () => {
    expect(chunks([], 3)).toEqual([]);
  });
});

describe("duplicateCounts", () => {
  it("identifies duplicate values and their counts", () => {
    expect(duplicateCounts([1, 2, 2, 3, 3, 3])).toEqual([
      { id: 2, count: 2 },
      { id: 3, count: 3 },
    ]);
  });

  it("returns empty for no duplicates", () => {
    expect(duplicateCounts([1, 2, 3])).toEqual([]);
  });

  it("handles empty array", () => {
    expect(duplicateCounts([])).toEqual([]);
  });
});

describe("thumbnailKind", () => {
  it("extracts kind from thumbnail URL pattern", () => {
    expect(thumbnailKind("https://tr.rbxcdn.com/123/456/Avatar/Png")).toBe("Avatar");
    expect(thumbnailKind("https://tr.rbxcdn.com/123/456/DynamicHeadCostume/Png")).toBe("DynamicHeadCostume");
  });

  it("returns null for non-matching URLs", () => {
    expect(thumbnailKind("https://example.com/image.png")).toBeNull();
    expect(thumbnailKind("")).toBeNull();
    expect(thumbnailKind(null)).toBeNull();
  });
});

describe("errorPayload", () => {
  it("formats error into a payload object", () => {
    const err = new Error("something broke");
    err.status = 502;
    const result = errorPayload(err, "test");
    expect(result.ok).toBe(false);
    expect(result.error).toBe("something broke");
    expect(result.status).toBe(502);
    expect(result.where).toBe("test");
    expect(result.fetchedAt).toBeDefined();
  });

  it("handles string errors", () => {
    const result = errorPayload("simple error");
    expect(result.error).toBe("simple error");
    expect(result.status).toBe(500);
  });

  it("includes details when present", () => {
    const err = new Error("fail");
    err.details = { code: "E001" };
    const result = errorPayload(err);
    expect(result.details).toEqual({ code: "E001" });
  });
});

describe("extractEmotesFromPayload", () => {
  it("extracts emotes from an array", () => {
    const payload = { emotes: [{ id: 1 }, { id: 2 }] };
    const result = extractEmotesFromPayload(payload);
    expect(result).toHaveLength(2);
    expect(result[0].id).toBe(1);
    expect(result[0].itemType).toBe("Emote");
  });

  it("extracts from numeric values", () => {
    const payload = { emotes: [100, 200] };
    const result = extractEmotesFromPayload(payload);
    expect(result).toHaveLength(2);
    expect(result[0].id).toBe(100);
  });

  it("extracts from object-style emotes with slots", () => {
    const payload = { emotes: { "1": { id: 10 }, "2": { id: 20 } } };
    const result = extractEmotesFromPayload(payload);
    expect(result).toHaveLength(2);
  });

  it("deduplicates by id", () => {
    const payload = { emotes: [{ id: 1 }, { id: 1 }] };
    const result = extractEmotesFromPayload(payload);
    expect(result).toHaveLength(1);
  });

  it("returns empty array for empty payload", () => {
    expect(extractEmotesFromPayload({})).toEqual([]);
    expect(extractEmotesFromPayload()).toEqual([]);
  });

  it("checks multiple candidate keys", () => {
    const payload = { equippedEmotes: [{ id: 5 }] };
    const result = extractEmotesFromPayload(payload);
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(5);
  });
});

describe("chooseBestBundle", () => {
  it("returns null for empty list", () => {
    expect(chooseBestBundle([])).toBeNull();
  });

  it("prefers bundles matching animation/body keywords", () => {
    const bundles = [
      { id: 1, name: "Random", bundleType: "Outfit" },
      { id: 2, name: "Walk Animation Pack", bundleType: "AvatarAnimations" },
    ];
    const result = chooseBestBundle(bundles);
    expect(result.id).toBe(2);
  });

  it("falls back to first bundle when no keyword match", () => {
    const bundles = [
      { id: 1, name: "First" },
      { id: 2, name: "Second" },
    ];
    expect(chooseBestBundle(bundles).id).toBe(1);
  });
});

describe("shouldResolveParentBundle", () => {
  it("returns true when item is null", () => {
    expect(shouldResolveParentBundle(null, 1)).toBe(true);
  });

  it("returns false when item already has parentBundle", () => {
    expect(shouldResolveParentBundle({ parentBundle: { id: 10 } }, 1)).toBe(false);
  });

  it("returns false when purchasableType is Bundle", () => {
    expect(shouldResolveParentBundle({ purchasableType: "Bundle" }, 1)).toBe(false);
  });

  it("returns true for animation type assets", () => {
    expect(shouldResolveParentBundle({ assetTypeName: "IdleAnimation" }, 1)).toBe(true);
    expect(shouldResolveParentBundle({ assetTypeName: "WalkAnimation" }, 1)).toBe(true);
  });

  it("returns true for body part types", () => {
    expect(shouldResolveParentBundle({ assetType: { name: "Torso" } }, 1)).toBe(true);
    expect(shouldResolveParentBundle({ assetType: { name: "Right Arm" } }, 1)).toBe(true);
  });

  it("returns true for names with bundle keywords", () => {
    expect(shouldResolveParentBundle({ name: "Animation Pack X" }, 1)).toBe(true);
    expect(shouldResolveParentBundle({ name: "Dynamic Head Cool" }, 1)).toBe(true);
  });

  it("returns false for normal items", () => {
    expect(shouldResolveParentBundle({ name: "Cool Hat", assetTypeName: "Hat" }, 1)).toBe(false);
  });
});

describe("getAssetTypeName", () => {
  it("returns from assetType.name", () => {
    expect(getAssetTypeName({ assetType: { name: "Hat" } })).toBe("Hat");
  });

  it("returns from assetTypeName", () => {
    expect(getAssetTypeName({ assetTypeName: "Face" })).toBe("Face");
  });

  it("resolves from type ID lookup", () => {
    expect(getAssetTypeName({ assetTypeId: 8 })).toBe("Hat");
    expect(getAssetTypeName({ assetType: { id: 18 } })).toBe("Face");
  });

  it("handles string assetType", () => {
    expect(getAssetTypeName({ assetType: "Shirt" })).toBe("Shirt");
  });

  it("returns null when nothing available", () => {
    expect(getAssetTypeName({})).toBeNull();
  });
});

describe("mapSettledLimit", () => {
  it("processes items with concurrency limit", async () => {
    const items = [1, 2, 3, 4, 5];
    const results = await mapSettledLimit(items, 2, async (x) => x * 2);
    expect(results).toHaveLength(5);
    expect(results.every(r => r.status === "fulfilled")).toBe(true);
    expect(results.map(r => r.value)).toEqual([2, 4, 6, 8, 10]);
  });

  it("captures rejections without stopping", async () => {
    const items = [1, 2, 3];
    const results = await mapSettledLimit(items, 2, async (x) => {
      if (x === 2) throw new Error("fail");
      return x;
    });
    expect(results[0]).toEqual({ status: "fulfilled", value: 1 });
    expect(results[1].status).toBe("rejected");
    expect(results[1].reason.message).toBe("fail");
    expect(results[2]).toEqual({ status: "fulfilled", value: 3 });
  });

  it("handles empty input", async () => {
    const results = await mapSettledLimit([], 2, async (x) => x);
    expect(results).toEqual([]);
  });

  it("handles null input", async () => {
    const results = await mapSettledLimit(null, 2, async (x) => x);
    expect(results).toEqual([]);
  });
});
