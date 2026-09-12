import type { Platform } from "../domain";
import { cleanText, normalizePlatform } from "../format";

export function asObject(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

export function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export function strings(value: unknown): string[] {
  if (!Array.isArray(value)) return cleanText(value) ? [cleanText(value)!] : [];
  return value.map(cleanText).filter((item): item is string => Boolean(item));
}

export function unique<T>(values: T[]): T[] {
  return [...new Set(values)];
}

export function platforms(value: unknown): Platform[] {
  const normalized = unique(strings(value).map(normalizePlatform));
  return normalized.length ? normalized : ["unknown"];
}

export function normalizeType(value: unknown): string | null {
  const text = cleanText(value)?.toLowerCase();
  if (!text) return null;
  if (/server[\s-]*side/.test(text)) return "Server-side";
  if (/external|aimbot/.test(text)) return /aimbot/.test(text) ? "Aimbot" : "External";
  if (/internal|executor/.test(text)) return "Internal";
  return text.replace(/\b\w/g, (character) => character.toUpperCase());
}

export function objectKeys(value: unknown): string[] {
  return Object.keys(asObject(value));
}

export function sourceTimestamp(value: unknown, fallback: string): string | null {
  const text = cleanText(value);
  if (!text) return fallback;
  const date = new Date(text);
  return Number.isFinite(date.valueOf()) ? date.toISOString() : text;
}
