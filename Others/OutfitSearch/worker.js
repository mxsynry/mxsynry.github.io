// Cloudflare Worker for Roblox Outfit Viewer
// Public, read-only Roblox API proxy. No Roblox cookies, no private tokens.

const CACHE_TTL_SECONDS = 60;
const MAX_INPUTS = 20;
const MAX_SEARCH_RESULTS = 25;
const MAX_OUTFITS = 300;

const BASE_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "content-type",
  "x-content-type-options": "nosniff"
};

const JSON_HEADERS = {
  ...BASE_HEADERS,
  "content-type": "application/json; charset=utf-8"
};

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: BASE_HEADERS });
    }

    const url = new URL(request.url);

    try {
      if (request.method !== "GET") {
        return json({ ok: false, error: "Only GET is supported." }, 405);
      }

      if (url.pathname === "/" || url.pathname === "/api/health") {
        return json({
          ok: true,
          name: "roblox-outfit-viewer-api",
          version: "2026-06-23.2",
          routes: ["/api/resolve?q=USERNAME", "/api/report/USER_ID", "/api/outfit/OUTFIT_ID"]
        });
      }

      if (url.pathname === "/api/resolve") {
        return cacheOrRun(request, ctx, () => resolveUsers(url.searchParams.get("q") || ""));
      }

      const reportMatch = url.pathname.match(/^\/api\/report\/(\d+)$/);
      if (reportMatch) {
        return cacheOrRun(request, ctx, () => getReport(Number(reportMatch[1])));
      }

      const outfitMatch = url.pathname.match(/^\/api\/outfit\/(\d+)$/);
      if (outfitMatch) {
        return cacheOrRun(request, ctx, () => getOutfitDetails(Number(outfitMatch[1])));
      }

      return json({ ok: false, error: "Not found.", path: url.pathname }, 404);
    } catch (err) {
      return json(errorPayload(err, "worker"), err.status || 500);
    }
  }
};

async function cacheOrRun(request, ctx, producer) {
  const cache = caches.default;
  const key = new Request(request.url, { method: "GET" });

  try {
    const hit = await cache.match(key);
    if (hit) return withCors(hit);
  } catch (_) {
    // Cache is helpful, not required.
  }

  const data = await producer();
  const res = json(data, 200, { "cache-control": `public, max-age=${CACHE_TTL_SECONDS}` });

  try {
    ctx.waitUntil(cache.put(key, res.clone()));
  } catch (_) {
    // Never break the API response because cache failed.
  }

  return res;
}

function withCors(res) {
  const headers = new Headers(res.headers);
  for (const [k, v] of Object.entries(JSON_HEADERS)) headers.set(k, v);
  return new Response(res.body, { status: res.status, headers });
}

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: { ...JSON_HEADERS, ...extraHeaders }
  });
}

function errorPayload(err, where = "api") {
  return {
    ok: false,
    error: err?.message || String(err),
    status: err?.status || 500,
    where,
    details: err?.details || undefined,
    fetchedAt: new Date().toISOString()
  };
}

async function resolveUsers(rawQuery) {
  const parts = rawQuery
    .split(/[\n,]+/)
    .map(s => s.trim())
    .filter(Boolean)
    .slice(0, MAX_INPUTS);

  const users = [];
  const logs = [];

  if (!parts.length) {
    return { ok: true, users: [], logs: ["No query entered."] };
  }

  for (const part of parts) {
    const q = part.replace(/^@/, "").trim();

    try {
      if (/^id:\s*\d+$/i.test(q) || /^\d+$/.test(q)) {
        const id = Number(q.replace(/^id:\s*/i, ""));
        const user = await getUser(id);
        users.push(user);
        logs.push(`Resolved exact ID ${id} -> @${user.name || "unknown"}.`);
        continue;
      }

      if (/^search:/i.test(q)) {
        const keyword = q.replace(/^search:\s*/i, "").trim();
        const found = await searchUsers(keyword, false);
        users.push(...found);
        logs.push(`Search "${keyword}" returned ${found.length} possible account(s).`);
        continue;
      }

      const exact = await usersByUsernames([q]);
      users.push(...exact);
      logs.push(exact.length ? `Exact username "${q}" returned ${exact.length} account(s).` : `Exact username "${q}" returned no accounts.`);

      const searchMatches = await searchUsers(q, true).catch(err => {
        logs.push(`Extra duplicate-friendly search for "${q}" failed: ${err.message}`);
        return [];
      });
      users.push(...searchMatches);
      if (searchMatches.length) logs.push(`Extra search found ${searchMatches.length} exact-name match(es) for "${q}".`);
    } catch (err) {
      logs.push(`Input "${part}" failed: ${err.message}`);
    }
  }

  const deduped = uniqueBy(users, u => u.id).filter(u => Number.isSafeInteger(u.id));
  return {
    ok: true,
    users: deduped,
    count: deduped.length,
    logs,
    fetchedAt: new Date().toISOString()
  };
}

