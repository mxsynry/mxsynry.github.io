import { z } from "zod";
import type { SourceRecord, SourceResult } from "../domain";
import { endpoints } from "../config";
import { cleanText, markdownText, normalizeDetection, normalizePlatform, numberOrNull, safeUrl } from "../format";
import { fetchJson } from "../http";
import { asObject, normalizeType, objectKeys, sourceTimestamp, strings, unique } from "./common";

const catalogSchema = z.record(z.string(), z.unknown());

export async function fetchInject(apiBase: string): Promise<SourceResult> {
  const config = endpoints(apiBase);
  const fetchedAt = new Date().toISOString();
  const [catalogPayload, versionsPayload] = await Promise.all([
    fetchJson(config.injectCatalog), fetchJson(config.injectVersions).catch(() => ({}))
  ]);
  const root = asObject(catalogPayload);
  const candidate = Object.keys(asObject(root.data)).length ? root.data : catalogPayload;
  const parsed = catalogSchema.safeParse(candidate);
  if (!parsed.success) throw new Error("Inject returned an unexpected catalog shape.");
  const records = Object.entries(parsed.data)
    .filter(([name]) => name && name.toLowerCase() !== "undefined")
    .flatMap(([name, item]) => normalizeInjectRecords(name, item, versionsPayload, fetchedAt));
  if (!records.length) throw new Error("Inject returned no usable executor records.");
  return { source: "inject", records, fetchedAt };
}

function normalizeInjectRecords(name: string, rawItem: unknown, versionsPayload: unknown, fetchedAt: string): SourceRecord[] {
  const item = asObject(rawItem);
  const platformNames = unique([...objectKeys(item.Platforms), ...objectKeys(item.Attributes), ...objectKeys(item.Cost), ...objectKeys(item.Tags), ...objectKeys(item.Links)]);
  return (platformNames.length ? platformNames : ["Unknown"]).map((platformName) => {
    const platform = normalizePlatform(platformName);
    const platformInfo = asObject(asObject(item.Platforms)[platformName]);
    const attributes = asObject(asObject(item.Attributes)[platformName]);
    const tags = asObject(asObject(item.Tags)[platformName]);
    const links = asObject(asObject(item.Links)[platformName]);
    const softwareVersions = asObject(platformInfo.Versions);
    const price = cleanText(asObject(item.Cost)[platformName]);
    const models = strings(attributes.PricingModel);
    const reportedRobloxVersion = cleanText(softwareVersions.Roblox);
    const currentRobloxVersion = injectVersion(versionsPayload, platform);
    const working = reportedRobloxVersion && currentRobloxVersion ? reportedRobloxVersion === currentRobloxVersion : null;
    const parent = cleanText(tags.Parent);
    const rank = cleanText(tags.Rank);
    const free = Boolean(price && /\bfree\b|freemium/i.test(price)) || models.some((model) => /^free$/i.test(model));
    return {
      source: "inject", sourceId: `${name}:${platformName}`, name, platforms: [platform], working,
      detection: normalizeDetection(platformInfo.Detection), version: cleanText(softwareVersions.Software),
      robloxVersion: reportedRobloxVersion, price, free: price || models.length ? free : null,
      sunc: null, unc: numberOrNull(attributes.UNC),
      type: /aimbot/i.test(parent || "") ? "Aimbot" : normalizeType(attributes.Type ?? parent),
      features: unique([...models, rank || "", parent || "", attributes.Decompiler === true ? "Decompiler" : "", attributes.MultipleInstance === true ? "Multi-instance" : "", attributes.Raknet === true ? "RakNet" : ""].filter(Boolean)),
      description: markdownText(attributes.About ?? attributes.Note),
      links: { website: safeUrl(links.Website), discord: safeUrl(links.Discord) },
      warning: attributes.Caution === true || attributes.Issues === true,
      sourceUpdatedAt: sourceTimestamp(platformInfo.Updated ?? platformInfo.LastUpdate, fetchedAt), fetchedAt
    };
  });
}

function injectVersion(payload: unknown, platform: string): string | null {
  const root = asObject(payload);
  const data = Object.keys(asObject(root.data)).length ? asObject(root.data) : root;
  const aliases: Record<string, string[]> = {
    windows: ["Windows", "windows", "LIVE", "live"], mac: ["Mac", "macOS", "mac"],
    android: ["Android", "android"], ios: ["iOS", "ios"]
  };
  for (const key of aliases[platform] ?? []) {
    const value = data[key];
    const nested = asObject(value);
    const version = cleanText(nested.Version ?? nested.version ?? nested.clientVersionUpload ?? value);
    if (version) return version;
  }
  return null;
}
