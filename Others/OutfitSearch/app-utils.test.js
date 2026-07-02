import { describe, it, expect } from "vitest";
import {
  hasConfiguredApi,
  isFallbackAssetName,
  uniqueBy,
  formatDate,
  cleanError,
  escapeHtml,
  escapeAttr,
  formatPrice,
  normalizeName,
  classifyOutfitEntry,
  splitOutfits,
  getAssetTypeText,
  fallbackAssetLabel,
  getShortTypeLabel,
  shouldGroupAsBundle,
  prepareDisplayAssets,
  makeBundleDisplayAsset,
  compactForLog,
  summarizeApiData,
  collectParamValues,
  splitParamList,
  looksLikeGithub404,
  getDisplayItem,
  formatLogLine,
} from "./app-utils.js";

describe("hasConfiguredApi", () => {
  const DEFAULT = "https://YOUR-WORKER.workers.dev";

  it("returns false when apiBase equals default", () => {
    expect(hasConfiguredApi(DEFAULT, DEFAULT)).toBe(false);
  });

  it("returns false when apiBase is empty", () => {
    expect(hasConfiguredApi("", DEFAULT)).toBeFalsy();
  });

  it("returns true when apiBase differs from default", () => {
    expect(hasConfiguredApi("https://my-worker.example.workers.dev", DEFAULT)).toBe(true);
  });
});

describe("isFallbackAssetName", () => {
  it("returns true for empty/null/undefined names", () => {
    expect(isFallbackAssetName("", 1)).toBe(true);
    expect(isFallbackAssetName(null, 1)).toBe(true);
    expect(isFallbackAssetName(undefined, 1)).toBe(true);
  });

  it('returns true for bare "asset" (case-insensitive)', () => {
    expect(isFallbackAssetName("asset", 1)).toBe(true);
    expect(isFallbackAssetName("Asset", 1)).toBe(true);
    expect(isFallbackAssetName("ASSET", 1)).toBe(true);
  });

  it('returns true for "Asset <number>" pattern', () => {
    expect(isFallbackAssetName("Asset 123", 123)).toBe(true);
    expect(isFallbackAssetName("asset 456", 789)).toBe(true);
  });

  it("returns false for real names", () => {
    expect(isFallbackAssetName("Cool Hat", 1)).toBe(false);
    expect(isFallbackAssetName("My Outfit", 42)).toBe(false);
  });

  it("returns true when name matches Asset {id} exactly", () => {
    expect(isFallbackAssetName("Asset 42", 42)).toBe(true);
  });

  it("returns false when name is Asset {different id}", () => {
    expect(isFallbackAssetName("Asset 42", 99)).toBe(true); // matches generic "asset <number>" pattern
  });
});

describe("uniqueBy", () => {
  it("deduplicates by key function", () => {
    const items = [{ id: 1 }, { id: 2 }, { id: 1 }, { id: 3 }];
    expect(uniqueBy(items, x => x.id)).toEqual([{ id: 1 }, { id: 2 }, { id: 3 }]);
  });

  it("keeps first occurrence", () => {
    const items = [{ id: 1, name: "first" }, { id: 1, name: "second" }];
    expect(uniqueBy(items, x => x.id)).toEqual([{ id: 1, name: "first" }]);
  });

  it("filters out null/undefined keys", () => {
    const items = [{ id: null }, { id: 1 }, { id: undefined }];
    expect(uniqueBy(items, x => x.id)).toEqual([{ id: 1 }]);
  });

  it("handles empty arrays", () => {
    expect(uniqueBy([], x => x)).toEqual([]);
  });
});

describe("formatDate", () => {
  it('returns "unknown" for falsy values', () => {
    expect(formatDate(null)).toBe("unknown");
    expect(formatDate("")).toBe("unknown");
    expect(formatDate(undefined)).toBe("unknown");
  });

  it('returns "unknown" for invalid dates', () => {
    expect(formatDate("not a date")).toBe("unknown");
  });

  it("formats a valid ISO date string", () => {
    const result = formatDate("2023-06-15T00:00:00Z");
    expect(result).toContain("2023");
    expect(result).toContain("15");
  });
});

