import { WORKER_VERSION, CACHE_TTL_SECONDS } from "./config.js";

export const BASE_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "content-type",
  "x-content-type-options": "nosniff",
  "referrer-policy": "no-referrer",
  "permissions-policy": "camera=(), microphone=(), geolocation=()",
  "cross-origin-resource-policy": "cross-origin",
  vary: "origin",
};
const JSON_HEADERS = {
  ...BASE_HEADERS,
  "content-type": "application/json; charset=utf-8",
};

export function withRequestMeta(response, requestId, startedAt) {
  const headers = new Headers(response.headers);
  headers.set("x-request-id", requestId);
  headers.set(
    "server-timing",
    `total;dur=${Math.max(0, Date.now() - startedAt)}`,
  );
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export async function cacheOrRun(request, ctx, producer) {
  const cache = caches.default;
  const keyUrl = `${request.url}${request.url.includes("?") ? "&" : "?"}__cacheVersion=${encodeURIComponent(WORKER_VERSION)}`;
  const key = new Request(keyUrl, { method: "GET" });

  try {
    const hit = await cache.match(key);
    if (hit) return withCors(hit);
  } catch (_) {}

  const data = await producer();
  if (data?.ok === false || data?.rateLimited) {
    return json(data, data?.rateLimited ? 429 : 500, {
      "cache-control": "no-store",
    });
  }
  const res = json(data, 200, {
    "cache-control": `public, max-age=${CACHE_TTL_SECONDS}`,
  });

  try {
    ctx.waitUntil(cache.put(key, res.clone()));
  } catch (_) {}

  return res;
}

function withCors(res) {
  const headers = new Headers(res.headers);
  for (const [k, v] of Object.entries(JSON_HEADERS)) headers.set(k, v);
  return new Response(res.body, { status: res.status, headers });
}

export function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: { ...JSON_HEADERS, ...extraHeaders },
  });
}

export function errorPayload(err, where = "api") {
  return {
    ok: false,
    error: err?.message || String(err),
    status: err?.status || 500,
    where,
    details: err?.details || undefined,
    fetchedAt: new Date().toISOString(),
  };
}
