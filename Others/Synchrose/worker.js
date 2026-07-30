// Dedicated read-only data bridge for Synchrose.
// It exposes fixed Pulsery status and approved-review routes; it is not an open proxy.

const WORKER_VERSION = "2026-07-30.1-pulsery-reviews";
const PULSERY_STATUS_URL = "https://pulsery.gg/api/status";
const PULSERY_REVIEWS_URL = "https://fsaenqbyrqbfkrvvwzwo.supabase.co/rest/v1/reviews";
const CACHE_TTL_SECONDS = 300;
const UPSTREAM_TIMEOUT_MS = 12000;
const REVIEW_EXECUTOR_PATTERN = /^[A-Za-z0-9 _-]{1,80}$/;

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "content-type",
  "access-control-max-age": "86400",
  "x-content-type-options": "nosniff"
};

const JSON_HEADERS = {
  ...CORS_HEADERS,
  "content-type": "application/json; charset=utf-8"
};

export default {
  async fetch(request, env, ctx) {
    try {
      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: CORS_HEADERS });
      }

      const url = new URL(request.url);

      if (request.method !== "GET") {
        return json({ ok: false, error: "Only GET is supported." }, 405);
      }

      if (url.pathname === "/" || url.pathname === "/api/health") {
        return json({
          ok: true,
          name: "synchrose-catalog-api",
          version: WORKER_VERSION,
          routes: [
            "/api/pulsery/status",
            "/api/pulsery/reviews?executor=NAME"
          ]
        });
      }

      if (url.pathname === "/api/pulsery/status") {
        return cacheOrRun(request, ctx, fetchPulseryStatus);
      }

      if (url.pathname === "/api/pulsery/reviews") {
        const executor = cleanText(url.searchParams.get("executor"));
        if (!REVIEW_EXECUTOR_PATTERN.test(executor)) {
          return json({ ok: false, error: "A valid executor name is required." }, 400);
        }
        return cacheOrRun(request, ctx, () => fetchPulseryReviews(executor, env));
      }

      return json({ ok: false, error: "Not found.", path: url.pathname }, 404);
    } catch (error) {
      return json({
        ok: false,
        error: error?.message || String(error),
        version: WORKER_VERSION
      }, error?.status || 500, { "cache-control": "no-store" });
    }
  }
};

async function cacheOrRun(request, ctx, producer) {
  const cache = caches.default;
  const cacheUrl = new URL(request.url);
  cacheUrl.searchParams.set("__version", WORKER_VERSION);
  const cacheKey = new Request(cacheUrl, { method: "GET" });

  try {
    const cached = await cache.match(cacheKey);
    if (cached) return withCors(cached);
  } catch {
    // Cache failure must not block public data.
  }

  const payload = await producer();
  const response = json(payload, 200, {
    "cache-control": `public, max-age=${CACHE_TTL_SECONDS}`
  });

  try {
    ctx?.waitUntil(cache.put(cacheKey, response.clone()));
  } catch {
    // Cache is optional.
  }

  return response;
}

async function fetchPulseryStatus() {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

  try {
    const response = await fetch(PULSERY_STATUS_URL, {
      method: "GET",
      headers: {
        accept: "application/json",
        "user-agent": "Synchrose/1.0 (+https://mxsynry.github.io/Others/Synchrose/)"
      },
      redirect: "follow",
      signal: controller.signal
    });

    if (!response.ok) {
      throw new Error(`Pulsery returned HTTP ${response.status}.`);
    }

    const payload = await response.json();
    if (!Array.isArray(payload?.executors)) {
      throw new Error("Pulsery returned an unexpected response.");
    }

    return {
      ok: true,
      provider: "pulsery",
      fetchedAt: new Date().toISOString(),
      executors: payload.executors.map(sanitizeExecutor).filter(Boolean)
    };
  } catch (error) {
    const message = error?.name === "AbortError"
      ? "Pulsery timed out."
      : error?.message || String(error);
    throw new ResponseError(message, 502);
  } finally {
    clearTimeout(timer);
  }
}