describe("cleanError", () => {
  it("extracts message from error objects", () => {
    expect(cleanError(new Error("something failed"))).toBe("something failed");
  });

  it("strips HTML tags", () => {
    expect(cleanError({ message: "error <b>bold</b> text" })).toBe("error bold text");
  });

  it("truncates long messages to 260 chars", () => {
    const long = "a".repeat(300);
    const result = cleanError({ message: long });
    expect(result.length).toBeLessThanOrEqual(261); // 260 + ellipsis
    expect(result.endsWith("…")).toBe(true);
  });

  it("handles string input", () => {
    expect(cleanError("raw error string")).toBe("raw error string");
  });

  it("collapses whitespace", () => {
    expect(cleanError({ message: "multiple   spaces\n\nnewlines" })).toBe("multiple spaces newlines");
  });
});

describe("escapeHtml", () => {
  it("escapes all special characters", () => {
    expect(escapeHtml('&<>\'"')).toBe("&amp;&lt;&gt;&#39;&quot;");
  });

  it("handles null/undefined", () => {
    expect(escapeHtml(null)).toBe("");
    expect(escapeHtml(undefined)).toBe("");
  });

  it("leaves safe strings unchanged", () => {
    expect(escapeHtml("hello world")).toBe("hello world");
  });
});

describe("escapeAttr", () => {
  it("escapes HTML chars and backticks", () => {
    expect(escapeAttr("`test`")).toBe("&#96;test&#96;");
    expect(escapeAttr("<b>")).toBe("&lt;b&gt;");
  });
});

describe("formatPrice", () => {
  it("returns price in Robux for a numeric price", () => {
    expect(formatPrice({ price: 100 })).toBe("100 Robux");
  });

  it('returns "Free" for price 0', () => {
    expect(formatPrice({ price: 0 })).toBe("Free");
  });

  it("returns lowest price with + suffix", () => {
    expect(formatPrice({ lowestPrice: 50 })).toBe("50 Robux+");
  });

  it('returns "Free" for free priceStatus', () => {
    expect(formatPrice({ priceStatus: "Free" })).toBe("Free");
  });

  it('returns "Off sale" for off-sale items', () => {
    expect(formatPrice({ isForSale: false })).toBe("Off sale");
    expect(formatPrice({ priceStatus: "Off Sale" })).toBe("Off sale");
  });

  it('returns "Limited / no listings" for limited items', () => {
    expect(formatPrice({ isLimited: true })).toBe("Limited / no listings");
    expect(formatPrice({ collectibleItemId: "abc" })).toBe("Limited / no listings");
  });

  it('returns "Price unavailable" as fallback', () => {
    expect(formatPrice({})).toBe("Price unavailable");
  });

  it("prefers parentBundle price over item price", () => {
    expect(formatPrice({ parentBundle: { price: 200 }, price: 100 })).toBe("200 Robux");
  });

  it("returns priceStatus string when not off-sale or free", () => {
    expect(formatPrice({ priceStatus: "Premium Only" })).toBe("Premium Only");
  });
});

describe("normalizeName", () => {
  it("trims and collapses whitespace", () => {
    expect(normalizeName("  hello   world  ")).toBe("hello world");
  });

  it("handles falsy input", () => {
    expect(normalizeName("")).toBe("");
    expect(normalizeName(null)).toBe("");
    expect(normalizeName(undefined)).toBe("");
  });
});

describe("classifyOutfitEntry", () => {
  it('returns "saved" for normal outfits', () => {
    expect(classifyOutfitEntry({ name: "My Cool Outfit" })).toBe("saved");
  });

  it('returns "costume" for costume-type entries', () => {
    expect(classifyOutfitEntry({ name: "Something", imageKind: "DynamicHeadCostume" })).toBe("costume");
    expect(classifyOutfitEntry({ name: "Costume Preset" })).toBe("costume");
  });

  it('returns "animation" for animation packs', () => {
    expect(classifyOutfitEntry({ name: "Robot Animation Pack" })).toBe("animation");
    expect(classifyOutfitEntry({ name: "Rthro Animation Package" })).toBe("animation");
  });

  it('returns "package" for known character packages', () => {
    expect(classifyOutfitEntry({ name: "Roblox Girl" })).toBe("package");
    expect(classifyOutfitEntry({ name: "Man" })).toBe("package");
    expect(classifyOutfitEntry({ name: "City Life Woman" })).toBe("package");
  });

  it('returns "package" for items with package/bundle/character in name', () => {
    expect(classifyOutfitEntry({ name: "Cool Character Set" })).toBe("package");
    expect(classifyOutfitEntry({ name: "My Bundle" })).toBe("package");
  });

  it('returns "saved" for items with "outfit" in name even with package keywords', () => {
    expect(classifyOutfitEntry({ name: "Outfit Package" })).toBe("saved");
  });
});

