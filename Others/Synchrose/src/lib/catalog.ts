import { SOURCE_IDS, type CatalogFilters, type CatalogSnapshot, type ExecutorRecord, type SourceHealth, type SourceId, type SourceResult } from "./domain";
import { mergeSourceResults } from "./consensus";
import { priceInfo } from "./price";
const randomOrder = new Map<string, number>();
function randomKey(id: string) { if (!randomOrder.has(id)) randomOrder.set(id, Math.random()); return randomOrder.get(id)!; }
import { fetchInject } from "./sources/inject";
import { fetchPulsery } from "./sources/pulsery";
import { fetchVoxlis } from "./sources/voxlis";
import { fetchWeao } from "./sources/weao";

const CACHE_KEY = "synchrose:source-snapshot:v1";
const CACHE_MAX_AGE = 24 * 60 * 60 * 1000;
type SourceLoader = (apiBase: string) => Promise<SourceResult>;
const LOADERS: Record<SourceId, SourceLoader> = { weao: fetchWeao, voxlis: fetchVoxlis, pulsery: fetchPulsery, inject: fetchInject };

export interface CatalogUpdate {
  results: Partial<Record<SourceId, SourceResult>>;
  health: Record<SourceId, SourceHealth>;
  records: ExecutorRecord[];
  pending: number;
}

export function readSnapshot(): CatalogSnapshot | null {
  try {
    const parsed = JSON.parse(localStorage.getItem(CACHE_KEY) || "null") as CatalogSnapshot | null;
    if (!parsed || parsed.version !== 1 || !parsed.savedAt || !parsed.results) return null;
    if (Date.now() - new Date(parsed.savedAt).valueOf() > CACHE_MAX_AGE) return null;
    return parsed;
  } catch { return null; }
}

export function initialUpdate(snapshot: CatalogSnapshot | null): CatalogUpdate {
  const results = snapshot?.results ?? {};
  const health = Object.fromEntries(SOURCE_IDS.map((source) => {
    const cached = results[source];
    return [source, { state: cached ? "cached" : "loading", count: cached?.records.length ?? 0, fetchedAt: cached?.fetchedAt ?? null } satisfies SourceHealth];
  })) as Record<SourceId, SourceHealth>;
  return buildUpdate(results, health, SOURCE_IDS.length);
}

export async function refreshCatalog(apiBase: string, previous: CatalogUpdate, onUpdate: (update: CatalogUpdate) => void): Promise<CatalogUpdate> {
  const results = { ...previous.results };
  const health = Object.fromEntries(SOURCE_IDS.map((source) => [source, { ...previous.health[source], state: "loading" }])) as Record<SourceId, SourceHealth>;
  let pending = SOURCE_IDS.length;
  onUpdate(buildUpdate(results, health, pending));
  await Promise.all(SOURCE_IDS.map(async (source) => {
    try {
      const result = await LOADERS[source](apiBase);
      results[source] = result;
      health[source] = { state: "live", count: result.records.length, fetchedAt: result.fetchedAt };
    } catch (error) {
      const cached = results[source];
      health[source] = {
        state: cached ? "cached" : "error", count: cached?.records.length ?? 0, fetchedAt: cached?.fetchedAt ?? null,
        message: error instanceof Error ? error.message : String(error)
      };
    }
    pending -= 1;
    const update = buildUpdate(results, health, pending);
    onUpdate(update);
    writeSnapshot(results);
  }));
  return buildUpdate(results, health, 0);
}