async function getReport(userId) {
  assertId(userId, "Roblox user ID");
  const logs = [];

  const [profile, avatar, currently, outfits, avatarThumb] = await Promise.all([
    getUser(userId),
    robloxJson(`https://avatar.roblox.com/v1/users/${userId}/avatar`, {}, "avatar details").catch(err => {
      logs.push(`Avatar details failed: ${err.message}`);
      return { assets: [] };
    }),
    robloxJson(`https://avatar.roblox.com/v1/users/${userId}/currently-wearing`, {}, "currently wearing IDs").catch(err => {
      logs.push(`Currently-wearing IDs failed: ${err.message}`);
      return { assetIds: [] };
    }),
    getOutfits(userId).catch(err => {
      logs.push(`Saved outfits failed: ${err.message}`);
      return [];
    }),
    getUserAvatarThumbnails([userId]).catch(err => {
      logs.push(`Avatar thumbnail failed: ${err.message}`);
      return {};
    })
  ]);

  const avatarAssets = Array.isArray(avatar.assets) ? avatar.assets : [];
  const currentIdsRaw = [
    ...(currently.assetIds || []),
    ...avatarAssets.map(a => a.id)
  ].filter(Number.isFinite);

  const duplicatedIds = duplicateCounts(currentIdsRaw);
  const assetIds = unique(currentIdsRaw);
  if (duplicatedIds.length) logs.push(`Removed duplicate currently-wearing IDs: ${duplicatedIds.map(x => `${x.id} x${x.count}`).join(", ")}.`);

  const avatarAssetMap = mapBy(avatarAssets, a => a.id);
  const [assetThumbs, catalogDetails, outfitThumbs] = await Promise.all([
    getAssetThumbnails(assetIds).catch(err => {
      logs.push(`Asset thumbnails failed: ${err.message}`);
      return {};
    }),
    getCatalogDetails(assetIds).catch(err => {
      logs.push(`Catalog details failed: ${err.message}`);
      return {};
    }),
    getOutfitThumbnails(outfits.map(o => o.id)).catch(err => {
      logs.push(`Outfit thumbnails failed: ${err.message}`);
      return {};
    })
  ]);

  const currentlyWearing = assetIds.map(id => {
    const fromAvatar = avatarAssetMap[id] || {};
    const fromCatalog = catalogDetails[id] || {};
    return normalizeAsset({
      id,
      ...fromAvatar,
      ...fromCatalog,
      name: fromCatalog.name || fromAvatar.name || `Asset ${id}`,
      assetType: fromCatalog.assetType || fromAvatar.assetType || null,
      imageUrl: assetThumbs[id]?.imageUrl || null
    });
  });

  const normalizedOutfits = outfits.map(o => ({ ...o, imageUrl: outfitThumbs[o.id]?.imageUrl || null }));

  logs.push(`Loaded profile for @${profile.name || userId}.`);
  logs.push(`Loaded ${currentlyWearing.length} unique currently-wearing item(s).`);
  logs.push(`Loaded ${normalizedOutfits.length} saved outfit(s).`);

  return {
    ok: true,
    profile,
    avatarThumbnail: avatarThumb[userId] || null,
    currentlyWearing,
    outfits: normalizedOutfits,
    debug: {
      rawCurrentlyWearingCount: currentIdsRaw.length,
      uniqueCurrentlyWearingCount: assetIds.length,
      duplicateIds: duplicatedIds,
      logs
    },
    fetchedAt: new Date().toISOString()
  };
}

