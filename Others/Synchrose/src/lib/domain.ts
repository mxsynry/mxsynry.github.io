export const SOURCE_IDS = ["weao", "voxlis", "pulsery", "inject"] as const;

export type SourceId = (typeof SOURCE_IDS)[number];
export type Platform = "windows" | "mac" | "android" | "ios" | "unknown";
export type Detection = "undetected" | "client-mod-only" | "detected" | "unknown";
export type WorkingConsensus = "working" | "broken" | "mixed" | "unknown";
export type DetectionConsensus = Detection | "mixed";
export type SourceHealthState = "loading" | "live" | "cached" | "error";

export interface SourceLinks {
  website?: string;
  discord?: string;
  purchase?: string;
  review?: string;
}

export interface SourceRecord {
  source: SourceId;
  sourceId?: string;
  rating?: number | null;
  insecure?: boolean;
  inviteOnly?: boolean;
  reviewCount?: number | null;
  stability?: number | null;
  myriad?: number | null;
  name: string;
  platforms: Platform[];
  working: boolean | null;
  detection: Detection;
  version: string | null;
  robloxVersion: string | null;
  price: string | null;
  free: boolean | null;
  sunc: number | null;
  unc: number | null;
  type: string | null;
  features: string[];
  description: string | null;
  links: SourceLinks;
  warning: boolean;
  sourceUpdatedAt: string | null;
  fetchedAt: string;
}

export interface SourceResult {
  source: SourceId;
  records: SourceRecord[];
  fetchedAt: string;
  error?: string;
}

export interface SourceHealth {
  state: SourceHealthState;
  count: number;
  fetchedAt: string | null;
  message?: string;
}

export interface EvidenceConflict {
  field: "working" | "detection" | "version" | "price" | "sunc";
  values: Array<{ source: SourceId; value: string }>;
}

export interface ExecutorRecord {
  id: string;
  name: string;
  aliases: string[];
  platforms: Platform[];
  sources: SourceId[];
  observations: SourceRecord[];
  working: WorkingConsensus;
  detection: DetectionConsensus;
  version: string | null;
  price: string | null;
  free: boolean | null;
  sunc: { min: number; max: number } | null;
  type: string | null;
  features: string[];
  description: string | null;
  links: SourceLinks;
  warning: boolean;
  conflicts: EvidenceConflict[];
}

export interface CatalogSnapshot {
  version: 1;
  savedAt: string;
  results: Partial<Record<SourceId, SourceResult>>;
}

export interface CatalogFilters {
  platforms?: Platform[];
  tags?: string[];
  verified?: boolean;
  trending?: boolean;
  warning?: boolean;
  showInsecure?: boolean;
  showInviteOnly?: boolean;
  valueRating?: string;
  search: string;
  platform: Platform | "all" | "mobile";
  working: WorkingConsensus | "all";
  detection: DetectionConsensus | "all";
  price: "all" | "free" | "paid";
  source: SourceId | "multi" | "all";
  feature: string | "all";
  type: string;
  key: "all" | "keyless" | "keysystem";
  sunc: "all" | "100" | "80" | "50" | "measured" | "unknown";
  sort: "status" | "sources" | "sunc" | "name" | "popular" | "random" | "price" | "value";
}

export const SOURCE_META: Record<SourceId, { label: string; url: string; role: string }> = {
  weao: { label: "WEAO", url: "https://weao.xyz/", role: "status, versions, detection" },
  voxlis: { label: "Voxlis", url: "https://voxlis.net/", role: "catalog notes and pricing" },
  pulsery: { label: "Pulsery", url: "https://pulsery.gg/", role: "status, stability, reviews" },
  inject: { label: "Inject", url: "https://inject.today/", role: "status and catalog" }
};
