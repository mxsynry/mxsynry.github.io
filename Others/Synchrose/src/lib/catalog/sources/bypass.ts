import { z } from "zod";
import type { SourceRecord, SourceResult } from "../model";
import { endpoints } from "../../config";
import {
  cleanText,
  markdownText,
  normalizeDetection,
  percentageOrNull,
  safeUrl,
} from "../../format";
import { fetchJson } from "../../http";
import { asObject, platforms, strings, unique, validTimestamp } from "./common";

const itemSchema = z.object({ name: z.string().min(1) }).passthrough();
const listSchema = z.array(z.unknown());

export async function fetchBypass(apiBase: string): Promise<SourceResult> {
  const payload = await fetchJson(endpoints(apiBase).bypassCatalog);
  const root = asObject(payload);
  const fetchedAt = validTimestamp(root.fetchedAt) ?? new Date().toISOString();
  const candidates = listSchema.parse(
    Array.isArray(payload) ? payload : root.executors,
  );
  const records = candidates.flatMap((candidate) => {
    const parsed = itemSchema.safeParse(candidate);
    return parsed.success
      ? [normalizeBypassRecord(parsed.data, fetchedAt)]
      : [];
  });
  if (!records.length)
    throw new Error("bypass.tools returned no usable executor records.");
  return { source: "bypass", records, fetchedAt };
}

function normalizeBypassRecord(
  item: z.infer<typeof itemSchema>,
  fetchedAt: string,
): SourceRecord {
  const category = cleanText(item.category) ?? "";
  const features = Array.isArray(item.features)
    ? strings(item.features)
    : (cleanText(item.features) ?? "")
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean);
  const status = cleanText(item.status)?.toLowerCase();
  const price = cleanText(item.price);
  const reportedVersion = cleanText(item.version);
  const robloxVersion =
    cleanText(item.rbx_version) ??
    (reportedVersion?.startsWith("version-") ? reportedVersion : null);
  const clientModWarning = features.some((feature) =>
    /^client mod warning$/i.test(feature),
  );
  return {
    source: "bypass",
    sourceId: cleanText(item.id) ?? item.name,
    name: item.name,
    platforms: platforms(category),
    working:
      status === "working" || status === "detected"
        ? true
        : status === "not working"
          ? false
          : null,
    detection: normalizeDetection(status),
    version:
      reportedVersion &&
      reportedVersion !== robloxVersion &&
      !reportedVersion.startsWith("version-")
        ? reportedVersion
        : null,
    robloxVersion,
    price,
    free: price === null ? null : /^free$/i.test(price),
    sunc: featurePercentage(features, "sUNC"),
    unc: featurePercentage(features, "UNC"),
    type: /external/i.test(category)
      ? "External"
      : /executor/i.test(category)
        ? "Internal"
        : null,
    features: unique([
      ...features,
      ...(item.weao_synced === true ? ["WEAO-synced"] : []),
    ]),
    description: markdownText(item.description),
    links: {
      website: safeUrl(item.website_url),
      discord: safeUrl(item.discord_url),
      purchase: safeUrl(item.purchase_url),
    },
    warning: clientModWarning,
    upstreamSource: item.weao_synced === true ? "weao" : undefined,
    sourceUpdatedAt: validTimestamp(item.updated_at),
    fetchedAt,
  };
}

function featurePercentage(
  features: string[],
  suite: "UNC" | "sUNC",
): number | null {
  const pattern = new RegExp(
    `^${suite}\\s*:?\\s*([+-]?\\d+(?:\\.\\d+)?)\\s*%$`,
    "i",
  );
  for (const feature of features) {
    const match = feature.match(pattern);
    if (match) return percentageOrNull(match[1]);
  }
  return null;
}