async function getOutfitDetails(outfitId) {
  assertId(outfitId, "Roblox outfit ID");
  const logs = [];
  const detail = await robloxJson(`https://avatar.roblox.com/v3/outfits/${outfitId}/details`, {}, "outfit details");
  const rawAssets = Array.isArray(detail.assets) ? detail.assets : [];
  const ids = unique(rawAssets.map(a => a.id).filter(Number.isFinite));
  const rawMap = mapBy(rawAssets, a => a.id);

  const [thumbs, catalog] = await Promise.all([
    getAssetThumbnails(ids).catch(err => {
      logs.push(`Outfit asset thumbnails failed: ${err.message}`);
      return {};
    }),
    getCatalogDetails(ids).catch(err => {
      logs.push(`Outfit catalog details failed: ${err.message}`);
      return {};
    })
  ]);

  return {
    ok: true,
    id: outfitId,
    name: detail.name,
    assets: ids.map(id => normalizeAsset({
      id,
      ...(rawMap[id] || {}),
      ...(catalog[id] || {}),
      name: catalog[id]?.name || rawMap[id]?.name || `Asset ${id}`,
      imageUrl: thumbs[id]?.imageUrl || null
    })),
    bodyColors: detail.bodyColors || null,
    scale: detail.scale || null,
    playerAvatarType: detail.playerAvatarType || null,
    debug: { logs },
    fetchedAt: new Date().toISOString()
  };
}

async function getUser(userId) {
  assertId(userId, "Roblox user ID");
  return robloxJson(`https://users.roblox.com/v1/users/${userId}`, {}, "user profile");
}

async function usersByUsernames(usernames) {
  const data = await robloxJson("https://users.roblox.com/v1/usernames/users", {
    method: "POST",
    body: JSON.stringify({ usernames, excludeBannedUsers: false })
  }, "username lookup");
  return data.data || [];
}

async function searchUsers(keyword, exactOnly) {
  if (!keyword) return [];
  const data = await robloxJson(`https://users.roblox.com/v1/users/search?keyword=${encodeURIComponent(keyword)}&limit=${MAX_SEARCH_RESULTS}`, {}, "user search");
  const list = data.data || [];
  return exactOnly ? list.filter(u => (u.name || "").toLowerCase() === keyword.toLowerCase()) : list;
}

async function getOutfits(userId) {
  assertId(userId, "Roblox user ID");
  const all = [];
  let cursor = "";

  for (let page = 1; page <= 5; page++) {
    const qs = cursor
      ? `itemsPerPage=100&cursor=${encodeURIComponent(cursor)}`
      : `itemsPerPage=100&page=${page}`;
    const data = await robloxJson(`https://avatar.roblox.com/v1/users/${userId}/outfits?${qs}`, {}, "saved outfits");
    all.push(...(data.data || []));

    if (data.nextPageCursor) cursor = data.nextPageCursor;
    else if (!data.data || data.data.length < 100) break;
  }

  return uniqueBy(all, o => o.id).slice(0, MAX_OUTFITS);
}

async function getUserAvatarThumbnails(userIds) {
  const ids = unique(userIds);
  if (!ids.length) return {};
  const data = await robloxJson(`https://thumbnails.roblox.com/v1/users/avatar?userIds=${ids.join(",")}&size=420x420&format=Png&isCircular=false`, {}, "user avatar thumbnails");
  return mapBy(data.data || [], x => x.targetId);
}

async function getAssetThumbnails(assetIds) {
  const out = {};
  for (const chunk of chunks(unique(assetIds), 100)) {
    if (!chunk.length) continue;
    const data = await robloxJson(`https://thumbnails.roblox.com/v1/assets?assetIds=${chunk.join(",")}&returnPolicy=PlaceHolder&size=150x150&format=Png&isCircular=false`, {}, "asset thumbnails");
    Object.assign(out, mapBy(data.data || [], x => x.targetId));
  }
  return out;
}

