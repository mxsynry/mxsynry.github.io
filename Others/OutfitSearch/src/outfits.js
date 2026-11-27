import { uniqueBy, normalizeName } from "./format.js";

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
    "rthro animation package",
  ]);

  if (knownPackages.has(name.toLowerCase()))
    return /animation/i.test(name) ? "animation" : "package";
  if (/\b(character|package|bundle)\b/i.test(name) && !/outfit/i.test(name))
    return "package";
  return "saved";
}

export function prepareDisplayAssets(rawAssets = [], options = {}) {
  const mode = options.mode || "normal";
  const assets = uniqueBy(rawAssets, (asset) =>
    Number(asset.id || asset.assetId),
  );
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
        parentBundle: bundle || null,
        bundleName: bundle?.name || options.outfitName || "Animation pack",
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

  return {
    assets: output,
    hiddenStandaloneAnimations,
    groupedBundleComponents,
    packComponentsShown,
    packComponentMode: mode === "animationPack",
  };
}

function makeBundleDisplayAsset(asset, bundle) {
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
    detailsSource: "bundle-group",
  };
}

function shouldGroupAsBundle(asset = {}) {
  const type = getAssetTypeText(asset);
  const name = String(asset.name || "");
  return (
    /DynamicHead|MoodAnimation|Torso|Right Arm|Left Arm|Right Leg|Left Leg|Head/i.test(
      type,
    ) ||
    /Dynamic Head|Animation Pack|Animation Package|Bundle|Package/i.test(name)
  );
}

function getAssetTypeText(asset = {}) {
  return String(
    asset.assetType?.name ||
      asset.assetType?.Name ||
      asset.assetTypeName ||
      asset.itemType ||
      "Asset",
  );
}
