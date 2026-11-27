import { unique } from "./utils.js";

const ROLIMONS_V2_URL = "https://api.rolimons.com/items/v2/itemdetails";
const ROLIMONS_V1_URL = "https://api.rolimons.com/items/v1/itemdetails";
const ROLIMONS_CACHE_MS = 120000;
const ROLIMONS_TIMEOUT_MS = 10000;
let rolimonsMemoryItems = null;
let rolimonsMemoryExpiresAt = 0;
let rolimonsInflight = null;

export async function getRolimonsByIds(assetIds, logs = []) {
  const ids = unique((assetIds || []).map(Number));
  if (!ids.length) return {};

  let all;
  try {
    all = await getRolimonsItems(logs);
  } catch (err) {
    logs.push(`Rolimons unavailable: ${err.message}`);
    return {};
  }

  const matched = {};
  for (const id of ids) {
    if (all[id]) matched[id] = all[id];
  }

  logs.push(
    `Rolimons matched ${Object.keys(matched).length} of ${ids.length} requested asset(s).`,
  );
  return matched;
}

export function mergeRolimonsIntoAsset(asset = {}, rolimons = null) {
  if (!rolimons) return asset;

  const id = Number(asset.id || asset.assetId || rolimons.id);
  const currentName = String(asset.name || asset.Name || "").trim();
  const nameMissing = !currentName || /^asset(?:\s+#?\d+)?$/i.test(currentName);

  return {
    ...asset,
    id,
    name:
      nameMissing && rolimons.name
        ? rolimons.name
        : asset.name || rolimons.name || `Asset ${id}`,
    isLimited: true,
    rolimons,
    componentNote: joinProviderNotes(
      asset.componentNote,
      formatRolimonsNote(rolimons),
    ),
    detailsSource: appendProviderSource(asset.detailsSource, "rolimons"),
  };
}

async function getRolimonsItems(logs = []) {
  const now = Date.now();

  if (rolimonsMemoryItems && now < rolimonsMemoryExpiresAt) {
    logs.push("Rolimons memory cache hit.");
    return rolimonsMemoryItems;
  }

  if (rolimonsInflight) {
    logs.push("Rolimons fetch joined an in-flight request.");
    return rolimonsInflight;
  }

  rolimonsInflight = (async () => {
    let payload;
    let version = "v2";

    try {
      payload = await fetchRolimonsJson(ROLIMONS_V2_URL, "Rolimons v2");
    } catch (v2Error) {
      logs.push(`Rolimons v2 failed: ${v2Error.message}. Falling back to v1.`);
      version = "v1";
      payload = await fetchRolimonsJson(ROLIMONS_V1_URL, "Rolimons v1");
    }

    const items = normalizeRolimonsPayload(payload);
    const count = Object.keys(items).length;
    if (!count) throw new Error("Rolimons returned no usable item records.");

    rolimonsMemoryItems = items;
    rolimonsMemoryExpiresAt = Date.now() + ROLIMONS_CACHE_MS;
    logs.push(`Rolimons ${version} loaded ${count} tracked item(s).`);
    return items;
  })();

  try {
    return await rolimonsInflight;
  } finally {
    rolimonsInflight = null;
  }
}

async function fetchRolimonsJson(url, label) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), ROLIMONS_TIMEOUT_MS);

  try {
    const res = await fetch(url, {
      method: "GET",
      headers: {
        accept: "application/json",
        referer: "https://www.rolimons.com/",
      },
      signal: controller.signal,
    });

    if (!res.ok) {
      const err = new Error(`${label}: HTTP ${res.status}`);
      err.status = res.status;
      throw err;
    }

    const data = await res.json();
    if (!data || typeof data.items !== "object") {
      throw new Error(`${label}: invalid item payload`);
    }

    return data;
  } catch (err) {
    if (controller.signal.aborted) {
      throw new Error(
        `${label} timed out after ${Math.round(ROLIMONS_TIMEOUT_MS / 1000)} seconds`,
      );
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
  }
}

export function normalizeRolimonsPayload(payload = {}) {
  const out = {};

  for (const [rawId, row] of Object.entries(payload.items || {})) {
    if (!Array.isArray(row)) continue;

    const id = Number(rawId);
    if (!Number.isSafeInteger(id)) continue;

    out[id] = {
      id,
      name: cleanRolimonsString(row[0]),
      acronym: cleanRolimonsString(row[1]),
      rap: rolimonsNumber(row[2]),
      value: rolimonsNumber(row[3]),
      defaultValue: rolimonsNumber(row[4]),
      demand: rolimonsEnum(row[5]),
      trend: rolimonsEnum(row[6]),
      projected: Number(row[7]) > 0,
      hyped: Number(row[8]) > 0,
      rare: Number(row[9]) > 0,
      url: `https://www.rolimons.com/item/${id}`,
    };
  }

  return out;
}

function formatRolimonsNote(item) {
  if (!item) return null;

  const parts = [];
  if (Number.isFinite(item.rap))
    parts.push(`RAP ${formatCompactInteger(item.rap)}`);
  if (Number.isFinite(item.value))
    parts.push(`Value ${formatCompactInteger(item.value)}`);
  if (item.acronym) parts.push(item.acronym);
  if (item.projected) parts.push("Projected");
  if (item.hyped) parts.push("Hyped");
  if (item.rare) parts.push("Rare");

  return parts.length
    ? `Rolimons · ${parts.join(" · ")}`
    : "Rolimons tracked item";
}

function rolimonsNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

function rolimonsEnum(value) {
  const n = Number(value);
  return Number.isInteger(n) && n >= 0 ? n : null;
}

function cleanRolimonsString(value) {
  const valueText = String(value ?? "").trim();
  return valueText || null;
}

function appendProviderSource(existing, provider) {
  const sources = String(existing || "")
    .split("+")
    .map((part) => part.trim())
    .filter(Boolean);

  if (!sources.includes(provider)) sources.push(provider);
  return sources.join(" + ");
}

function joinProviderNotes(existing, next) {
  return (
    [existing, next]
      .map((value) => String(value || "").trim())
      .filter(Boolean)
      .join(" · ") || null
  );
}

function formatCompactInteger(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "?";
  if (n >= 1000000) return `${trimCompact(n / 1000000)}M`;
  if (n >= 1000) return `${trimCompact(n / 1000)}K`;
  return String(Math.round(n));
}

function trimCompact(value) {
  const digits = value >= 100 ? 0 : value >= 10 ? 1 : 2;
  return Number(value.toFixed(digits)).toString();
}