export function filterCatalog(records: ExecutorRecord[], filters: CatalogFilters): ExecutorRecord[] {
  const search = filters.search.trim().toLowerCase();
  const filtered = records.filter((record) => {
    if (filters.platforms?.length && !filters.platforms.some(p => record.platforms.includes(p))) return false;
    if (filters.tags?.length && !filters.tags.every(tag => record.features.includes(tag))) return false;
    if (filters.verified && !record.features.includes("Verified")) return false;
    if (filters.trending && !record.features.includes("Trending")) return false;
    if (filters.warning && !record.warning) return false;
    if (filters.showInsecure === false && (record.warning || record.observations.some(o => o.insecure))) return false;
    if (filters.showInviteOnly === false && record.observations.some(o => o.inviteOnly)) return false;
    if (filters.valueRating && filters.valueRating !== "all" && priceInfo(record.price).rating !== filters.valueRating) return false;
    if (search) {
      const haystack = [record.name, record.version, record.price, record.type, record.detection, ...record.aliases, ...record.platforms, ...record.features, ...record.sources, ...record.observations.map(o => o.description || "")].join(" ").toLowerCase();
      if (!haystack.includes(search)) return false;
    }
    if (filters.platform === "mobile") {
      if (!record.platforms.some((platform) => platform === "android" || platform === "ios")) return false;
    } else if (filters.platform !== "all" && !record.platforms.includes(filters.platform)) return false;
    if (filters.working !== "all" && record.working !== filters.working) return false;
    if (filters.detection !== "all" && record.detection !== filters.detection) return false;
    if (filters.price === "free" && record.free !== true) return false;
    if (filters.price === "paid" && record.free !== false) return false;
    if (filters.source === "multi" && record.sources.length < 2) return false;
    if (filters.source !== "all" && filters.source !== "multi" && !record.sources.includes(filters.source)) return false;
    if (filters.type !== "all" && (record.type || "Unknown") !== filters.type) return false;
    if (filters.key === "keysystem" && !record.features.includes("Key system")) return false;
    if (filters.key === "keyless" && !record.features.includes("Keyless")) return false;
    if (filters.sunc === "unknown" && record.sunc !== null) return false;
    if (filters.sunc === "measured" && record.sunc === null) return false;
    if (["100", "80", "50"].includes(filters.sunc) && (record.sunc?.min ?? -1) < Number(filters.sunc)) return false;
    if (filters.feature !== "all" && !record.features.includes(filters.feature)) return false;
    return true;
  });
  return filtered.sort((a, b) => {
    if (filters.sort === "random") return randomKey(a.id) - randomKey(b.id);
    if (filters.sort === "price") return priceInfo(a.price).cost - priceInfo(b.price).cost || a.name.localeCompare(b.name);
    if (filters.sort === "value") return ["good","fair","expensive","unknown"].indexOf(priceInfo(a.price).rating) - ["good","fair","expensive","unknown"].indexOf(priceInfo(b.price).rating) || a.name.localeCompare(b.name);
    if (filters.sort === "popular") return Number(b.features.includes("Trending")) - Number(a.features.includes("Trending")) || Math.max(0, ...b.observations.map(o => o.reviewCount || 0)) - Math.max(0, ...a.observations.map(o => o.reviewCount || 0)) || a.name.localeCompare(b.name);
    if (filters.sort === "name") return a.name.localeCompare(b.name);
    if (filters.sort === "sources") return b.sources.length - a.sources.length || a.name.localeCompare(b.name);
    if (filters.sort === "sunc") return (b.sunc?.max ?? -1) - (a.sunc?.max ?? -1) || a.name.localeCompare(b.name);
    return statusRank(a.working) - statusRank(b.working) || b.sources.length - a.sources.length || a.name.localeCompare(b.name);
  });
}

function statusRank(status: ExecutorRecord["working"]): number { return { working: 0, mixed: 1, unknown: 2, broken: 3 }[status]; }
function buildUpdate(results: Partial<Record<SourceId, SourceResult>>, health: Record<SourceId, SourceHealth>, pending: number): CatalogUpdate {
  return { results: { ...results }, health: { ...health }, records: mergeSourceResults(results), pending };
}
function writeSnapshot(results: Partial<Record<SourceId, SourceResult>>) {
  try {
    const snapshot: CatalogSnapshot = { version: 1, savedAt: new Date().toISOString(), results };
    localStorage.setItem(CACHE_KEY, JSON.stringify(snapshot));
  } catch { /* Live data works without browser storage. */ }
}
