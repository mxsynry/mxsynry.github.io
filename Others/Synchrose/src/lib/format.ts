import type { Detection, DetectionConsensus, Platform, WorkingConsensus } from "./domain";

export const PLATFORM_LABELS: Record<Platform, string> = {
  windows: "Windows",
  mac: "macOS",
  android: "Android",
  ios: "iOS",
  unknown: "Unknown"
};

export const STATUS_LABELS: Record<WorkingConsensus, string> = {
  working: "Working",
  broken: "Outdated",
  mixed: "Mixed reports",
  unknown: "Unknown"
};

export const DETECTION_LABELS: Record<DetectionConsensus, string> = {
  undetected: "Undetected",
  "client-mod-only": "Client-mod bypass",
  detected: "Detected",
  mixed: "Mixed reports",
  unknown: "Unknown"
};

export function normalizePlatform(value: unknown): Platform {
  const text = String(value ?? "").trim().toLowerCase();
  if (/windows|win64|uwp/.test(text)) return "windows";
  if (/mac|osx|darwin/.test(text)) return "mac";
  if (/android/.test(text)) return "android";
  if (/ios|iphone|ipad/.test(text)) return "ios";
  return "unknown";
}

export function normalizeDetection(value: unknown): Detection {
  if (typeof value === "boolean") return value ? "detected" : "undetected";
  const text = String(value ?? "").trim().toLowerCase();
  if (/client[\s_-]*mod/.test(text)) return "client-mod-only";
  if (/\bundetected\b|not detected|^safe$/.test(text)) return "undetected";
  if (/detected|banwave|unsafe/.test(text)) return "detected";
  return "unknown";
}

export function cleanText(value: unknown): string | null {
  const text = String(value ?? "").replace(/\u0000/g, "").replace(/\s+/g, " ").trim();
  return text && !/^(n\/?a|unknown|null|undefined)$/i.test(text) ? text : null;
}

export function markdownText(value: unknown): string | null {
  return typeof value === "string" ? value.replace(/\u0000/g, "").trim() || null : null;
}

export function numberOrNull(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(String(value).replace("%", ""));
  return Number.isFinite(parsed) ? parsed : null;
}

export function booleanOrNull(value: unknown): boolean | null {
  if (typeof value === "boolean") return value;
  if (value === 1 || String(value).toLowerCase() === "true") return true;
  if (value === 0 || String(value).toLowerCase() === "false") return false;
  return null;
}

export function safeUrl(value: unknown): string | undefined {
  const text = cleanText(value);
  if (!text) return undefined;
  try {
    const url = new URL(text);
    return url.protocol === "https:" || url.protocol === "http:" ? url.toString() : undefined;
  } catch {
    return undefined;
  }
}

export function formatTime(value: string | null): string {
  if (!value) return "Never";
  const date = new Date(value);
  if (!Number.isFinite(date.valueOf())) return "Unknown";
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(date);
}

export function formatSunc(range: { min: number; max: number } | null): string {
  if (!range) return "—";
  if (range.min === range.max) return `${trimNumber(range.max)}%`;
  return `${trimNumber(range.min)}–${trimNumber(range.max)}%`;
}

export function trimNumber(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(1).replace(/\.0$/, "");
}