async function fetchPulseryReviews(executor, env) {
  const apiKey = cleanText(env?.PULSERY_SUPABASE_KEY);
  if (!apiKey) {
    throw new ResponseError("Pulsery reviews are not configured on this Worker.", 503);
  }

  const upstream = new URL(PULSERY_REVIEWS_URL);
  upstream.searchParams.set(
    "select",
    "id,executor_id,author,author_name,rating,text,content,created_at,avatar_url,status,screenshots,reply_text,reply_author,reply_at"
  );
  upstream.searchParams.set("status", "eq.approved");
  upstream.searchParams.set("executor_id", `eq.${executor}`);
  upstream.searchParams.set("order", "created_at.desc");
  upstream.searchParams.set("limit", "50");

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

  try {
    const response = await fetch(upstream, {
      method: "GET",
      headers: {
        accept: "application/json",
        apikey: apiKey,
        authorization: `Bearer ${apiKey}`,
        "user-agent": "Synchrose/1.0 (+https://mxsynry.github.io/Others/Synchrose/)"
      },
      redirect: "follow",
      signal: controller.signal
    });

    if (!response.ok) {
      throw new Error(`Pulsery reviews returned HTTP ${response.status}.`);
    }

    const payload = await response.json();
    if (!Array.isArray(payload)) {
      throw new Error("Pulsery reviews returned an unexpected response.");
    }

    return {
      ok: true,
      provider: "pulsery",
      executor,
      fetchedAt: new Date().toISOString(),
      reviews: payload.map(sanitizeReview).filter(Boolean)
    };
  } catch (error) {
    const message = error?.name === "AbortError"
      ? "Pulsery reviews timed out."
      : error?.message || String(error);
    throw new ResponseError(message, 502);
  } finally {
    clearTimeout(timer);
  }
}

function sanitizeExecutor(item) {
  const name = cleanText(item?.name);
  if (!name) return null;

  return {
    id: cleanText(item?.id),
    name,
    slug: cleanText(item?.slug),
    version: cleanText(item?.version),
    status: cleanText(item?.status),
    rating: finiteOrNull(item?.rating),
    review_count: finiteOrNull(item?.review_count),
    price_num: finiteOrNull(item?.price_num),
    price_text: cleanText(item?.price_text),
    price_cycle: cleanText(item?.price_cycle),
    lifetime_available: item?.lifetime_available === true,
    platforms: cleanList(item?.platforms),
    type: cleanText(item?.type),
    is_detected: booleanOrNull(item?.is_detected),
    is_working: booleanOrNull(item?.is_working),
    working_status: cleanText(item?.working_status),
    updated: cleanText(item?.updated),
    last_status_change: cleanText(item?.last_status_change),
    roblox_version: cleanText(item?.roblox_version),
    sunc_percent: cleanText(item?.sunc_percent),
    unc_percent: cleanText(item?.unc_percent),
    decompiler: item?.decompiler === true,
    multi_instance: item?.multi_instance === true,
    raknet: item?.raknet === true,
    myriad_score: finiteOrNull(item?.myriad_score),
    stability_score: finiteOrNull(item?.stability_score),
    safety_certified: Boolean(item?.safety_certificate),
    use_with_caution: item?.use_with_caution === true,
    developer: cleanText(item?.developer),
    description: cleanText(item?.description),
    website_url: cleanUrl(item?.website_url),
    discord_url: cleanUrl(item?.discord_url),
    purchase_url: cleanUrl(item?.purchase_url)
  };
}

function sanitizeReview(item) {
  const text = cleanText(item?.content || item?.text);
  if (!text || cleanText(item?.status).toLowerCase() !== "approved") return null;

  const rating = finiteOrNull(item?.rating);
  return {
    id: cleanText(item?.id),
    executor_id: cleanText(item?.executor_id),
    author: cleanText(item?.author_name || item?.author) || "Pulsery user",
    rating: rating === null ? null : Math.min(5, Math.max(0, rating)),
    text,
    created_at: cleanText(item?.created_at),
    avatar_url: cleanUrl(item?.avatar_url),
    screenshots: cleanUrlList(item?.screenshots).slice(0, 4),
    reply_text: cleanText(item?.reply_text),
    reply_author: cleanText(item?.reply_author),
    reply_at: cleanText(item?.reply_at)
  };
}

function cleanText(value) {
  if (value === null || value === undefined) return "";
  const text = String(value).trim();
  return text === "undefined" || text === "null" ? "" : text.slice(0, 4000);
}

function cleanList(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map(cleanText).filter(Boolean))].slice(0, 20);
}

function cleanUrlList(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map(cleanUrl).filter(Boolean))].slice(0, 8);
}

function cleanUrl(value) {
  const text = cleanText(value);
  if (!text) return "";
  try {
    const url = new URL(text);
    return url.protocol === "https:" || url.protocol === "http:" ? url.toString() : "";
  } catch {
    return "";
  }
}

function finiteOrNull(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function booleanOrNull(value) {
  return typeof value === "boolean" ? value : null;
}

function withCors(response) {
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(CORS_HEADERS)) headers.set(name, value);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers
  });
}

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...JSON_HEADERS, ...extraHeaders }
  });
}

class ResponseError extends Error {
  constructor(message, status = 500) {
    super(message);
    this.status = status;
  }
}
