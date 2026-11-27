import {
  isHttpUrl,
  formatInteger,
  finiteOrNull,
  integerOrNull,
} from "./format.js";

export const DEMAND_LABELS = new Map([
  [-1, "Unassigned"],
  [0, "Terrible"],
  [1, "Low"],
  [2, "Normal"],
  [3, "High"],
  [4, "Amazing"],
]);
export const TREND_LABELS = new Map([
  [-1, "Unassigned"],
  [0, "Lowering"],
  [1, "Unstable"],
  [2, "Stable"],
  [3, "Raising"],
  [4, "Fluctuating"],
]);

export function getDisplayItem(item = {}) {
  const id = Number(item.id || item.assetId);
  const bundle = item.parentBundle || null;
  const roli = normalizeRolimons(item.rolimons);
  const rawName = item.name || item.Name || "";
  const preferredItemName =
    roli?.name || (!isFallbackAssetName(rawName, id) ? rawName : "");
  const assetType =
    item.assetType?.name ||
    item.assetType?.Name ||
    item.assetTypeName ||
    item.itemType ||
    "Asset";

  if (item.componentDisplayMode === "pack-component") {
    const bundleName = bundle?.name || item.bundleName || "Animation pack";
    return {
      ...item,
      id,
      rolimons: roli,
      name: preferredItemName || fallbackAssetLabel(item, id),
      missingName: !preferredItemName,
      creatorName: item.creatorName || bundle?.creatorName || "Roblox",
      price: null,
      lowestPrice: null,
      priceStatus: "Included in pack",
      isForSale: false,
      isFree: false,
      purchasableType: "Bundle",
      bundleId: bundle?.id || item.bundleId || null,
      url:
        bundle?.url ||
        (bundle?.id
          ? `https://www.roblox.com/bundles/${bundle.id}`
          : `https://www.roblox.com/catalog/${id}`),
      metaType: `${assetType} component`,
      detailsSource: item.detailsSource || "pack-component",
      componentNote: `Included in ${bundleName}. Not sold as a standalone avatar item.`,
    };
  }

  if (bundle?.id) {
    return {
      ...item,
      id,
      rolimons: roli,
      name: bundle.name || preferredItemName || `Bundle ${bundle.id}`,
      missingName: false,
      creatorName:
        bundle.creatorName || item.creatorName || item.creator?.name || null,
      price: bundle.price ?? item.price ?? null,
      lowestPrice: bundle.lowestPrice ?? item.lowestPrice ?? null,
      priceStatus: bundle.priceStatus || item.priceStatus || null,
      isForSale: bundle.isForSale ?? item.isForSale ?? null,
      isFree: bundle.isFree ?? item.isFree ?? false,
      purchasableType: "Bundle",
      bundleId: bundle.id,
      url: bundle.url || `https://www.roblox.com/bundles/${bundle.id}`,
      metaType: `${bundle.bundleType || "Bundle"} component: ${assetType}`,
      detailsSource: item.detailsSource || bundle.detailsSource || null,
    };
  }

  return {
    ...item,
    id,
    rolimons: roli,
    name: preferredItemName || fallbackAssetLabel(item, id),
    missingName: !preferredItemName,
    creatorName:
      item.creatorName || item.creator?.name || item.creator?.Name || null,
    url: item.purchasableUrl || `https://www.roblox.com/catalog/${id}`,
    metaType: assetType,
    detailsSource: item.detailsSource || null,
  };
}

function normalizeRolimons(value) {
  if (!value || typeof value !== "object") return null;
  const id = Number(value.id);
  return {
    ...value,
    id: Number.isSafeInteger(id) ? id : null,
    name: String(value.name || "").trim() || null,
    acronym: String(value.acronym || "").trim() || null,
    rap: finiteOrNull(value.rap),
    value: finiteOrNull(value.value),
    defaultValue: finiteOrNull(value.defaultValue),
    demand: integerOrNull(value.demand),
    trend: integerOrNull(value.trend),
    projected: Boolean(value.projected),
    hyped: Boolean(value.hyped),
    rare: Boolean(value.rare),
    url: isHttpUrl(value.url)
      ? value.url
      : Number.isSafeInteger(id)
        ? `https://www.rolimons.com/item/${id}`
        : null,
  };
}

