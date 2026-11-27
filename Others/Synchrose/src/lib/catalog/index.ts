import { writeSnapshot } from "./cache";
export { readSnapshot } from "./cache";
export { filterCatalog } from "./filters";

import {
  SOURCE_IDS,
  type CatalogSnapshot,
  type ExecutorRecord,
  type SourceHealth,
  type SourceId,
  type SourceResult,
} from "./model";
import { mergeSourceResults } from "./merge";
import { fetchBypass } from "./sources/bypass";
import { fetchPulsery } from "./sources/pulsery";
import { fetchVoxlis } from "./sources/voxlis";
import { fetchWeao } from "./sources/weao";

type SourceLoader = (apiBase: string) => Promise<SourceResult>;
const LOADERS: Record<SourceId, SourceLoader> = {
  weao: fetchWeao,
  voxlis: fetchVoxlis,
  pulsery: fetchPulsery,
  bypass: fetchBypass,
};

export interface CatalogUpdate {
  results: Partial<Record<SourceId, SourceResult>>;
  health: Record<SourceId, SourceHealth>;
  records: ExecutorRecord[];
  pending: number;
}

export function initialUpdate(snapshot: CatalogSnapshot | null): CatalogUpdate {
  const results = snapshot?.results ?? {};
  const health = Object.fromEntries(
    SOURCE_IDS.map((source) => {
      const cached = results[source];
      return [
        source,
        {
          state: cached ? "cached" : "loading",
          count: cached?.records.length ?? 0,
          fetchedAt: cached?.fetchedAt ?? null,
        } satisfies SourceHealth,
      ];
    }),
  ) as Record<SourceId, SourceHealth>;
  return buildUpdate(results, health, SOURCE_IDS.length);
}

export async function refreshCatalog(
  apiBase: string,
  previous: CatalogUpdate,
  onUpdate: (update: CatalogUpdate) => void,
): Promise<CatalogUpdate> {
  const results = { ...previous.results };
  const health = Object.fromEntries(
    SOURCE_IDS.map((source) => [
      source,
      { ...previous.health[source], state: "loading" },
    ]),
  ) as Record<SourceId, SourceHealth>;
  let pending = SOURCE_IDS.length;
  onUpdate(buildUpdate(results, health, pending));
  await Promise.all(
    SOURCE_IDS.map(async (source) => {
      try {
        const result = await LOADERS[source](apiBase);
        results[source] = result;
        health[source] = {
          state: result.stale ? "cached" : "live",
          count: result.records.length,
          fetchedAt: result.fetchedAt,
          message: result.stale
            ? "The upstream catalog reports cached data."
            : undefined,
        };
      } catch (error) {
        const cached = results[source];
        health[source] = {
          state: cached ? "cached" : "error",
          count: cached?.records.length ?? 0,
          fetchedAt: cached?.fetchedAt ?? null,
          message: error instanceof Error ? error.message : String(error),
        };
      }
      pending -= 1;
      const update = buildUpdate(results, health, pending);
      onUpdate(update);
      writeSnapshot(results);
    }),
  );
  return buildUpdate(results, health, 0);
}

function buildUpdate(
  results: Partial<Record<SourceId, SourceResult>>,
  health: Record<SourceId, SourceHealth>,
  pending: number,
): CatalogUpdate {
  return {
    results: { ...results },
    health: { ...health },
    records: mergeSourceResults(results),
    pending,
  };
}
