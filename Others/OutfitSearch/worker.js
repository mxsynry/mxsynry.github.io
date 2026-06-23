// Cloudflare Worker for Roblox Outfit Viewer
// Deploy this as a Worker, then paste its URL into the GitHub Pages app.
// It only calls public, read-only Roblox endpoints and never uses a .ROBLOSECURITY cookie.

const CACHE_TTL_SECONDS = 60;
const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "content-type",
  "x-content-type-options": "nosniff"
};

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") return new Response(null, { headers: JSON_HEADERS });
    const url = new URL(request.url);
    try {
      if (request.method !== "GET") return json({ error: "Only GET is supported." }, 405);
      if (url.pathname === "/" || url.pathname === "/api/health") return json({ ok: true, name: "roblox-outfit-viewer-api" });
      if (url.pathname === "/api/resolve") return cached(request, ctx, () => resolveUsers(url.searchParams.get("q") || ""));
      const reportMatch = url.pathname.match(/^\/api\/report\/(\d+)$/);
      if (reportMatch) return cached(request, ctx, () => getReport(Number(reportMatch[1])));
      const outfitMatch = url.pathname.match(/^\/api\/outfit\/(\d+)$/);
      if (outfitMatch) return cached(request, ctx, () => getOutfitDetails(Number(outfitMatch[1])));
      return json({ error: "Not found." }, 404);
    } catch (err) {
      return json({ error: err.message || String(err) }, err.status || 500);
    }
  }
};

async function cached(request, ctx, producer) {
  const cache = caches.default;
  const key = new Request(request.url, { method: "GET" });
  const hit = await cache.match(key);
  if (hit) return withCors(hit);
  const data = await producer();
  const res = json(data, 200, { "cache-control": `public, max-age=${CACHE_TTL_SECONDS}` });
  ctx.waitUntil(cache.put(key, res.clone()));
  return res;
}

function withCors(res) {
  const headers = new Headers(res.headers);
  for (const [k, v] of Object.entries(JSON_HEADERS)) headers.set(k, v);
  return new Response(res.body, { status: res.status, headers });
}

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), { status, headers: { ...JSON_HEADERS, ...extraHeaders } });
}

async function resolveUsers(rawQuery) {
  const parts = rawQuery.split(/[\n,]+/).map(s => s.trim()).filter(Boolean).slice(0, 20);
  const users = [];
  const notes = [];
  for (const part of parts) {
    const q = part.replace(/^@/, "");
    if (/^id:\s*\d+$/i.test(q) || /^\d+$/.test(q)) {
      const id = Number(q.replace(/^id:\s*/i, ""));
      users.push(await getUser(id));
      continue;
    }
    if (/^search:/i.test(q)) {
      const keyword = q.replace(/^search:\s*/i, "").trim();
      users.push(...await searchUsers(keyword, false));
      notes.push(`search:${keyword}`);
      continue;
    }
    const exact = await usersByUsernames([q]);
    users.push(...exact);
    // Extra duplicate-friendly pass: if an unusual duplicate username case exists,
    // this can surface additional accounts; otherwise exact lookup will be the main result.
    const searchMatches = await searchUsers(q, true).catch(() => []);
    users.push(...searchMatches);
  }
  return { users: uniqueBy(users, u => u.id), notes };
}

async function getReport(userId) {
  assertId(userId);
  const [profile, current, outfits, avatarThumb] = await Promise.all([
    getUser(userId),
    robloxJson(`https://avatar.roblox.com/v1/users/${userId}/currently-wearing`).catch(() => ({ assetIds: [] })),
    getOutfits(userId).catch(() => []),
    getUserAvatarThumbnails([userId]).catch(() => ({}))
  ]);
  const assetIds = (current.assetIds || []).filter(Number.isFinite);
  const [assetThumbs, assetDetails, outfitThumbs] = await Promise.all([
    getAssetThumbnails(assetIds).catch(() => ({})),
    getCatalogDetails(assetIds).catch(() => ({})),
    getOutfitThumbnails(outfits.map(o => o.id)).catch(() => ({}))
  ]);
  const currentlyWearing = assetIds.map(id => ({ id, ...(assetDetails[id] || {}), imageUrl: assetThumbs[id]?.imageUrl || null }));
  const normalizedOutfits = outfits.map(o => ({ ...o, imageUrl: outfitThumbs[o.id]?.imageUrl || null }));
  return {
    profile,
    avatarThumbnail: avatarThumb[userId] || null,
    currentlyWearing,
    outfits: normalizedOutfits,
    fetchedAt: new Date().toISOString()
  };
}

