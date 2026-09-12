import { z } from "zod";
import type { Platform, SourceRecord, SourceResult } from "../domain";
import { endpoints } from "../config";
import { cleanText, markdownText, safeUrl, trimNumber } from "../format";
import { fetchJson, mapConcurrent } from "../http";
import { asArray, asObject, normalizeType, platforms, strings, unique } from "./common";

const entrySchema = z.object({
  folder: z.unknown().optional(),
  info: z.record(z.string(), z.unknown()),
  points: z.record(z.string(), z.unknown()).optional()
}).passthrough();

const PRICE_ALIASES: Record<string, string> = {
  arceusxneo: "arceusx", matrixhub: "matrix", yubx: "yub-x", dx9warev2: "dx9ware", bunnifun: "bunni"
};

export async function fetchVoxlis(apiBase: string): Promise<SourceResult> {
  const config = endpoints(apiBase);
  const fetchedAt = new Date().toISOString();
  const pricesPayload = await fetchJson(config.voxlisPrices);
  const prices = asObject(pricesPayload);
  const slugs = discoverSlugs(prices);
  if (!slugs.length) throw new Error("Voxlis returned no catalog slugs.");
  const records = await mapConcurrent(slugs, 6, async (slug) => {
    try {
      const url = new URL(config.voxlisEntry);
      url.searchParams.set("slug", slug);
      const parsed = entrySchema.safeParse(await fetchJson(url.toString()));
      if (!parsed.success) return null;
      return normalizeVoxlisRecord(parsed.data, prices, fetchedAt);
    } catch { return null; }
  });
  const usable = records.filter((record): record is SourceRecord => Boolean(record));
  if (!usable.length) throw new Error("Voxlis returned no usable executor records.");
  return { source: "voxlis", records: usable, fetchedAt };
}

function discoverSlugs(prices: Record<string, unknown>): string[] {
  const paid = Object.keys(prices).filter((key) => key !== "freeProducts" && !key.startsWith("$"));
  const free = [prices.freeProducts, prices.$freeProducts].flatMap(asArray).map(String);
  return unique([...paid, ...free].map((value) => value.trim().toLowerCase()).filter(Boolean)).sort();
}

function normalizeVoxlisRecord(entry: z.infer<typeof entrySchema>, prices: Record<string, unknown>, fetchedAt: string): SourceRecord | null {
  const info = entry.info;
  if (info.hidden === true) return null;
  const points = entry.points || {};
  const modals = asObject(entry.modals);
  const modalWarning = asObject(modals.warning).enabled === true || asObject(modals.warningred).enabled === true;
  const name = cleanText(info.name) || cleanText(entry.folder);
  if (!name) return null;
  const productPlatforms = platforms(info.platforms ?? info.platform);
  const tags = strings(info.tags).map((tag) => tag.toLowerCase());
  const badges = strings(info.badges).map((badge) => badge.toLowerCase());
  const price = getPrice(name, productPlatforms, prices);
  const urls = asObject(info.urls);
  const pro = markdownText(points.pro_summary);
  const neutral = markdownText(points.neutral_summary);
  const con = markdownText(points.con_summary);
  return {
    source: "voxlis", sourceId: cleanText(entry.folder) || name, name, platforms: productPlatforms,
    insecure: tags.includes("insecure"), inviteOnly: tags.some(tag => tag.replace(/[-_ ]/g, "") === "inviteonly"),
    working: null, detection: "unknown",
    version: null, robloxVersion: null, price: price.label, free: price.free, sunc: null, unc: null,
    type: normalizeType(info.type), features: unique([...tags.map(titleCase), ...badges.map(titleCase), ...(info.keyed === true || tags.includes("freemium") ? ["Key system"] : info.keyed === false ? ["Keyless"] : [])]),
    description: [pro, neutral, con].filter(Boolean).join("\n\n") || null,
    links: { website: safeUrl(firstUrl(urls.website) ?? info.website ?? info.url), discord: safeUrl(firstUrl(urls.discord) ?? info.discord), purchase: price.purchase },
    warning: modalWarning || tags.includes("insecure") || badges.some((badge) => badge === "warning" || badge === "warningred"),
    sourceUpdatedAt: fetchedAt, fetchedAt
  };
}

function getPrice(name: string, productPlatforms: Platform[], prices: Record<string, unknown>): { free: boolean | null; label: string | null; purchase?: string } {
  const compactName = name.toLowerCase().replace(/[^a-z0-9]+/g, "");
  const key = PRICE_ALIASES[compactName] || compactName;
  const freeProducts = [...asArray(prices.freeProducts), ...asArray(prices.$freeProducts)].map(String);
  if (freeProducts.some((product) => product.toLowerCase() === key)) return { free: true, label: "Free" };
  const product = asObject(prices[key]);
  const offers = asArray(product.offers).map(asObject).filter((offer) => {
    const platform = cleanText(offer.platform)?.toLowerCase();
    return !platform || productPlatforms.includes(platform as Platform);
  });
  const candidates = offers.length ? offers : asArray(product.offers).map(asObject);
  const paid = candidates.filter((offer) => Number(offer.price) > 0).sort((left, right) => Number(left.price) - Number(right.price));
  const hasFree = candidates.some((offer) => Number(offer.price) === 0);
  const purchase = safeUrl(product.purchaseUrl);
  if (hasFree && paid[0]) return { free: true, label: `Free or ${formatOffer(paid[0])}`, purchase };
  if (hasFree) return { free: true, label: "Free", purchase };
  if (paid[0]) return { free: false, label: formatOffer(paid[0]), purchase };
  return { free: null, label: null, purchase };
}

function formatOffer(offer: Record<string, unknown>): string {
  const amount = Number(offer.price);
  const currency = cleanText(offer.currency) || "USD";
  const prefix = currency === "USD" ? "$" : `${currency} `;
  const base = `${prefix}${trimNumber(amount)}`;
  const days = Number(offer.days);
  if (days === -1) return `${base} lifetime`;
  if (days === 1) return `${base} daily`;
  if (days === 7) return `${base} weekly`;
  if (days === 30) return `${base} monthly`;
  return days > 0 ? `${base} / ${days} days` : base;
}

function firstUrl(value: unknown): unknown { return Array.isArray(value) ? value[0] : value; }
function titleCase(value: string): string { return value.replace(/[-_]+/g, " ").replace(/\b\w/g, (character) => character.toUpperCase()); }
