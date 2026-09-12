import { z } from "zod";
import type { SourceRecord, SourceResult } from "../domain";
import { endpoints } from "../config";
import { booleanOrNull, cleanText, normalizeDetection, numberOrNull, safeUrl } from "../format";
import { fetchJson } from "../http";
import { asArray, asObject, normalizeType, platforms, sourceTimestamp, unique } from "./common";

const itemSchema = z.object({ name: z.unknown() }).passthrough();

export async function fetchPulsery(apiBase: string): Promise<SourceResult> {
  const fetchedAt = new Date().toISOString();
  const payload = await fetchJson(endpoints(apiBase).pulseryStatus);
  const root = asObject(payload);
  const data = asObject(root.data);
  const candidates = asArray(root.executors).length ? asArray(root.executors) : asArray(data.executors);
  const records = candidates
    .map((candidate) => itemSchema.safeParse(candidate))
    .filter((result) => result.success)
    .map((result) => normalizePulseryRecord(result.data, fetchedAt))
    .filter((record): record is SourceRecord => Boolean(record));
  if (!records.length) throw new Error("Pulsery returned no usable executor records.");
  return { source: "pulsery", records, fetchedAt };
}

function normalizePulseryRecord(item: z.infer<typeof itemSchema>, fetchedAt: string): SourceRecord | null {
  const name = cleanText(item.name);
  if (!name) return null;
  const statusText = cleanText(item.status)?.toLowerCase() || "";
  const clientModOnly = /client[\s-]*mod/.test(statusText);
  const price = cleanText(item.price_text);
  const numericPrice = numberOrNull(item.price_num);
  const free = numericPrice === 0 || Boolean(price && /\bfree\b|freemium/i.test(price));
  const features = unique([
    item.decompiler === true ? "Decompiler" : "",
    item.multi_instance === true ? "Multi-instance" : "",
    item.raknet === true ? "RakNet" : "",
    item.safety_certified === true ? "Verified" : ""
  ].filter(Boolean));
  return {
    source: "pulsery", sourceId: cleanText(item.id) || name, name, platforms: platforms(item.platforms),
    working: booleanOrNull(item.is_working),
    detection: clientModOnly ? "client-mod-only" : normalizeDetection(booleanOrNull(item.is_detected) ?? statusText),
    version: cleanText(item.version), robloxVersion: cleanText(item.roblox_version),
    price: price || (free ? "Free" : numericPrice !== null ? String(numericPrice) : null),
    free: price || numericPrice !== null ? free : null,
    sunc: numberOrNull(item.sunc_percent), unc: numberOrNull(item.unc_percent), type: normalizeType(item.type),
    features, description: cleanText(item.description),
    links: { website: safeUrl(item.website_url), discord: safeUrl(item.discord_url), purchase: safeUrl(item.purchase_url) },
    warning: item.use_with_caution === true,
    sourceUpdatedAt: sourceTimestamp(item.updated ?? item.last_status_change, fetchedAt), fetchedAt
  };
}
