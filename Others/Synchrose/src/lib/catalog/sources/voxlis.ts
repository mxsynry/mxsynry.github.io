import { z } from "zod";
import type { Platform, SourceRecord, SourceResult } from "../model";
import { endpoints } from "../../config";
import {
  booleanOrNull,
  cleanText,
  markdownText,
  numberOrNull,
  percentageOrNull,
  safeUrl,
} from "../../format";
import { fetchJson } from "../../http";
import {
  asArray,
  asObject,
  normalizeType,
  platforms,
  strings,
  unique,
  validTimestamp,
} from "./common";

const catalogSchema = z.object({ cards: z.array(z.unknown()) }).passthrough();
const cardSchema = z
  .object({ slug: z.string().min(1), title: z.string().min(1) })
  .passthrough();

export async function fetchVoxlis(apiBase: string): Promise<SourceResult> {
  const payload = catalogSchema.parse(
    await fetchJson(endpoints(apiBase).voxlisCatalog),
  );
  const fetchedAt =
    validTimestamp(payload.bridgeFetchedAt) ?? new Date().toISOString();
  const records = payload.cards.flatMap((candidate) => {
    const parsed = cardSchema.safeParse(candidate);
    if (!parsed.success) return [];
    const card = parsed.data;
    const variants = asArray(card.variants);
    return (variants.length ? variants : [card]).map((variant) =>
      normalizeVariant(card, asObject(variant), payload, fetchedAt),
    );
  });
  if (!records.length)
    throw new Error("Voxlis returned no usable directory records.");
  return {
    source: "voxlis",
    records,
    fetchedAt,
    stale: payload.stale === true,
  };
}

function normalizeVariant(
  card: z.infer<typeof cardSchema>,
  variant: Record<string, unknown>,
  payload: Record<string, unknown>,
  fetchedAt: string,
): SourceRecord {
  const productPlatforms = platforms(variant.platform);
  const pricing = asObject(variant.pricing);
  const access = cleanText(pricing.access)?.toLowerCase();
  const free =
    access === "free"
      ? true
      : access === "paid"
        ? false
        : booleanOrNull(pricing.free);
  const sunc = asObject(variant.sunc);
  const metadata = asObject(sunc.metadata);
  const audit = asObject(asObject(variant.myriad).audit);
  const tags = strings(card.tags);
  const status = cleanText(variant.status)?.toLowerCase();
  return {
    source: "voxlis",
    sourceId: `${card.slug}:${cleanText(variant.id) ?? `${productPlatforms[0]}:${cleanText(variant.type) ?? "unknown"}`}`,
    name: card.title,
    platforms: productPlatforms,
    insecure: card.insecure === true,
    inviteOnly: card.inviteOnly === true,
    working: status === "updated" ? true : status === "outdated" ? false : null,
    detection: "unknown",
    // The directory's version field is the targeted Roblox build, not an executor release.
    version: null,
    robloxVersion: cleanText(variant.version),
    price:
      cleanText(pricing.label) ??
      (free === true ? "Free" : free === false ? "Paid" : null),
    free,
    sunc: percentageOrNull(sunc.score),
    unc: null,
    suncDetails: Object.keys(metadata).length
      ? {
          suiteVersion: cleanText(metadata.version),
          executor: cleanText(metadata.executor),
          testedAt: validTimestamp(metadata.testedAt),
        }
      : undefined,
    myriad: audit.kind === "v" ? percentageOrNull(audit.rating) : null,
    myriadDetails:
      audit.kind === "v"
        ? {
            category: "vulnerabilities",
            url: safeUrl(audit.url),
            executorVersion: cleanText(audit.executorVersion),
            testedAt: validTimestamp(audit.generated),
            checked: numberOrNull(audit.checked),
            secured: numberOrNull(audit.secured),
            vulnerable: numberOrNull(audit.vulnerable),
            ambiguous: numberOrNull(audit.ambiguous),
            excluded: numberOrNull(audit.excluded),
          }
        : undefined,
    type: normalizeType(variant.type),
    features: unique([
      ...tags,
      ...strings(card.badges),
      ...(card.keyed === true ||
      tags.includes("freemium") ||
      tags.includes("keysystem")
        ? ["Key system"]
        : card.keyed === false
          ? ["Keyless"]
          : []),
    ]),
    description: markdownText(card.description),
    reviewNotes: markdownText(variant.review),
    links: {
      website: firstSafeUrl(variant.websiteUrls),
      discord: firstSafeUrl(variant.discordUrls),
      purchase: safeUrl(pricing.purchaseUrl),
    },
    warning: card.warning === true || card.insecure === true,
    sourceUpdatedAt: latestUpdate(card.updateHistory, productPlatforms),
    sourceCheckedAt: validTimestamp(payload.checkedAt),
    stale: payload.stale === true,
    fetchedAt,
  };
}

function latestUpdate(
  history: unknown,
  productPlatforms: Platform[],
): string | null {
  return (
    asArray(history)
      .map(asObject)
      .filter((entry) =>
        platforms(entry.platform).some((platform) =>
          productPlatforms.includes(platform),
        ),
      )
      .map((entry) => validTimestamp(entry.updatedAt))
      .filter((value): value is string => Boolean(value))
      .sort()
      .at(-1) ?? null
  );
}

function firstSafeUrl(value: unknown): string | undefined {
  return asArray(value)
    .map(safeUrl)
    .find((url): url is string => Boolean(url));
}
