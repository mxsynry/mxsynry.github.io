import { z } from "zod";
import type { SourceRecord, SourceResult } from "../domain";
import { endpoints } from "../config";
import { booleanOrNull, cleanText, normalizeDetection, normalizePlatform, numberOrNull, safeUrl } from "../format";
import { fetchWithFallback } from "../http";
import { asArray, asObject, normalizeType, sourceTimestamp, unique } from "./common";

const itemSchema = z.object({
  title: z.unknown().optional(), name: z.unknown().optional(), platform: z.unknown().optional(),
  cost: z.unknown().optional(), free: z.unknown().optional(), updateStatus: z.unknown().optional(),
  detected: z.unknown().optional(), suncPercentage: z.unknown().optional(), uncPercentage: z.unknown().optional(),
  version: z.unknown().optional(), rbxversion: z.unknown().optional(), rbxVersion: z.unknown().optional()
}).passthrough();

export async function fetchWeao(apiBase: string): Promise<SourceResult> {
  const config = endpoints(apiBase);
  const fetchedAt = new Date().toISOString();
  const [statusPayload, versionsPayload] = await Promise.all([
    fetchWithFallback(config.weaoStatus, config.weaoStatusFallback),
    fetchWithFallback(config.weaoVersions, config.weaoVersionsFallback).catch(() => ({}))
  ]);
  const root = asObject(statusPayload);
  const candidates = Array.isArray(statusPayload)
    ? statusPayload
    : asArray(root.data).length ? asArray(root.data) : asArray(root.exploits);
  const records = candidates
    .map((candidate) => itemSchema.safeParse(candidate))
    .filter((result) => result.success)
    .map((result) => normalizeWeaoRecord(result.data, versionsPayload, fetchedAt))
    .filter((record): record is SourceRecord => Boolean(record));
  if (!records.length) throw new Error("WEAO returned no usable executor records.");
  return { source: "weao", records, fetchedAt };
}

function normalizeWeaoRecord(item: z.infer<typeof itemSchema>, versionsPayload: unknown, fetchedAt: string): SourceRecord | null {
  const name = cleanText(item.title) || cleanText(item.name);
  if (!name) return null;
  const platform = normalizePlatform(item.platform);
  const cost = cleanText(item.cost);
  const freeFlag = booleanOrNull(item.free);
  const free = freeFlag ?? (cost ? /\bfree\b/i.test(cost) : null);
  const slug = asObject(item.slug);
  const currentVersion = findPlatformVersion(versionsPayload, platform);
  const reportedRobloxVersion = cleanText(item.rbxversion) || cleanText(item.rbxVersion);
  const explicitWorking = booleanOrNull(item.updateStatus);
  const working = currentVersion && reportedRobloxVersion ? currentVersion === reportedRobloxVersion : explicitWorking;
  const features = unique([
    item.decompiler === true ? "Decompiler" : "",
    item.multiInject === true ? "Multi-instance" : "",
    item.keysystem === true ? "Key system" : "",
    item.clientmods === true ? "Client-mod bypass" : "",
    item.beta === true ? "Beta" : "",
    item.elementCertified === true ? "Verified" : ""
  ].filter(Boolean));
  return {
    source: "weao", sourceId: cleanText(item.id) ?? undefined, name, platforms: [platform], working,
    detection: item.clientmods === true ? "client-mod-only" : normalizeDetection(item.detected),
    version: cleanText(item.version), robloxVersion: reportedRobloxVersion,
    price: cost || (free === true ? "Free" : free === false ? "Paid" : null), free,
    sunc: numberOrNull(item.suncPercentage), unc: numberOrNull(item.uncPercentage),
    type: normalizeType(item.extype ?? item.type), features,
    description: cleanText(slug.fullDescription) || cleanText(item.description),
    links: { website: safeUrl(item.websitelink ?? item.website), discord: safeUrl(item.discordlink ?? item.discord), purchase: safeUrl(item.purchaselink) },
    warning: item.hasIssues === true, sourceUpdatedAt: sourceTimestamp(item.updatedDate, fetchedAt), fetchedAt
  };
}

function findPlatformVersion(payload: unknown, platform: string): string | null {
  const root = asObject(payload);
  const data = Object.keys(asObject(root.data)).length ? asObject(root.data) : root;
  const aliases: Record<string, string[]> = {
    windows: ["Windows", "windows", "LIVE", "live"], mac: ["Mac", "macOS", "mac"],
    android: ["Android", "android"], ios: ["iOS", "ios"]
  };
  for (const key of aliases[platform] ?? []) {
    const value = data[key];
    const object = asObject(value);
    const version = cleanText(object.version ?? object.clientVersionUpload ?? value);
    if (version) return version;
  }
  return null;
}