async function getOutfitThumbnails(outfitIds) {
  const out = {};
  for (const chunk of chunks(unique(outfitIds), 100)) {
    if (!chunk.length) continue;
    const data = await robloxJson(`https://thumbnails.roblox.com/v1/users/outfits?userOutfitIds=${chunk.join(",")}&size=150x150&format=Png&isCircular=false`, {}, "outfit thumbnails");
    Object.assign(out, mapBy(data.data || [], x => x.targetId));
  }
  return out;
}

async function getCatalogDetails(assetIds) {
  const out = {};

  for (const chunk of chunks(unique(assetIds), 100)) {
    if (!chunk.length) continue;

    try {
      const data = await robloxJson("https://catalog.roblox.com/v1/catalog/items/details", {
        method: "POST",
        body: JSON.stringify({ items: chunk.map(id => ({ itemType: "Asset", id })) })
      }, "catalog batch details");

      for (const item of data.data || []) {
        out[item.id] = normalizeAsset(item);
      }
    } catch (_) {
      // Public fallback. Slower but useful when catalog batch details rejects old/classic assets.
      await Promise.all(chunk.map(async id => {
        try {
          const data = await robloxJson(`https://economy.roblox.com/v2/assets/${id}/details`, {}, `economy asset ${id}`);
          out[id] = normalizeAsset(data);
        } catch {
          out[id] = { id, name: `Asset ${id}` };
        }
      }));
    }
  }

  return out;
}

function normalizeAsset(item) {
  const id = Number(item.id || item.assetId || item.targetId);
  const creatorName = item.creatorName || item.creatorTargetName || item.creator?.name || item.creator?.Name || null;
  const creatorId = item.creatorId || item.creatorTargetId || item.creator?.id || item.creator?.Id || null;
  const typeName = item.assetType?.name || item.assetType?.Name || item.assetTypeName || item.itemType || "Asset";

  return {
    ...item,
    id,
    name: item.name || item.Name || `Asset ${id}`,
    itemType: item.itemType || "Asset",
    assetType: item.assetType || (typeName ? { name: typeName } : null),
    creatorName,
    creatorId,
    price: item.price ?? item.PriceInRobux ?? item.priceInRobux ?? null,
    lowestPrice: item.lowestPrice ?? item.lowestResalePrice ?? null
  };
}

async function robloxJson(url, opts = {}, label = "Roblox API") {
  const method = opts.method || "GET";
  const headers = {
    "accept": "application/json",
    ...(method !== "GET" ? { "content-type": "application/json" } : {}),
    ...(opts.headers || {})
  };

  let res;
  try {
    res = await fetch(url, { method, headers, body: opts.body });
  } catch (err) {
    const e = new Error(`${label} network error: ${err.message}`);
    e.status = 502;
    throw e;
  }

  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { raw: text.slice(0, 500) };
  }

  if (!res.ok) {
    const msg = data.errors?.[0]?.message || data.error || data.message || `${method} ${url} failed with HTTP ${res.status}`;
    const err = new Error(`${label}: ${msg}`);
    err.status = res.status === 404 ? 404 : (res.status === 429 ? 429 : 502);
    err.details = { robloxStatus: res.status, url, preview: typeof data.raw === "string" ? data.raw : undefined };
    throw err;
  }

  return data;
}

function assertId(id, label = "ID") {
  if (!Number.isSafeInteger(id) || id <= 0) {
    const err = new Error(`Invalid ${label}.`);
    err.status = 400;
    throw err;
  }
}

function unique(arr) {
  return [...new Set(arr.filter(Number.isFinite))];
}

function uniqueBy(arr, fn) {
  const seen = new Set();
  return arr.filter(x => {
    const k = fn(x);
    if (k === undefined || k === null || seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

function mapBy(arr, fn) {
  const out = {};
  for (const item of arr) {
    const key = fn(item);
    if (key !== undefined && key !== null) out[key] = item;
  }
  return out;
}

function chunks(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

function duplicateCounts(arr) {
  const counts = new Map();
  for (const id of arr) counts.set(id, (counts.get(id) || 0) + 1);
  return [...counts.entries()]
    .filter(([, count]) => count > 1)
    .map(([id, count]) => ({ id, count }));
}