describe("splitOutfits", () => {
  it("categorizes outfits correctly", () => {
    const outfits = [
      { name: "Normal Outfit" },
      { name: "DynamicHeadCostume Thing", imageKind: "DynamicHeadCostume" },
      { name: "Robot Animation Pack" },
      { name: "Roblox Girl" },
    ];
    const result = splitOutfits(outfits);
    expect(result.saved).toHaveLength(1);
    expect(result.costumeLike).toHaveLength(1);
    expect(result.animationPacks).toHaveLength(1);
    expect(result.characterPackages).toHaveLength(1);
  });

  it("returns empty arrays for empty input", () => {
    const result = splitOutfits([]);
    expect(result.saved).toHaveLength(0);
    expect(result.costumeLike).toHaveLength(0);
    expect(result.animationPacks).toHaveLength(0);
    expect(result.characterPackages).toHaveLength(0);
  });
});

describe("getAssetTypeText", () => {
  it("returns assetType.name when available", () => {
    expect(getAssetTypeText({ assetType: { name: "Hat" } })).toBe("Hat");
  });

  it("falls back to assetTypeName", () => {
    expect(getAssetTypeText({ assetTypeName: "Face" })).toBe("Face");
  });

  it("falls back to itemType", () => {
    expect(getAssetTypeText({ itemType: "Emote" })).toBe("Emote");
  });

  it('defaults to "Asset"', () => {
    expect(getAssetTypeText({})).toBe("Asset");
  });
});

describe("fallbackAssetLabel", () => {
  it("returns type-specific label when type is known", () => {
    expect(fallbackAssetLabel({ assetTypeName: "Hat" }, 42)).toBe("Hat #42");
  });

  it("returns generic Asset label when no type", () => {
    expect(fallbackAssetLabel({}, 42)).toBe("Asset #42");
  });
});

describe("getShortTypeLabel", () => {
  it("normalizes Accessory suffix", () => {
    expect(getShortTypeLabel({ assetTypeName: "Hair Accessory" })).toBe("Hair Accessory");
  });

  it("normalizes Animation suffix", () => {
    expect(getShortTypeLabel({ assetTypeName: "Idle Animation" })).toBe("Idle Animation");
  });

  it('defaults to "Asset"', () => {
    expect(getShortTypeLabel({})).toBe("Asset");
  });
});

describe("shouldGroupAsBundle", () => {
  it("returns true for body-part types", () => {
    expect(shouldGroupAsBundle({ assetTypeName: "Torso" })).toBe(true);
    expect(shouldGroupAsBundle({ assetTypeName: "Right Arm" })).toBe(true);
    expect(shouldGroupAsBundle({ assetTypeName: "Left Leg" })).toBe(true);
    expect(shouldGroupAsBundle({ assetTypeName: "Head" })).toBe(true);
  });

  it("returns true for DynamicHead type", () => {
    expect(shouldGroupAsBundle({ assetTypeName: "DynamicHead" })).toBe(true);
  });

  it("returns true for names containing bundle keywords", () => {
    expect(shouldGroupAsBundle({ name: "My Animation Pack" })).toBe(true);
    expect(shouldGroupAsBundle({ name: "Cool Bundle" })).toBe(true);
    expect(shouldGroupAsBundle({ name: "Dynamic Head Face" })).toBe(true);
  });

  it("returns false for normal items", () => {
    expect(shouldGroupAsBundle({ assetTypeName: "Hat", name: "Cool Hat" })).toBe(false);
  });
});