async function getOutfitDetails(outfitId) {
  assertId(outfitId);
  const detail = await robloxJson(`https://avatar.roblox.com/v3/outfits/${outfitId}/details`);
  const rawAssets = detail.assets || [];
  const ids = rawAssets.map(a => a.id).filter(Number.isFinite);
  const [thumbs, catalog] = await Promise.all([
    getAssetThumbnails(ids).catch(() => ({})),
    getCatalogDetails(ids).catch(() => ({}))
  ]);
  return {
    id: outfitId,
    name: detail.name,
    assets: rawAssets.map(a => ({ ...a, ...(catalog[a.id] || {}), imageUrl: thumbs[a.id]?.imageUrl || null })),
    bodyColors: detail.bodyColors || null,
    scale: detail.scale || null,
    playerAvatarType: detail.playerAvatarType || null,
    fetchedAt: new Date().toISOString()
  };
}

async function getUser(userId) {
  assertId(userId);
  return robloxJson(`https://users.roblox.com/v1/users/${userId}`);
}

async function usersByUsernames(usernames) {
  const data = await robloxJson("https://users.roblox.com/v1/usernames/users", {
    method: "POST",
    body: JSON.stringify({ usernames, excludeBannedUsers: false })
  });
  return data.data || [];
}

async function searchUsers(keyword, exactOnly) {
  if (!keyword) return [];
  const data = await robloxJson(`https://users.roblox.com/v1/users/search?keyword=${encodeURIComponent(keyword)}&limit=25`);
  const list = data.data || [];
  return exactOnly ? list.filter(u => (u.name || "").toLowerCase() === keyword.toLowerCase()) : list;
}

async function getOutfits(userId) {
  assertId(userId);
  const all = [];
  // The public endpoint usually returns a page of saved outfits. Try both pagination styles defensively.
  let cursor = "";
  for (let page = 1; page <= 3; page++) {
    const qs = cursor
      ? `itemsPerPage=100&cursor=${encodeURIComponent(cursor)}`
      : `itemsPerPage=100&page=${page}`;
    const data = await robloxJson(`https://avatar.roblox.com/v1/users/${userId}/outfits?${qs}`);
    all.push(...(data.data || []));
    if (data.nextPageCursor) cursor = data.nextPageCursor;
    else if (!data.data || data.data.length < 100) break;
  }
  return uniqueBy(all, o => o.id).slice(0, 300);
}

async function getUserAvatarThumbnails(userIds) {
  if (!userIds.length) return {};
  const data = await robloxJson(`https://thumbnails.roblox.com/v1/users/avatar?userIds=${userIds.join(",")}&size=420x420&format=Png&isCircular=false`);
  return mapBy(data.data || [], x => x.targetId);
}

async function getAssetThumbnails(assetIds) {
  const out = {};
  for (const chunk of chunks(unique(assetIds), 100)) {
    if (!chunk.length) continue;
    const data = await robloxJson(`https://thumbnails.roblox.com/v1/assets?assetIds=${chunk.join(",")}&returnPolicy=PlaceHolder&size=150x150&format=Png&isCircular=false`);
    Object.assign(out, mapBy(data.data || [], x => x.targetId));
  }
  return out;
}

async function getOutfitThumbnails(outfitIds) {
  const out = {};
  for (const chunk of chunks(unique(outfitIds), 100)) {
    if (!chunk.length) continue;
    const data = await robloxJson(`https://thumbnails.roblox.com/v1/users/outfits?userOutfitIds=${chunk.join(",")}&size=150x150&format=Png&isCircular=false`);
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
      });
      for (const item of data.data || []) out[item.id] = item;
    } catch (_) {
      // Fallback: slower, but keeps the app useful if catalog batch details changes.
      for (const id of chunk.slice(0, 40)) {
        try { out[id] = await robloxJson(`https://economy.roblox.com/v2/assets/${id}/details`); }
        catch { out[id] = { id, name: `Asset ${id}` }; }
      }
    }
  }
  return out;
}

async function robloxJson(url, opts = {}) {
  const method = opts.method || "GET";
  const headers = {
    "accept": "application/json",
    "content-type": "application/json",
    "user-agent": "roblox-outfit-viewer/1.0 (+public read-only)",
    ...(opts.headers || {})
  };
  const res = await fetch(url, { method, headers, body: opts.body });
  const text = await res.text();
  let data;
  try { data = text ? JSON.parse(text) : {}; } catch { data = { raw: text }; }
  if (!res.ok) {
    const msg = data.errors?.[0]?.message || data.error || data.message || `${method} ${url} failed with ${res.status}`;
    const err = new Error(msg);
    err.status = res.status === 429 ? 429 : 502;
    throw err;
  }
  return data;
}

function assertId(id) {
  if (!Number.isSafeInteger(id) || id <= 0) {
    const err = new Error("Invalid Roblox user/outfit ID.");
    err.status = 400;
    throw err;
  }
}
function unique(arr) { return [...new Set(arr.filter(Number.isFinite))]; }
function uniqueBy(arr, fn) {
  const seen = new Set();
  return arr.filter(x => {
    const k = fn(x);
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}
function mapBy(arr, fn) {
  const out = {};
  for (const item of arr) out[fn(item)] = item;
  return out;
}
function chunks(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}
