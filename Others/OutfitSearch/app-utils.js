// Pure utility functions extracted from app.js for reuse and testability.

export function hasConfiguredApi(apiBase, defaultApiBase) {
  return apiBase && apiBase !== defaultApiBase;
}

export function isFallbackAssetName(name, id) {
  const s = String(name || "").trim();
  if (!s) return true;
  if (/^asset$/i.test(s)) return true;
  if (/^asset\s+\d+$/i.test(s)) return true;
  return Number.isFinite(Number(id)) && s === `Asset ${id}`;
}

export function uniqueBy(arr, fn) {
  const seen = new Set();
  return arr.filter(x => {
    const k = fn(x);
    if (k === undefined || k === null || seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

export function formatDate(value) {
  if (!value) return "unknown";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "unknown";
  return d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

export function cleanError(err) {
  let message = err?.message || String(err);
  message = message.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
  if (message.length > 260) message = message.slice(0, 260) + "…";
  return message;
}

export function escapeHtml(v) {
  return String(v ?? "").replace(/[&<>'"]/g, ch => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[ch]));
}

export function escapeAttr(v) {
  return escapeHtml(v).replace(/`/g, "&#96;");
}

export function formatPrice(item = {}) {
  const source = item.parentBundle || item;
  const status = String(source.priceStatus || item.priceStatus || "").trim();

  const direct = Number(source.price);
  if (Number.isFinite(direct)) return direct === 0 ? "Free" : `${direct} Robux`;

  const lowest = Number(source.lowestPrice ?? source.resaleLowestPrice);
  if (Number.isFinite(lowest) && lowest > 0) return `${lowest} Robux+`;

  if (/^free$/i.test(status)) return "Free";
  if (status && !/^off\s*sale$/i.test(status)) return status;

  if (source.isLimited || source.collectibleItemId || item.collectibleItemId) return "Limited / no listings";
  if (source.isForSale === false || /^off\s*sale$/i.test(status)) return "Off sale";

  return "Price unavailable";
}

export function normalizeName(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

export function classifyOutfitEntry(outfit = {}) {
  const name = normalizeName(outfit.name || "");
  const text = `${outfit.imageKind || ""} ${outfit.outfitKind || ""} ${outfit.thumbnailType || ""} ${outfit.imageUrl || ""} ${name}`;

  if (/DynamicHeadCostume|Costume/i.test(text)) return "costume";
  if (/\b(animation pack|animation package)\b/i.test(name)) return "animation";

  const knownPackages = new Set([
    "roblox girl",
    "roblox boy",
    "man",
    "woman",
    "city life woman",
    "city life man",
    "knights of redcliff paladin",
    "rthro normal",
    "rthro animation package"
  ]);

  if (knownPackages.has(name.toLowerCase())) return /animation/i.test(name) ? "animation" : "package";
  if (/\b(character|package|bundle)\b/i.test(name) && !/outfit/i.test(name)) return "package";
  return "saved";
}

export function splitOutfits(outfits = []) {
  const saved = [];
  const costumeLike = [];
  const animationPacks = [];
  const characterPackages = [];

  for (const outfit of outfits) {
    const kind = classifyOutfitEntry(outfit);
    if (kind === "costume") costumeLike.push(outfit);
    else if (kind === "animation") animationPacks.push(outfit);
    else if (kind === "package") characterPackages.push(outfit);
    else saved.push(outfit);
  }

  return { saved, costumeLike, animationPacks, characterPackages };
}

export function getAssetTypeText(asset = {}) {
  return String(asset.assetType?.name || asset.assetType?.Name || asset.assetTypeName || asset.itemType || "Asset");
}

export function fallbackAssetLabel(item, id) {
  const type = getShortTypeLabel(item);
  return type && type !== "Asset" ? `${type} #${id}` : `Asset #${id}`;
}

export function getShortTypeLabel(item = {}) {
  const raw = item.assetType?.name || item.assetType?.Name || item.assetTypeName || item.itemType || "Asset";
  return String(raw)
    .replace(/Accessory$/i, "Accessory")
    .replace(/Animation$/i, "Animation")
    .trim() || "Asset";
}

export function shouldGroupAsBundle(asset = {}) {
  const type = getAssetTypeText(asset);
  const name = String(asset.name || "");
  return /DynamicHead|MoodAnimation|Torso|Right Arm|Left Arm|Right Leg|Left Leg|Head/i.test(type)
    || /Dynamic Head|Animation Pack|Animation Package|Bundle|Package/i.test(name);
}

export function prepareDisplayAssets(rawAssets = [], options = {}) {
  const mode = options.mode || "normal";
  const assets = uniqueBy(rawAssets, a => Number(a.id || a.assetId));
  const output = [];
  const seenBundles = new Set();
  let hiddenStandaloneAnimations = 0;
  let groupedBundleComponents = 0;
  let packComponentsShown = 0;

  for (const asset of assets) {
    const type = getAssetTypeText(asset);
    const isAnimation = /Animation/i.test(type);
    const isEmote = /EmoteAnimation|Emote Animation/i.test(type);
    const bundle = asset.parentBundle;

    if (mode === "animationPack") {
      output.push({
        ...asset,
        componentDisplayMode: "pack-component",
        parentBundle: bundle || asset.parentBundle || null,
        bundleName: bundle?.name || options.outfitName || "Animation pack"
      });
      packComponentsShown += 1;
      continue;
    }

    if (isAnimation && !isEmote) {
      if (bundle?.id) {
        if (!seenBundles.has(bundle.id)) {
          output.push(makeBundleDisplayAsset(asset, bundle));
          seenBundles.add(bundle.id);
        }
        groupedBundleComponents += 1;
      } else {
        hiddenStandaloneAnimations += 1;
      }
      continue;
    }

    if (bundle?.id && shouldGroupAsBundle(asset)) {
      if (!seenBundles.has(bundle.id)) {
        output.push(makeBundleDisplayAsset(asset, bundle));
        seenBundles.add(bundle.id);
      }
      groupedBundleComponents += 1;
      continue;
    }

    output.push(asset);
  }

  return { assets: output, hiddenStandaloneAnimations, groupedBundleComponents, packComponentsShown, packComponentMode: mode === "animationPack" };
}

export function makeBundleDisplayAsset(asset, bundle) {
  return {
    ...asset,
    id: asset.id,
    name: bundle.name || asset.name || `Bundle ${bundle.id}`,
    parentBundle: bundle,
    creatorName: bundle.creatorName || asset.creatorName || null,
    price: bundle.price ?? asset.price ?? null,
    lowestPrice: bundle.lowestPrice ?? asset.lowestPrice ?? null,
    isForSale: bundle.isForSale ?? asset.isForSale ?? null,
    isFree: bundle.isFree ?? asset.isFree ?? false,
    purchasableType: "Bundle",
    purchasableId: bundle.id,
    purchasableUrl: bundle.url || `https://www.roblox.com/bundles/${bundle.id}`,
    assetTypeName: bundle.bundleType || "Bundle",
    itemType: "Bundle",
    detailsSource: "bundle-group"
  };
}

export function compactForLog(data) {
  if (data === undefined) return undefined;
  try {
    return JSON.parse(JSON.stringify(data, (_, value) => {
      if (typeof value === "string" && value.length > 800) return value.slice(0, 800) + "…";
      return value;
    }));
  } catch {
    return String(data);
  }
}

export function summarizeApiData(data) {
  if (!data || typeof data !== "object") return data;
  return {
    ok: data.ok,
    count: data.count,
    users: Array.isArray(data.users) ? data.users.length : undefined,
    currentlyWearing: Array.isArray(data.currentlyWearing) ? data.currentlyWearing.length : undefined,
    outfits: Array.isArray(data.outfits) ? data.outfits.length : undefined,
    assets: Array.isArray(data.assets) ? data.assets.length : undefined,
    debug: data.debug ? {
      duplicateIds: data.debug.duplicateIds,
      logs: Array.isArray(data.debug.logs) ? data.debug.logs.length : undefined
    } : undefined
  };
}

export function collectParamValues(params, keys) {
  return keys.flatMap(key => params.getAll(key)).filter(v => v !== null && v !== undefined && String(v).trim() !== "");
}

export function splitParamList(value) {
  return String(value || "")
    .split(/[\n,;]+/)
    .map(v => v.trim())
    .filter(Boolean);
}

export function looksLikeGithub404(text, res) {
  return (
    res.status === 404 &&
    (text.includes("Page not found") || text.includes("GitHub Pages") || text.includes("File not found"))
  );
}

export function getDisplayItem(item = {}) {
  const id = Number(item.id || item.assetId);
  const bundle = item.parentBundle || null;
  const rawName = item.name || item.Name || "";
  const missingName = isFallbackAssetName(rawName, id);
  const assetType = item.assetType?.name || item.assetType?.Name || item.assetTypeName || item.itemType || "Asset";

  if (item.componentDisplayMode === "pack-component") {
    const bundleName = bundle?.name || item.bundleName || "Animation pack";
    return {
      ...item,
      id,
      name: missingName ? fallbackAssetLabel(item, id) : rawName,
      missingName,
      creatorName: item.creatorName || bundle?.creatorName || "Roblox",
      price: null,
      lowestPrice: null,
      priceStatus: "Included in pack",
      isForSale: false,
      isFree: false,
      purchasableType: "Bundle",
      bundleId: bundle?.id || item.bundleId || null,
      url: bundle?.url || (bundle?.id ? `https://www.roblox.com/bundles/${bundle.id}` : `https://www.roblox.com/catalog/${id}`),
      metaType: `${assetType} component`,
      detailsSource: item.detailsSource || "pack-component",
      componentNote: `Included in ${bundleName}. Not sold as a standalone avatar item.`
    };
  }

  if (bundle?.id) {
    return {
      ...item,
      id,
      name: bundle.name || rawName || `Bundle ${bundle.id}`,
      missingName: false,
      creatorName: bundle.creatorName || item.creatorName || item.creator?.name || null,
      price: bundle.price ?? item.price ?? null,
      lowestPrice: bundle.lowestPrice ?? item.lowestPrice ?? null,
      priceStatus: bundle.priceStatus || item.priceStatus || null,
      isForSale: bundle.isForSale ?? item.isForSale ?? null,
      isFree: bundle.isFree ?? item.isFree ?? false,
      purchasableType: "Bundle",
      bundleId: bundle.id,
      url: bundle.url || `https://www.roblox.com/bundles/${bundle.id}`,
      metaType: `${bundle.bundleType || "Bundle"} component: ${assetType}`,
      detailsSource: item.detailsSource || bundle.detailsSource || null
    };
  }

  return {
    ...item,
    id,
    name: missingName ? fallbackAssetLabel(item, id) : rawName,
    missingName,
    creatorName: item.creatorName || item.creator?.name || item.creator?.Name || null,
    url: item.purchasableUrl || `https://www.roblox.com/catalog/${id}`,
    metaType: assetType,
    detailsSource: item.detailsSource || null
  };
}

export function formatLogLine(entry) {
  const data = entry.data === undefined ? "" : `\n${JSON.stringify(entry.data, null, 2)}`;
  return `[${entry.time}] ${entry.level.toUpperCase()} ${entry.message}${data}`;
}