describe("prepareDisplayAssets", () => {
  it("passes through normal assets unchanged", () => {
    const assets = [{ id: 1, assetTypeName: "Hat" }, { id: 2, assetTypeName: "Face" }];
    const result = prepareDisplayAssets(assets);
    expect(result.assets).toHaveLength(2);
    expect(result.hiddenStandaloneAnimations).toBe(0);
    expect(result.groupedBundleComponents).toBe(0);
  });

  it("hides standalone non-emote animations", () => {
    const assets = [{ id: 1, assetTypeName: "Idle Animation" }];
    const result = prepareDisplayAssets(assets);
    expect(result.assets).toHaveLength(0);
    expect(result.hiddenStandaloneAnimations).toBe(1);
  });

  it("groups bundled animations into a single bundle entry", () => {
    const bundle = { id: 100, name: "Walk Pack", creatorName: "Roblox" };
    const assets = [
      { id: 1, assetTypeName: "Walk Animation", parentBundle: bundle },
      { id: 2, assetTypeName: "Run Animation", parentBundle: bundle },
    ];
    const result = prepareDisplayAssets(assets);
    expect(result.assets).toHaveLength(1);
    expect(result.groupedBundleComponents).toBe(2);
  });

  it("does not hide emote animations", () => {
    const assets = [{ id: 1, assetTypeName: "Emote Animation" }];
    const result = prepareDisplayAssets(assets);
    expect(result.assets).toHaveLength(1);
    expect(result.hiddenStandaloneAnimations).toBe(0);
  });

  it("deduplicates by asset id", () => {
    const assets = [{ id: 1, assetTypeName: "Hat" }, { id: 1, assetTypeName: "Hat" }];
    const result = prepareDisplayAssets(assets);
    expect(result.assets).toHaveLength(1);
  });

  it("uses animationPack mode correctly", () => {
    const assets = [{ id: 1, assetTypeName: "Walk Animation" }, { id: 2, assetTypeName: "Run Animation" }];
    const result = prepareDisplayAssets(assets, { mode: "animationPack", outfitName: "Robot Pack" });
    expect(result.assets).toHaveLength(2);
    expect(result.packComponentsShown).toBe(2);
    expect(result.packComponentMode).toBe(true);
    expect(result.assets[0].componentDisplayMode).toBe("pack-component");
  });
});

describe("makeBundleDisplayAsset", () => {
  it("creates a bundle display asset from asset and bundle", () => {
    const asset = { id: 1, name: "Walk Anim", creatorName: "Me" };
    const bundle = { id: 100, name: "Walk Pack", creatorName: "Roblox", price: 75, url: "https://example.com" };
    const result = makeBundleDisplayAsset(asset, bundle);
    expect(result.id).toBe(1);
    expect(result.name).toBe("Walk Pack");
    expect(result.purchasableType).toBe("Bundle");
    expect(result.purchasableId).toBe(100);
    expect(result.purchasableUrl).toBe("https://example.com");
    expect(result.price).toBe(75);
    expect(result.detailsSource).toBe("bundle-group");
  });

  it("falls back to asset name when bundle has no name", () => {
    const result = makeBundleDisplayAsset({ id: 1, name: "Walk" }, { id: 100 });
    expect(result.name).toBe("Walk");
  });
});

describe("compactForLog", () => {
  it("returns undefined for undefined input", () => {
    expect(compactForLog(undefined)).toBeUndefined();
  });

  it("passes through simple data", () => {
    expect(compactForLog({ a: 1, b: "hello" })).toEqual({ a: 1, b: "hello" });
  });

  it("truncates long strings at 800 chars", () => {
    const long = "x".repeat(1000);
    const result = compactForLog({ text: long });
    expect(result.text.length).toBeLessThan(1000);
    expect(result.text.endsWith("…")).toBe(true);
  });

  it("handles circular references gracefully", () => {
    const obj = {};
    obj.self = obj;
    const result = compactForLog(obj);
    expect(typeof result).toBe("string");
  });
});

describe("summarizeApiData", () => {
  it("returns non-object data as-is", () => {
    expect(summarizeApiData(null)).toBeNull();
    expect(summarizeApiData(42)).toBe(42);
  });

  it("summarizes a full API response", () => {
    const data = {
      ok: true,
      count: 2,
      users: [{ id: 1 }, { id: 2 }],
      currentlyWearing: [{ id: 10 }],
      outfits: [{ id: 20 }, { id: 21 }],
      assets: [{ id: 30 }],
      debug: { duplicateIds: [5], logs: ["log1", "log2"] },
    };
    const result = summarizeApiData(data);
    expect(result.ok).toBe(true);
    expect(result.count).toBe(2);
    expect(result.users).toBe(2);
    expect(result.currentlyWearing).toBe(1);
    expect(result.outfits).toBe(2);
    expect(result.assets).toBe(1);
    expect(result.debug.logs).toBe(2);
    expect(result.debug.duplicateIds).toEqual([5]);
  });

  it("omits missing fields as undefined", () => {
    const result = summarizeApiData({ ok: true });
    expect(result.users).toBeUndefined();
    expect(result.debug).toBeUndefined();
  });
});

