import { SOURCE_IDS, type DetectionConsensus, type EvidenceConflict, type ExecutorRecord, type SourceId, type SourceRecord, type SourceResult, type WorkingConsensus } from "./domain";
import { chooseDisplayName, mergeAliases, normalizeIdentity } from "./identity";
import { unique } from "./sources/common";

const GENERAL_PRIORITY: SourceId[] = ["weao", "pulsery", "inject", "voxlis"];
const DESCRIPTION_PRIORITY: SourceId[] = ["voxlis", "pulsery", "inject", "weao"];

export function mergeSourceResults(results: Partial<Record<SourceId, SourceResult>>): ExecutorRecord[] {
  const groups = new Map<string, SourceRecord[]>();
  for (const source of SOURCE_IDS) {
    for (const record of results[source]?.records ?? []) {
      const identity = normalizeIdentity(record.name);
      if (!identity) continue;
      const group = groups.get(identity) ?? [];
      group.push(record);
      groups.set(identity, group);
    }
  }
  return [...groups.entries()].map(([id, observations]) => mergeExecutor(id, observations)).sort((a, b) => a.name.localeCompare(b.name));
}

function mergeExecutor(id: string, observations: SourceRecord[]): ExecutorRecord {
  const ordered = orderBySource(observations, GENERAL_PRIORITY);
  const suncValues = observations.map((record) => record.sunc).filter(isNumber);
  const priceValues = unique(observations.map((record) => record.price).filter(isString));
  const freeValues = unique(observations.map((record) => record.free).filter(isBoolean));
  return {
    id,
    name: chooseDisplayName(observations),
    aliases: mergeAliases(observations),
    platforms: unique(observations.flatMap((record) => record.platforms)),
    sources: SOURCE_IDS.filter((source) => observations.some((record) => record.source === source)),
    observations,
    working: workingConsensus(observations),
    detection: detectionConsensus(observations),
    version: firstValue(ordered, "version"),
    price: priceValues.length > 1 ? "Varies" : priceValues[0] ?? null,
    free: freeValues.length === 1 ? freeValues[0] : null,
    sunc: suncValues.length ? { min: Math.min(...suncValues), max: Math.max(...suncValues) } : null,
    type: firstValue(ordered, "type"),
    features: unique(observations.flatMap((record) => record.features)).sort(),
    description: firstValue(orderBySource(observations, DESCRIPTION_PRIORITY), "description"),
    links: {
      website: firstLink(ordered, "website"), discord: firstLink(ordered, "discord"),
      purchase: firstLink(ordered, "purchase"), review: firstLink(ordered, "review")
    },
    warning: observations.some((record) => record.warning),
    conflicts: findConflicts(observations)
  };
}

function workingConsensus(records: SourceRecord[]): WorkingConsensus {
  const values = unique(records.map((record) => record.working).filter(isBoolean));
  if (!values.length) return "unknown";
  if (values.length > 1) return "mixed";
  return values[0] ? "working" : "broken";
}

function detectionConsensus(records: SourceRecord[]): DetectionConsensus {
  const values = unique(records.map((record) => record.detection).filter((value) => value !== "unknown"));
  if (!values.length) return "unknown";
  if (values.length > 1) return "mixed";
  return values[0];
}

function findConflicts(records: SourceRecord[]): EvidenceConflict[] {
  const conflicts: EvidenceConflict[] = [];
  pushConflict(conflicts, "working", records.filter((r) => r.working !== null).map((r) => ({ source: r.source, value: r.working ? "Working" : "Outdated" })));
  pushConflict(conflicts, "detection", records.filter((r) => r.detection !== "unknown").map((r) => ({ source: r.source, value: r.detection })));
  pushConflict(conflicts, "version", records.filter((r) => r.version).map((r) => ({ source: r.source, value: r.version! })));
  pushConflict(conflicts, "price", records.filter((r) => r.price).map((r) => ({ source: r.source, value: r.price! })));
  pushConflict(conflicts, "sunc", records.filter((r) => r.sunc !== null).map((r) => ({ source: r.source, value: `${r.sunc}%` })));
  return conflicts;
}

function pushConflict(conflicts: EvidenceConflict[], field: EvidenceConflict["field"], values: Array<{ source: SourceId; value: string }>) {
  if (unique(values.map((entry) => entry.value.toLowerCase())).length > 1) conflicts.push({ field, values });
}

function orderBySource(records: SourceRecord[], priority: SourceId[]): SourceRecord[] {
  return [...records].sort((a, b) => priority.indexOf(a.source) - priority.indexOf(b.source));
}

function firstValue<K extends "version" | "type" | "description">(records: SourceRecord[], key: K): SourceRecord[K] {
  return records.find((record) => record[key])?.[key] ?? null;
}

function firstLink(records: SourceRecord[], key: keyof SourceRecord["links"]): string | undefined {
  return records.find((record) => record.links[key])?.links[key];
}

function isNumber(value: number | null): value is number { return Number.isFinite(value); }
function isString(value: string | null): value is string { return Boolean(value); }
function isBoolean(value: boolean | null): value is boolean { return typeof value === "boolean"; }
