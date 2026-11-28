import type { SourceResult } from "../model";
import { fetchJson } from "../../http";

type PublicCatalog = "voxlis" | "bypass";

export async function requestCatalog(
  source: PublicCatalog,
  bridgeUrl: string,
  normalize: (payload: unknown) => SourceResult,
): Promise<SourceResult> {
  const urls = [bridgeUrl];
  const origin = window.location?.origin;
  if (origin && origin !== "null") {
    urls.push(`${origin}/api/${source}/catalog`);
  }
  const failures: string[] = [];
  for (const url of new Set(urls.filter(Boolean))) {
    try {
      return normalize(await fetchJson(url));
    } catch (error) {
      failures.push(error instanceof Error ? error.message : String(error));
    }
  }

  try {
    const payload = await fetchJson(`./catalog/${source}.json`);
    const snapshot = (
      payload as { snapshot?: { source?: string; fetchedAt?: string } }
    )?.snapshot;
    if (
      snapshot?.source !== source ||
      typeof snapshot.fetchedAt !== "string" ||
      !Number.isFinite(Date.parse(snapshot.fetchedAt || ""))
    ) {
      throw new Error("Invalid saved catalog.");
    }
    const result = normalize(payload);
    return {
      ...result,
      stale: true,
      records: result.records.map((record) => ({ ...record, stale: true })),
      message: `Live bridge unavailable; showing a catalog saved on ${new Date(snapshot.fetchedAt).toISOString()}.`,
    };
  } catch {
    throw new Error(
      `${source === "voxlis" ? "Voxlis" : "bypass.tools"} could not load. ${failures.join(" ")} Deploy the current site bridge or update the configured Worker.`,
    );
  }
}