describe("collectParamValues", () => {
  it("collects values for matching keys", () => {
    const params = new URLSearchParams("id=1&id=2&name=foo");
    expect(collectParamValues(params, ["id"])).toEqual(["1", "2"]);
  });

  it("collects from multiple key names", () => {
    const params = new URLSearchParams("user=alice&username=bob");
    expect(collectParamValues(params, ["user", "username"])).toEqual(["alice", "bob"]);
  });

  it("filters out empty values", () => {
    const params = new URLSearchParams("id=&name=foo");
    expect(collectParamValues(params, ["id", "name"])).toEqual(["foo"]);
  });
});

describe("splitParamList", () => {
  it("splits by comma", () => {
    expect(splitParamList("a,b,c")).toEqual(["a", "b", "c"]);
  });

  it("splits by semicolon", () => {
    expect(splitParamList("a;b;c")).toEqual(["a", "b", "c"]);
  });

  it("splits by newline", () => {
    expect(splitParamList("a\nb\nc")).toEqual(["a", "b", "c"]);
  });

  it("trims whitespace and filters empty", () => {
    expect(splitParamList(" a , , b ")).toEqual(["a", "b"]);
  });

  it("handles empty/null input", () => {
    expect(splitParamList("")).toEqual([]);
    expect(splitParamList(null)).toEqual([]);
  });
});

describe("looksLikeGithub404", () => {
  it("returns true for GitHub 404 pages", () => {
    expect(looksLikeGithub404("Page not found - GitHub Pages", { status: 404 })).toBe(true);
    expect(looksLikeGithub404("File not found", { status: 404 })).toBe(true);
  });

  it("returns false for non-404 status", () => {
    expect(looksLikeGithub404("Page not found", { status: 200 })).toBe(false);
  });

  it("returns false for non-GitHub 404", () => {
    expect(looksLikeGithub404("Custom 404 page", { status: 404 })).toBe(false);
  });
});

describe("getDisplayItem", () => {
  it("returns basic display item for simple asset", () => {
    const result = getDisplayItem({ id: 42, name: "Cool Hat", assetTypeName: "Hat" });
    expect(result.id).toBe(42);
    expect(result.name).toBe("Cool Hat");
    expect(result.metaType).toBe("Hat");
    expect(result.missingName).toBe(false);
    expect(result.url).toBe("https://www.roblox.com/catalog/42");
  });

  it("uses fallback label for fallback names", () => {
    const result = getDisplayItem({ id: 42, name: "Asset 42" });
    expect(result.missingName).toBe(true);
    expect(result.name).toBe("Asset #42");
  });

  it("handles pack-component display mode", () => {
    const result = getDisplayItem({
      id: 10,
      name: "Walk Anim",
      componentDisplayMode: "pack-component",
      parentBundle: { id: 100, name: "Walk Pack" },
    });
    expect(result.purchasableType).toBe("Bundle");
    expect(result.priceStatus).toBe("Included in pack");
    expect(result.componentNote).toContain("Walk Pack");
  });

  it("handles bundle items", () => {
    const result = getDisplayItem({
      id: 10,
      name: "Component",
      parentBundle: { id: 100, name: "My Bundle", price: 50, url: "https://example.com" },
    });
    expect(result.name).toBe("My Bundle");
    expect(result.purchasableType).toBe("Bundle");
    expect(result.bundleId).toBe(100);
  });
});

describe("formatLogLine", () => {
  it("formats a log entry without data", () => {
    const line = formatLogLine({ time: "2023-01-01T00:00:00Z", level: "info", message: "hello" });
    expect(line).toBe("[2023-01-01T00:00:00Z] INFO hello");
  });

  it("formats a log entry with data", () => {
    const line = formatLogLine({ time: "2023-01-01T00:00:00Z", level: "error", message: "fail", data: { code: 500 } });
    expect(line).toContain("[2023-01-01T00:00:00Z] ERROR fail");
    expect(line).toContain('"code": 500');
  });
});