function formatRolimonsMarket(roli) {
  if (!roli) return "";
  const parts = [];

  // Value is the preferred Rolimons market number when assigned; RAP remains visible separately.
  if (Number.isFinite(roli.value) && roli.value > 0)
    parts.push(`Value ${formatInteger(roli.value)}`);
  if (Number.isFinite(roli.rap) && roli.rap >= 0)
    parts.push(`RAP ${formatInteger(roli.rap)}`);
  if (
    !parts.length &&
    Number.isFinite(roli.defaultValue) &&
    roli.defaultValue >= 0
  ) {
    parts.push(`Default ${formatInteger(roli.defaultValue)}`);
  }

  return parts.join(" • ");
}

function formatRolimonsMeta(roli) {
  if (!roli) return "";
  const parts = [];
  if (roli.acronym) parts.push(roli.acronym);
  if (roli.demand !== null && DEMAND_LABELS.has(roli.demand))
    parts.push(`Demand ${DEMAND_LABELS.get(roli.demand)}`);
  if (roli.trend !== null && TREND_LABELS.has(roli.trend))
    parts.push(`Trend ${TREND_LABELS.get(roli.trend)}`);
  if (roli.projected) parts.push("Projected");
  if (roli.hyped) parts.push("Hyped");
  if (roli.rare) parts.push("Rare");
  return parts.join(" • ");
}

export function formatSourceLabel(item = {}) {
  if (item.rolimons) return "Rolimons + Roblox";
  const raw = String(item.detailsSource || "").trim();
  if (!raw) return "Roblox";
  return raw.replace(/\s*\+\s*rolimons/gi, "").trim() || "Roblox";
}

