import type { SourceRecord } from "./domain";

const ALIASES: Record<string, string> = {
  arceusxneo: "arceusx",
  arceusx: "arceusx",
  bunnifun: "bunni",
  dx9warev2: "dx9ware",
  matrixhub: "matrix",
  matrix: "matrix",
  vegax: "vegax",
  yubx: "yubx"
};

const SOURCE_NAME_PRIORITY = ["weao", "pulsery", "inject", "voxlis"] as const;

export function normalizeIdentity(value: string): string {
  const normalized = value.normalize("NFKD").toLowerCase().replace(/[^a-z0-9]+/g, "");
  return ALIASES[normalized] ?? normalized;
}

export function chooseDisplayName(records: SourceRecord[]): string {
  for (const source of SOURCE_NAME_PRIORITY) {
    const record = records.find((candidate) => candidate.source === source && candidate.name.trim());
    if (record) return record.name.trim();
  }
  return records[0]?.name.trim() || "Unknown";
}

export function mergeAliases(records: SourceRecord[]): string[] {
  return [...new Set(records.map((record) => record.name.trim()).filter(Boolean))].sort((a, b) =>
    a.localeCompare(b)
  );
}
