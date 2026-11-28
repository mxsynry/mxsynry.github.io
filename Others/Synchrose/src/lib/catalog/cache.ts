import type { CatalogSnapshot, SourceId, SourceResult } from "./model";

const CACHE_KEY = "synchrose:source-snapshot:v3";
const CACHE_MAX_AGE = 24 * 60 * 60 * 1000;
export function readSnapshot(): CatalogSnapshot | null {
  try {
    const parsed = JSON.parse(
      localStorage.getItem(CACHE_KEY) || "null",
    ) as CatalogSnapshot | null;
    if (!parsed || parsed.version !== 3 || !parsed.savedAt || !parsed.results)
      return null;
    if (Date.now() - new Date(parsed.savedAt).valueOf() > CACHE_MAX_AGE)
      return null;
    return parsed;
  } catch {
    return null;
  }
}

export function writeSnapshot(
  results: Partial<Record<SourceId, SourceResult>>,
) {
  try {
    const snapshot: CatalogSnapshot = {
      version: 3,
      savedAt: new Date().toISOString(),
      results,
    };
    localStorage.setItem(CACHE_KEY, JSON.stringify(snapshot));
  } catch {
    /* Live data works without browser storage. */
  }
}