export function getCommerceDisplay(item = {}) {
  const source = item.parentBundle || item;
  const status = String(
    source.priceStatus ||
      item.priceStatus ||
      source.saleStatus ||
      item.saleStatus ||
      "",
  ).trim();
  const statusLower = status.toLowerCase();
  const nameLower = String(source.name || item.name || "").toLowerCase();
  const restrictions = [
    ...(Array.isArray(source.itemRestrictions) ? source.itemRestrictions : []),
    ...(Array.isArray(item.itemRestrictions) ? item.itemRestrictions : []),
    ...(Array.isArray(source.itemStatus) ? source.itemStatus : []),
    ...(Array.isArray(item.itemStatus) ? item.itemStatus : []),
  ].map((value) => String(value).toLowerCase());

  const isLimited = Boolean(
    source.isLimited ||
    item.isLimited ||
    source.isLimitedUnique ||
    item.isLimitedUnique ||
    source.collectibleItemId ||
    item.collectibleItemId ||
    item.rolimons ||
    restrictions.some((value) => /limited|collectible/.test(value)),
  );
  const isForSale =
    source.isForSale ??
    item.isForSale ??
    source.IsForSale ??
    item.IsForSale ??
    null;
  const hasResellers =
    source.hasResellers ??
    item.hasResellers ??
    source.HasResellers ??
    item.HasResellers ??
    null;

  const direct = firstFiniteNumber(
    source.price,
    item.price,
    source.priceInRobux,
    item.priceInRobux,
    source.PriceInRobux,
    item.PriceInRobux,
  );
  const resale = firstPositiveFiniteNumber(
    source.lowestPrice,
    item.lowestPrice,
    source.resaleLowestPrice,
    item.resaleLowestPrice,
    source.lowestResalePrice,
    item.lowestResalePrice,
  );
  const units = firstFiniteNumber(
    source.unitsAvailableForConsumption,
    item.unitsAvailableForConsumption,
    source.UnitsAvailableForConsumption,
    item.UnitsAvailableForConsumption,
  );
  const remaining = firstFiniteNumber(
    source.remaining,
    item.remaining,
    source.Remaining,
    item.Remaining,
  );
  const totalQuantity = firstFiniteNumber(
    source.totalQuantity,
    item.totalQuantity,
    source.TotalQuantity,
    item.TotalQuantity,
  );

  const removed =
    /content deleted|deleted|moderated|unavailable|banned|blocked|not approved/.test(
      nameLower,
    ) ||
    /unavailable|moderated|deleted|not available|banned|blocked|not approved/.test(
      statusLower,
    ) ||
    restrictions.some((value) =>
      /unavailable|moderated|deleted|banned|blocked|not approved/.test(value),
    );
  if (removed)
    return { label: "Unavailable", tone: "danger", state: "unavailable" };

  const soldOut =
    /sold\s*out|out\s*of\s*stock/.test(statusLower) ||
    (Number.isFinite(units) &&
      units <= 0 &&
      Number.isFinite(totalQuantity) &&
      totalQuantity > 0) ||
    (Number.isFinite(remaining) && remaining <= 0 && isLimited);

  if (isLimited) {
    const primaryStockAvailable =
      isForSale === true && (!Number.isFinite(units) || units > 0) && !soldOut;
    if (primaryStockAvailable && Number.isFinite(direct) && direct > 0) {
      return {
        label: formatInteger(direct),
        tone: "normal",
        state: "primary-sale",
      };
    }

    if (
      /no\s*resellers/.test(statusLower) ||
      (hasResellers === false && !primaryStockAvailable)
    ) {
      return {
        label: soldOut ? "Sold out" : "No listings",
        tone: "muted",
        state: soldOut ? "sold-out" : "no-listings",
      };
    }

    if (Number.isFinite(resale) && resale > 0 && hasResellers !== false) {
      return {
        label: `${formatInteger(resale)} resale`,
        tone: "market",
        state: "resale",
      };
    }

    if (soldOut) return { label: "Sold out", tone: "muted", state: "sold-out" };
    if (
      isForSale === false ||
      /off\s*sale|not\s*for\s*sale/.test(statusLower)
    ) {
      return { label: "Limited · off sale", tone: "muted", state: "off-sale" };
    }
    return { label: "Limited", tone: "market", state: "limited" };
  }

  if (soldOut) return { label: "Sold out", tone: "muted", state: "sold-out" };
  if (
    isForSale === false ||
    /off\s*sale|not\s*for\s*sale|no\s*resellers/.test(statusLower)
  ) {
    return { label: "Off sale", tone: "muted", state: "off-sale" };
  }
  if (/^free$/.test(statusLower) && isForSale !== false)
    return { label: "Free", tone: "success", state: "free" };

  if (Number.isFinite(direct)) {
    if (direct === 0) {
      return isForSale === true
        ? { label: "Free", tone: "success", state: "free" }
        : { label: "Unavailable", tone: "muted", state: "unknown-zero" };
    }
    return {
      label: formatInteger(direct),
      tone: "normal",
      state: "primary-sale",
    };
  }

  if (status) return { label: status, tone: "muted", state: "status" };
  return { label: "Unavailable", tone: "muted", state: "unknown" };
}

function firstFiniteNumber(...values) {
  for (const value of values) {
    if (value === undefined || value === null || value === "") continue;
    const number = Number(value);
    if (Number.isFinite(number)) return number;
  }
  return null;
}

function firstPositiveFiniteNumber(...values) {
  for (const value of values) {
    if (value === undefined || value === null || value === "") continue;
    const number = Number(value);
    if (Number.isFinite(number) && number > 0) return number;
  }
  return null;
}

function formatPrice(item = {}) {
  return getCommerceDisplay(item).label;
}

function isFallbackAssetName(name, id) {
  const value = String(name || "").trim();
  if (!value) return true;
  if (/^asset$/i.test(value)) return true;
  if (/^asset\s+#?\d+$/i.test(value)) return true;
  return Number.isFinite(Number(id)) && value === `Asset ${id}`;
}

function fallbackAssetLabel(item, id) {
  const type = getShortTypeLabel(item);
  return type && type !== "Asset" ? `${type} #${id}` : `Asset #${id}`;
}

function getShortTypeLabel(item = {}) {
  const raw =
    item.assetType?.name ||
    item.assetType?.Name ||
    item.assetTypeName ||
    item.itemType ||
    "Asset";
  return (
    String(raw)
      .replace(/Accessory$/i, "Accessory")
      .replace(/Animation$/i, "Animation")
      .trim() || "Asset"
  );
}
