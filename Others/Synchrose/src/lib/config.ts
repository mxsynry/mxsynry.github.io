const API_STORAGE_KEY = "synchrose:api-base";

export function resolveApiBase(): string {
  const meta = document.querySelector<HTMLMetaElement>(
    'meta[name="synchrose-api-base"]',
  )?.content;
  const query = new URLSearchParams(window.location.search).get("api");
  try {
    if (query === "clear") localStorage.removeItem(API_STORAGE_KEY);
    else if (query && isHttpUrl(query))
      localStorage.setItem(API_STORAGE_KEY, query.replace(/\/$/, ""));
    const stored = localStorage.getItem(API_STORAGE_KEY);
    const candidate = stored || meta || "";
    return isHttpUrl(candidate) ? candidate.replace(/\/$/, "") : "";
  } catch {
    const candidate = meta || "";
    return isHttpUrl(candidate) ? candidate.replace(/\/$/, "") : "";
  }
}

function isHttpUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}

export function endpoints(apiBase: string) {
  return {
    weaoStatus: "https://weao.xyz/api/status/exploits",
    weaoStatusFallback: "https://whatexpsare.online/api/status/exploits",
    weaoVersions: "https://weao.xyz/api/versions/current",
    weaoVersionsFallback: "https://whatexpsare.online/api/versions/current",
    voxlisCatalog: apiBase ? `${apiBase}/api/voxlis/catalog` : "",
    pulseryStatus: apiBase ? `${apiBase}/api/pulsery/status` : "",
    pulseryReviews: apiBase ? `${apiBase}/api/pulsery/reviews` : "",
    bypassCatalog: apiBase ? `${apiBase}/api/bypass/catalog` : "",
  } as const;
}
