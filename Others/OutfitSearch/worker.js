// Cloudflare Worker for Roblox Outfit Viewer
// Public, read-only Roblox API proxy. No Roblox cookies, no private tokens.

const WORKER_VERSION = "2026-07-23.2-saved-outfits-restore";
const CACHE_TTL_SECONDS = 180;
const MAX_INPUTS = 20;
const MAX_SEARCH_RESULTS = 25;
const MAX_OUTFITS = 300;
const MAX_RAW_QUERY_LENGTH = 600;
const MAX_QUERY_PART_LENGTH = 80;
const UPSTREAM_TIMEOUT_MS = 12000;

const BASE_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "content-type",
  "x-content-type-options": "nosniff",
  "referrer-policy": "no-referrer",
  "permissions-policy": "camera=(), microphone=(), geolocation=()",
  "cross-origin-resource-policy": "cross-origin",
  "vary": "origin"
};

const JSON_HEADERS = {
  ...BASE_HEADERS,
  "content-type": "application/json; charset=utf-8"
};

export default {
  async fetch(request, env, ctx) {
    const startedAt = Date.now();
    const requestId = typeof crypto?.randomUUID === "function"
      ? crypto.randomUUID()
      : `${startedAt.toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
    const finish = response => withRequestMeta(response, requestId, startedAt);

    if (request.method === "OPTIONS") {
      return finish(new Response(null, { status: 204, headers: BASE_HEADERS }));
    }

    const url = new URL(request.url);

    try {
      if (request.method !== "GET") {
        return finish(json({ ok: false, error: "Only GET is supported.", requestId }, 405));
      }

      if (url.pathname === "/" || url.pathname === "/api/health") {
        return finish(json({
          ok: true,
          name: "outfitsearch-api",
          version: WORKER_VERSION,
          requestId,
          fetchedAt: new Date().toISOString(),
          routes: ["/api/resolve?q=USERNAME", "/api/report/USER_ID", "/api/outfit/OUTFIT_ID"]
        }));
      }

      if (url.pathname === "/api/resolve") {
        return finish(await cacheOrRun(request, ctx, () => resolveUsers(url.searchParams.get("q") || "")));
      }

      const reportMatch = url.pathname.match(/^\/api\/report\/(\d+)$/);
      if (reportMatch) {
        return finish(await cacheOrRun(request, ctx, () => getReport(Number(reportMatch[1]))));
      }

      const outfitMatch = url.pathname.match(/^\/api\/outfit\/(\d+)$/);
      if (outfitMatch) {
        return finish(await cacheOrRun(request, ctx, () => getOutfitDetails(Number(outfitMatch[1]))));
      }

      return finish(json({ ok: false, error: "Not found.", path: url.pathname, requestId }, 404));
    } catch (err) {
      return finish(json({ ...errorPayload(err, "worker"), requestId }, err.status || 500));
    }
  }
};

function withRequestMeta(response, requestId, startedAt) {
  const headers = new Headers(response.headers);
  headers.set("x-request-id", requestId);
  headers.set("server-timing", `total;dur=${Math.max(0, Date.now() - startedAt)}`);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers
  });
}

async function cacheOrRun(request, ctx, producer) {
  const cache = caches.default;
  const keyUrl = `${request.url}${request.url.includes("?") ? "&" : "?"}__cacheVersion=${encodeURIComponent(WORKER_VERSION)}`;
  const key = new Request(keyUrl, { method: "GET" });

  try {
    const hit = await cache.match(key);
    if (hit) return withCors(hit);
  } catch (_) {
    // Cache is helpful, not required.
  }

  const data = await producer();
  if (data?.ok === false || data?.rateLimited) {
    return json(data, data?.rateLimited ? 429 : 500, { "cache-control": "no-store" });
  }
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
  if (rawQuery.length > MAX_RAW_QUERY_LENGTH) {
    const err = new Error(`Search input is too long. Maximum ${MAX_RAW_QUERY_LENGTH} characters.`);
    err.status = 400;
    throw err;
  }

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
    if (part.length > MAX_QUERY_PART_LENGTH) {
      logs.push(`Skipped an input longer than ${MAX_QUERY_PART_LENGTH} characters.`);
      continue;
    }
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
      logs.push(`Skipped broad duplicate-friendly search for "${q}". Use search:${q} if you want broad search results.`);
    } catch (err) {
      logs.push(`Input "${part}" failed: ${err.message}`);
      if (err.status === 429) {
        return {
          ok: false,
          rateLimited: true,
          retryAfterSeconds: err.retryAfterSeconds || 300,
          error: "Roblox is rate-limiting lookups. Wait a few minutes before searching again.",
          users: [],
          count: 0,
          logs,
          fetchedAt: new Date().toISOString()
        };
      }
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
  if (avatarAssets.length) {
    const avatarNamed = avatarAssets.filter(a => !isFallbackAssetName(a.name || a.Name || a.assetName || a.AssetName, a.id)).length;
    logs.push(`Avatar details returned ${avatarAssets.length} asset record(s), ${avatarNamed} with public names.`);
  }

  const [assetThumbs, catalogDetails, outfitThumbs] = await Promise.all([
    getAssetThumbnails(assetIds).catch(err => {
      logs.push(`Asset thumbnails failed: ${err.message}`);
      return {};
    }),
    getCatalogDetails(assetIds, logs).catch(err => {
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
      name: pickAssetName(id, fromCatalog, fromAvatar),
      assetType: fromCatalog.assetType || fromAvatar.assetType || null,
      imageUrl: assetThumbs[id]?.imageUrl || null,
      imageKind: thumbnailKind(assetThumbs[id]?.imageUrl || null)
    });
  });

  const emoteLogs = [];
  const rawEmotes = await getPublicUserEmotes(userId, avatar, emoteLogs).catch(err => {
    emoteLogs.push(`Public emote lookup failed: ${err.message}`);
    return [];
  });
  const emoteIds = unique(rawEmotes.map(e => Number(e.id || e.assetId)).filter(Number.isFinite));
  const rawEmoteMap = mapBy(rawEmotes.map(normalizeAsset), e => e.id);
  const [emoteThumbs, emoteCatalog] = await Promise.all([
    getAssetThumbnails(emoteIds).catch(err => {
      emoteLogs.push(`Emote thumbnails failed: ${err.message}`);
      return {};
    }),
    getCatalogDetails(emoteIds, emoteLogs).catch(err => {
      emoteLogs.push(`Emote catalog details failed: ${err.message}`);
      return {};
    })
  ]);
  const emotes = emoteIds.map(id => normalizeAsset({
    id,
    ...(rawEmoteMap[id] || {}),
    ...(emoteCatalog[id] || {}),
    name: pickAssetName(id, emoteCatalog[id], rawEmoteMap[id]),
    assetTypeName: "Emote Animation",
    itemType: "Emote",
    imageUrl: emoteThumbs[id]?.imageUrl || null,
    imageKind: thumbnailKind(emoteThumbs[id]?.imageUrl || null)
  }));
  if (emotes.length) logs.push(`Loaded ${emotes.length} public equipped emote(s).`);
  else logs.push(`No public equipped emotes returned. ${emoteLogs.join(" ")}`.trim());

  const normalizedOutfits = outfits.map(o => {
    const imageUrl = outfitThumbs[o.id]?.imageUrl || null;
    const imageKind = thumbnailKind(imageUrl);
    return {
      ...o,
      imageUrl,
      imageKind,
      outfitKind: imageKind && imageKind !== "Avatar" ? "Avatar costume entry" : "Saved outfit"
    };
  });

  logs.push(`Loaded profile for @${profile.name || userId}.`);
  logs.push(`Loaded ${currentlyWearing.length} unique currently-wearing item(s).`);
  logs.push(`Loaded ${emotes.length} emote item(s).`);
  logs.push(`Loaded ${normalizedOutfits.length} saved outfit(s).`);

  return {
    ok: true,
    profile,
    avatarThumbnail: avatarThumb[userId] || null,
    currentlyWearing,
    emotes,
    outfits: normalizedOutfits,
    debug: {
      rawCurrentlyWearingCount: currentIdsRaw.length,
      uniqueCurrentlyWearingCount: assetIds.length,
      duplicateIds: duplicatedIds,
      emoteLogs,
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
    getCatalogDetails(ids, logs).catch(err => {
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
      name: pickAssetName(id, catalog[id], rawMap[id]),
      imageUrl: thumbs[id]?.imageUrl || null,
      imageKind: thumbnailKind(thumbs[id]?.imageUrl || null)
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
  let v1Error = null;

  try {
    const publicOutfits = await getOutfitsV1(userId);
    if (publicOutfits.length) return publicOutfits;
  } catch (err) {
    if (err.status === 429) throw err;
    v1Error = err;
  }

  const groups = await Promise.allSettled([
    getOutfitsV2(userId, true, 5),
    getOutfitsV2(userId, false, 1)
  ]);

  const v2Outfits = groups
    .filter(result => result.status === "fulfilled")
    .flatMap(result => result.value);

  if (v2Outfits.length) {
    return uniqueBy(v2Outfits, outfit => outfit.id).slice(0, MAX_OUTFITS);
  }

  const rateLimit = groups.find(result => result.status === "rejected" && result.reason?.status === 429);
  if (rateLimit) throw rateLimit.reason;
  if (v1Error) throw v1Error;
  return [];
}

async function getOutfitsV2(userId, isEditable, maxPages) {
  const all = [];
  let paginationToken = "1";

  for (let page = 0; page < maxPages; page += 1) {
    const qs = new URLSearchParams({
      paginationToken,
      itemsPerPage: "50",
      isEditable: String(isEditable),
      outfitType: "All"
    });
    const data = await robloxJson(
      `https://avatar.roblox.com/v2/avatar/users/${userId}/outfits?${qs}`,
      {},
      `saved outfits v2 (${isEditable ? "editable" : "catalog"})`
    );
    all.push(...(data.data || []));
    paginationToken = String(data.paginationToken || "");
    if (!paginationToken || !(data.data || []).length) break;
  }

  return all;
}

async function getOutfitsV1(userId) {
  const all = [];
  let cursor = "";

  for (let page = 1; page <= 5; page++) {
    const qs = cursor
      ? `itemsPerPage=100&cursor=${encodeURIComponent(cursor)}`
      : `itemsPerPage=100&page=${page}`;
    const data = await robloxJson(`https://avatar.roblox.com/v1/users/${userId}/outfits?${qs}`, {}, "saved outfits v1 fallback");
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

const ASSET_TYPE_NAMES = {
  1: "Image",
  2: "T-Shirt",
  3: "Audio",
  4: "Mesh",
  8: "Hat",
  9: "Place",
  10: "Model",
  11: "Shirt",
  12: "Pants",
  13: "Decal",
  17: "Head",
  18: "Face",
  19: "Gear",
  21: "Badge",
  24: "Animation",
  27: "Torso",
  28: "Right Arm",
  29: "Left Arm",
  30: "Left Leg",
  31: "Right Leg",
  32: "Package",
  41: "Hair Accessory",
  42: "Face Accessory",
  43: "Neck Accessory",
  44: "Shoulder Accessory",
  45: "Front Accessory",
  46: "Back Accessory",
  47: "Waist Accessory",
  48: "Climb Animation",
  49: "Death Animation",
  50: "Fall Animation",
  51: "Idle Animation",
  52: "Jump Animation",
  53: "Run Animation",
  54: "Swim Animation",
  55: "Walk Animation",
  56: "Pose Animation",
  61: "Emote Animation",
  64: "T-Shirt Accessory",
  65: "Shirt Accessory",
  66: "Pants Accessory",
  67: "Jacket Accessory",
  68: "Sweater Accessory",
  69: "Shorts Accessory",
  70: "Left Shoe Accessory",
  71: "Right Shoe Accessory",
  72: "Dress Skirt Accessory",
  76: "Eyebrow Accessory",
  77: "Eyelash Accessory"
};

async function getCatalogDetails(assetIds, logs = []) {
  const out = {};
  let catalogNamed = 0;
  let singleCatalogNamed = 0;
  let economyNamed = 0;
  let legacyNamed = 0;
  let limitedPrices = 0;
  let missingAfterFallback = 0;
  let priced = 0;
  let offSaleOrUnknown = 0;

  for (const chunk of chunks(unique(assetIds), 100)) {
    if (!chunk.length) continue;

    try {
      const data = await robloxJson("https://catalog.roblox.com/v1/catalog/items/details", {
        method: "POST",
        body: JSON.stringify({
          items: chunk.map(id => ({ itemType: "Asset", id }))
        })
      }, "catalog batch details");

      for (const item of data.data || []) {
        const normalized = normalizeAsset({ ...item, detailsSource: "catalog-batch" });
        if (Number.isFinite(normalized.id)) {
          out[normalized.id] = mergeAssetDetails(out[normalized.id], normalized);
          if (!isFallbackAssetName(out[normalized.id].name, normalized.id)) catalogNamed += 1;
        }
      }
    } catch (err) {
      logs.push(`Catalog batch details failed for ${chunk.length} item(s): ${err.message}`);
    }

    // The batch endpoint often omits sale fields. The per-item catalog endpoint often has
    // priceStatus, collectibleItemId, itemRestrictions, purchaseCount/favoriteCount, etc.
    const needsSingleCatalog = chunk.filter(id => {
      const item = out[id];
      return !item ||
        isFallbackAssetName(item.name, id) ||
        !item.creatorName ||
        !getAssetTypeName(item) ||
        item.price === null || item.price === undefined ||
        !item.priceStatus ||
        !item.collectibleItemId;
    });

    if (needsSingleCatalog.length) {
      const results = await mapSettledLimit(needsSingleCatalog, 4, async id => {
        const data = await robloxJson(
          `https://catalog.roblox.com/v1/catalog/items/${id}/details?itemType=Asset`,
          {},
          `catalog item details ${id}`
        );
        return normalizeAsset({ ...data, id, detailsSource: "catalog-single" });
      });

      results.forEach((result, index) => {
        const id = needsSingleCatalog[index];
        if (result.status === "fulfilled") {
          out[id] = mergeAssetDetails(out[id], result.value);
          if (!isFallbackAssetName(out[id].name, id)) singleCatalogNamed += 1;
        }
      });
    }

    const needsBundle = chunk.filter(id => shouldResolveParentBundle(out[id], id));
    if (needsBundle.length) {
      const bundleMap = await getParentBundlesForAssets(needsBundle, logs);
      for (const id of needsBundle) {
        if (bundleMap[id]) {
          out[id] = mergeAssetDetails(out[id], {
            id,
            parentBundle: bundleMap[id],
            purchasableType: "Bundle",
            purchasableId: bundleMap[id].id,
            purchasableUrl: `https://www.roblox.com/bundles/${bundleMap[id].id}/${slugify(bundleMap[id].name || "bundle")}`,
            detailsSource: out[id]?.detailsSource || "bundle-parent"
          });
        }
      }
    }

    const needsEconomy = chunk.filter(id => {
      const item = out[id];
      return !item ||
        isFallbackAssetName(item.name, id) ||
        !item.creatorName ||
        !getAssetTypeName(item) ||
        item.price === null || item.price === undefined;
    });

    if (needsEconomy.length) {
      const results = await mapSettledLimit(needsEconomy, 3, async id => {
        const data = await robloxJson(`https://economy.roblox.com/v2/assets/${id}/details`, {}, `economy asset ${id}`);
        return normalizeAsset({ ...data, id, detailsSource: "economy" });
      });

      results.forEach((result, index) => {
        const id = needsEconomy[index];
        if (result.status === "fulfilled") {
          out[id] = mergeAssetDetails(out[id], result.value);
          if (!isFallbackAssetName(out[id].name, id)) economyNamed += 1;
        } else if (!out[id]) {
          out[id] = normalizeAsset({ id, name: `Asset ${id}`, detailsSource: "fallback" });
        }
      });
    }

    // Limited / collectible items use collectibleItemId. Resellers endpoint gives current
    // resale listings; lowest listing is a better display than "Price unavailable".
    const collectible = chunk
      .map(id => out[id])
      .filter(item => item?.collectibleItemId && (item.lowestPrice === null || item.lowestPrice === undefined));

    if (collectible.length) {
      const results = await mapSettledLimit(collectible, 3, async item => {
        const data = await robloxJson(
          `https://apis.roblox.com/marketplace-sales/v1/item/${encodeURIComponent(item.collectibleItemId)}/resellers?limit=10`,
          {},
          `collectible resellers ${item.id}`
        );
        const prices = (data.data || [])
          .map(x => Number(x.price || x.Price))
          .filter(Number.isFinite);
        const lowest = prices.length ? Math.min(...prices) : null;
        return { id: item.id, lowestPrice: lowest, resaleLowestPrice: lowest, resaleListings: prices.length, detailsSource: "marketplace-sales" };
      });

      results.forEach((result) => {
        if (result.status === "fulfilled" && Number.isFinite(result.value.lowestPrice)) {
          out[result.value.id] = mergeAssetDetails(out[result.value.id], result.value);
          limitedPrices += 1;
        }
      });
    }

    const needsLegacy = chunk.filter(id => {
      const item = out[id];
      return !item ||
        isFallbackAssetName(item.name, id) ||
        item.price === null || item.price === undefined;
    });

    if (needsLegacy.length) {
      const legacyResults = await mapSettledLimit(needsLegacy, 3, async id => {
        const data = await robloxJson(`https://api.roblox.com/marketplace/productinfo?assetId=${id}`, {}, `legacy product info ${id}`);
        return normalizeAsset({ ...data, id, detailsSource: "legacy-productinfo" });
      });

      legacyResults.forEach((result, index) => {
        const id = needsLegacy[index];
        if (result.status === "fulfilled") {
          out[id] = mergeAssetDetails(out[id], result.value);
          if (!isFallbackAssetName(out[id].name, id)) legacyNamed += 1;
        }
      });
    }

    for (const id of chunk) {
      if (!out[id]) {
        out[id] = normalizeAsset({ id, name: `Asset ${id}`, detailsSource: "fallback" });
      }

      if (isFallbackAssetName(out[id].name, id)) missingAfterFallback += 1;
      if (Number.isFinite(Number(out[id].price)) || Number.isFinite(Number(out[id].lowestPrice))) priced += 1;
      else offSaleOrUnknown += 1;
    }
  }

  if (assetIds.length) {
    logs.push(`Item detail lookup: batch named ${catalogNamed}, single named ${singleCatalogNamed}, economy named ${economyNamed}, legacy named ${legacyNamed}, limited resale prices ${limitedPrices}, priced ${priced}, off-sale/unknown ${offSaleOrUnknown}, still unnamed ${missingAfterFallback}.`);
  }

  return out;
}

function normalizeAsset(item = {}) {
  const id = Number(item.id || item.Id || item.assetId || item.AssetId || item.targetId);

  const creatorName =
    item.creatorName ||
    item.creatorTargetName ||
    item.creator?.name ||
    item.creator?.Name ||
    item.Creator?.Name ||
    item.creator?.creatorName ||
    null;

  const creatorId =
    item.creatorId ||
    item.creatorTargetId ||
    item.creator?.id ||
    item.creator?.Id ||
    item.Creator?.Id ||
    item.creator?.creatorId ||
    null;

  const rawTypeId = Number(
    item.assetTypeId ||
    item.AssetTypeId ||
    item.assetType?.id ||
    item.assetType?.Id
  );

  const assetTypeValue = typeof item.assetType === "string" ? item.assetType : "";
  const typeName =
    item.assetType?.name ||
    item.assetType?.Name ||
    assetTypeValue ||
    item.assetTypeName ||
    item.AssetTypeName ||
    item.assetTypeDisplayName ||
    item.AssetTypeDisplayName ||
    ASSET_TYPE_NAMES[rawTypeId] ||
    (item.itemType && item.itemType !== "Asset" ? item.itemType : "") ||
    "Asset";

  const rawName =
    item.name ||
    item.Name ||
    item.assetName ||
    item.AssetName ||
    "";

  const price = firstNumber(
    item.price,
    item.Price,
    item.priceInRobux,
    item.PriceInRobux,
    item.robuxPrice,
    item.RobuxPrice
  );

  const lowestPrice = firstPositiveNumber(
    item.lowestPrice,
    item.lowestResalePrice,
    item.LowestPrice,
    item.resaleLowestPrice,
    item.lowestAvailablePrice,
    item.minimumPrice,
    item.MinimumPrice
  );

  const priceStatus =
    item.priceStatus ||
    item.PriceStatus ||
    item.saleStatus ||
    item.SaleStatus ||
    null;

  const isForSale =
    item.isForSale ??
    item.IsForSale ??
    item.forSale ??
    item.ForSale ??
    null;

  const itemRestrictions = Array.isArray(item.itemRestrictions)
    ? item.itemRestrictions
    : [];

  const isLimited = Boolean(
    item.isLimited ||
    item.IsLimited ||
    item.isLimitedUnique ||
    item.IsLimitedUnique ||
    itemRestrictions.includes("Limited") ||
    itemRestrictions.includes("LimitedUnique") ||
    item.collectibleItemId
  );

  // Do not use isPublicDomain/IsPublicDomain as a price signal. Roblox can mark
  // some public assets this way even when they are not actually free catalog items.
  const isFree =
    price === 0 ||
    String(priceStatus || "").trim().toLowerCase() === "free";

  return {
    ...item,
    id,
    name: rawName || `Asset ${id}`,
    itemType: item.itemType || "Asset",
    assetType: item.assetType || {
      id: Number.isFinite(rawTypeId) ? rawTypeId : undefined,
      name: typeName
    },
    assetTypeName: typeName,
    creatorName,
    creatorId,
    price,
    lowestPrice,
    priceStatus,
    isForSale,
    isLimited,
    isFree,
    collectibleItemId: item.collectibleItemId || item.CollectibleItemId || null,
    collectibleProductId: item.collectibleProductId || item.CollectibleProductId || null,
    parentBundle: item.parentBundle || item.ParentBundle || null,
    purchasableType: item.purchasableType || item.PurchasableType || null,
    purchasableId: item.purchasableId || item.PurchasableId || null,
    purchasableUrl: item.purchasableUrl || item.PurchasableUrl || null,
    itemRestrictions,
    detailsSource: item.detailsSource || item.source || null
  };
}

function mergeAssetDetails(base = {}, extra = {}) {
  const id = Number(extra.id || base.id);
  const baseName = base.name || base.Name;
  const extraName = extra.name || extra.Name;

  const bestName = !isFallbackAssetName(extraName, id)
    ? extraName
    : (!isFallbackAssetName(baseName, id) ? baseName : `Asset ${id}`);

  const extraTypeName = getAssetTypeName(extra);
  const baseTypeName = getAssetTypeName(base);
  const rawTypeId = Number(
    extra.assetType?.id ||
    extra.assetType?.Id ||
    extra.assetTypeId ||
    extra.AssetTypeId ||
    base.assetType?.id ||
    base.assetType?.Id ||
    base.assetTypeId ||
    base.AssetTypeId
  );

  const bestType = extraTypeName && extraTypeName !== "Asset"
    ? extraTypeName
    : (baseTypeName || ASSET_TYPE_NAMES[rawTypeId] || "Asset");

  return {
    ...base,
    ...extra,
    id,
    name: bestName,
    creatorName: extra.creatorName || base.creatorName || extra.creator?.name || base.creator?.name || null,
    creatorId: extra.creatorId || base.creatorId || extra.creator?.id || base.creator?.id || null,
    price: extra.price ?? base.price ?? null,
    lowestPrice: extra.lowestPrice ?? base.lowestPrice ?? extra.resaleLowestPrice ?? base.resaleLowestPrice ?? null,
    resaleLowestPrice: extra.resaleLowestPrice ?? base.resaleLowestPrice ?? null,
    resaleListings: extra.resaleListings ?? base.resaleListings ?? null,
    priceStatus: extra.priceStatus || base.priceStatus || null,
    isForSale: extra.isForSale ?? base.isForSale ?? null,
    isLimited: extra.isLimited ?? base.isLimited ?? false,
    isFree: extra.isFree ?? base.isFree ?? false,
    collectibleItemId: extra.collectibleItemId || base.collectibleItemId || null,
    collectibleProductId: extra.collectibleProductId || base.collectibleProductId || null,
    parentBundle: extra.parentBundle || base.parentBundle || null,
    purchasableType: extra.purchasableType || base.purchasableType || null,
    purchasableId: extra.purchasableId || base.purchasableId || null,
    purchasableUrl: extra.purchasableUrl || base.purchasableUrl || null,
    itemRestrictions: extra.itemRestrictions || base.itemRestrictions || [],
    detailsSource: extra.detailsSource || base.detailsSource || null,
    assetType: extra.assetType || base.assetType || {
      id: Number.isFinite(rawTypeId) ? rawTypeId : undefined,
      name: bestType
    },
    assetTypeName: bestType
  };
}

function firstNumber(...values) {
  for (const value of values) {
    if (value === undefined || value === null || value === "") continue;
    const n = Number(value);
    if (Number.isFinite(n)) return n;
  }
  return null;
}

function firstPositiveNumber(...values) {
  for (const value of values) {
    if (value === undefined || value === null || value === "") continue;
    const n = Number(value);
    if (Number.isFinite(n) && n > 0) return n;
  }
  return null;
}

function getAssetTypeName(item = {}) {
  const rawTypeId = Number(item.assetType?.id || item.assetType?.Id || item.assetTypeId || item.AssetTypeId);
  const assetTypeValue = typeof item.assetType === "string" ? item.assetType : "";
  return item.assetType?.name ||
    item.assetType?.Name ||
    assetTypeValue ||
    item.assetTypeName ||
    item.AssetTypeName ||
    item.assetTypeDisplayName ||
    item.AssetTypeDisplayName ||
    ASSET_TYPE_NAMES[rawTypeId] ||
    null;
}

function isFallbackAssetName(name, id) {
  const s = String(name || "").trim();
  if (!s) return true;
  if (/^asset$/i.test(s)) return true;
  if (/^asset\s+\d+$/i.test(s)) return true;
  return Number.isFinite(Number(id)) && s === `Asset ${id}`;
}

function pickAssetName(id, ...items) {
  for (const item of items) {
    const name = item?.name || item?.Name || item?.assetName || item?.AssetName;
    if (!isFallbackAssetName(name, id)) return name;
  }
  return `Asset ${id}`;
}


async function getPublicUserEmotes(userId, avatarPayload = {}, logs = []) {
  const fromAvatar = extractEmotesFromPayload(avatarPayload);
  if (fromAvatar.length) {
    logs.push(`Avatar payload returned ${fromAvatar.length} emote record(s).`);
    return fromAvatar;
  }

  const candidateUrls = [
    `https://avatar.roblox.com/v1/users/${userId}/emotes`,
    `https://avatar.roblox.com/v1/users/${userId}/emotes?includeAssetIds=true`
  ];

  for (const url of candidateUrls) {
    try {
      const data = await robloxJson(url, {}, "user emotes");
      const found = extractEmotesFromPayload(data);
      if (found.length) {
        logs.push(`Public emote endpoint returned ${found.length} emote record(s).`);
        return found;
      }
      logs.push(`Public emote endpoint responded but contained no emote list.`);
    } catch (err) {
      logs.push(`Public emote endpoint unavailable: ${err.message}`);
    }
  }

  return [];
}

function extractEmotesFromPayload(payload = {}) {
  const out = [];

  const pushMaybe = (value, slot = null) => {
    if (!value) return;
    if (typeof value === "number" || typeof value === "string") {
      const id = Number(value);
      if (Number.isFinite(id)) out.push({ id, assetId: id, slot, assetTypeName: "Emote Animation", itemType: "Emote" });
      return;
    }
    const id = Number(value.id || value.assetId || value.AssetId || value.emoteAssetId || value.EmoteAssetId);
    if (Number.isFinite(id)) {
      out.push({
        ...value,
        id,
        assetId: id,
        slot: value.slot ?? value.position ?? value.Position ?? slot,
        assetTypeName: value.assetTypeName || value.AssetTypeName || "Emote Animation",
        itemType: "Emote"
      });
    }
  };

  const candidates = [payload.emotes, payload.Emotes, payload.data, payload.equippedEmotes, payload.equippedEmoteAssets];
  for (const candidate of candidates) {
    if (Array.isArray(candidate)) candidate.forEach(pushMaybe);
    else if (candidate && typeof candidate === "object") {
      for (const [slot, value] of Object.entries(candidate)) pushMaybe(value, slot);
    }
  }

  return uniqueBy(out, e => Number(e.id || e.assetId));
}

function shouldResolveParentBundle(item, id) {
  if (!item) return true;
  if (item.parentBundle || item.purchasableType === "Bundle") return false;
  const type = String(getAssetTypeName(item) || item.assetTypeName || "");
  const name = String(item.name || "");
  return /DynamicHead|MoodAnimation|ClimbAnimation|DeathAnimation|FallAnimation|IdleAnimation|JumpAnimation|RunAnimation|SwimAnimation|WalkAnimation|PoseAnimation|Torso|Right Arm|Left Arm|Left Leg|Right Leg|Head/i.test(type)
    || /Animation Pack|Animation Package|Dynamic Head|Recolorable|Bundle|Package/i.test(name);
}

async function getParentBundlesForAssets(assetIds, logs = []) {
  const out = {};
  const bundleIds = new Set();
  const assetToBundleId = {};

  const results = await mapSettledLimit(unique(assetIds), 4, async id => {
    const data = await robloxJson(
      `https://catalog.roblox.com/v1/assets/${id}/bundles?limit=10&sortOrder=Asc`,
      {},
      `asset bundles ${id}`
    );
    const bundles = data.data || [];
    const best = chooseBestBundle(bundles);
    if (best?.id) {
      assetToBundleId[id] = Number(best.id);
      bundleIds.add(Number(best.id));
    }
  });

  const rejected = results.filter(r => r.status === "rejected").length;
  if (rejected) logs.push(`Bundle parent lookup failed for ${rejected} asset(s).`);

  const details = await getBundleDetails([...bundleIds], logs);
  for (const [assetId, bundleId] of Object.entries(assetToBundleId)) {
    if (details[bundleId]) out[Number(assetId)] = details[bundleId];
  }

  if (Object.keys(out).length) logs.push(`Resolved ${Object.keys(out).length} asset component(s) to parent bundle(s).`);
  return out;
}

function chooseBestBundle(bundles = []) {
  if (!bundles.length) return null;
  return bundles.find(b => /Animation|DynamicHead|Dynamic Head|Avatar|Body|Package|Bundle/i.test(`${b.name || ""} ${b.bundleType || ""}`)) || bundles[0];
}

async function getBundleDetails(bundleIds, logs = []) {
  const out = {};
  const uniqueIds = unique(bundleIds);
  if (!uniqueIds.length) return out;

  const results = await Promise.allSettled(uniqueIds.map(async id => {
    const data = await robloxJson(
      `https://catalog.roblox.com/v1/bundles/${id}/details`,
      {},
      `bundle details ${id}`
    );
    return normalizeBundle(data);
  }));

  results.forEach((result, index) => {
    if (result.status === "fulfilled" && result.value?.id) {
      out[result.value.id] = result.value;
    } else if (result.status === "rejected") {
      logs.push(`Bundle details failed for ${uniqueIds[index]}: ${result.reason?.message || result.reason}`);
    }
  });

  return out;
}

function normalizeBundle(bundle = {}) {
  const product = bundle.product || bundle.Product || {};
  const creator = bundle.creator || bundle.Creator || {};
  const id = Number(bundle.id || bundle.Id || bundle.bundleId || bundle.BundleId);
  const name = firstNonEmptyString(bundle.name, bundle.Name, bundle.bundleName, bundle.BundleName) || `Bundle ${id}`;
  const price = firstNumber(
    bundle.price,
    bundle.Price,
    bundle.priceInRobux,
    bundle.PriceInRobux,
    product.priceInRobux,
    product.PriceInRobux,
    product.price,
    product.Price
  );
  const lowestPrice = firstNumber(bundle.lowestPrice, bundle.lowestResalePrice, product.lowestPrice, product.lowestResalePrice);
  const isForSale = bundle.isForSale ?? bundle.IsForSale ?? product.isForSale ?? product.IsForSale ?? null;
  const isFree = price === 0;
  const creatorName = firstNonEmptyString(
    bundle.creatorName,
    bundle.CreatorName,
    creator.name,
    creator.Name,
    creator.creatorName,
    creator.CreatorName
  );
  const creatorId = firstNumber(
    bundle.creatorId,
    bundle.CreatorId,
    creator.id,
    creator.Id,
    creator.creatorId,
    creator.CreatorId
  );
  const bundleType = firstNonEmptyString(bundle.bundleType, bundle.BundleType, bundle.type, bundle.Type);
  return {
    id,
    name,
    bundleType: bundleType || null,
    creatorName: creatorName || null,
    creatorId: creatorId ?? null,
    price,
    lowestPrice,
    isForSale,
    isFree,
    description: bundle.description || bundle.Description || "",
    productId: product.id || product.Id || product.productId || product.ProductId || null,
    url: `https://www.roblox.com/bundles/${id}/${slugify(name)}`,
    detailsSource: "bundle-details"
  };
}

function firstNonEmptyString(...values) {
  for (const value of values) {
    const s = String(value ?? "").trim();
    if (s) return s;
  }
  return "";
}

function slugify(value) {
  return String(value || "bundle")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "bundle";
}

async function robloxJson(url, opts = {}, label = "Roblox API") {
  const method = opts.method || "GET";
  const headers = {
    "accept": "application/json",
    ...(method !== "GET" ? { "content-type": "application/json" } : {}),
    ...(opts.headers || {})
  };

  const maxAttempts = method === "GET" ? 2 : 1;
  let lastErr = null;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    let res;
    let text;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
    try {
      res = await fetch(url, { method, headers, body: opts.body, signal: controller.signal });
      text = await res.text();
    } catch (err) {
      const timedOut = controller.signal.aborted;
      const e = new Error(timedOut
        ? `${label} timed out after ${Math.round(UPSTREAM_TIMEOUT_MS / 1000)} seconds`
        : `${label} network error: ${err.message}`);
      e.status = timedOut ? 504 : 502;
      throw e;
    } finally {
      clearTimeout(timeoutId);
    }

    let data;
    try {
      data = text ? JSON.parse(text) : {};
    } catch {
      data = { raw: text.slice(0, 500) };
    }

    if (res.ok) return data;

    const msg = data.errors?.[0]?.message || data.error || data.message || `${method} ${url} failed with HTTP ${res.status}`;
    const err = new Error(`${label}: ${msg}`);
    err.status = res.status === 404 ? 404 : (res.status === 429 ? 429 : 502);
    err.retryAfterSeconds = Number(res.headers.get("retry-after")) || undefined;
    err.details = { robloxStatus: res.status, url, preview: typeof data.raw === "string" ? data.raw : undefined };
    lastErr = err;

    if (method !== "GET" || res.status === 429 || ![500, 502, 503, 504].includes(res.status) || attempt === maxAttempts) {
      throw err;
    }

    const waitMs = 350 * attempt;
    await delay(waitMs);
  }

  throw lastErr || new Error(`${label}: request failed`);
}

async function mapSettledLimit(items, limit, mapper) {
  const input = Array.from(items || []);
  const results = new Array(input.length);
  let next = 0;

  async function worker() {
    while (next < input.length) {
      const index = next++;
      try {
        results[index] = { status: "fulfilled", value: await mapper(input[index], index) };
      } catch (reason) {
        results[index] = { status: "rejected", reason };
      }
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, input.length) }, worker));
  return results;
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function thumbnailKind(imageUrl) {
  const m = String(imageUrl || "").match(/\/\d+\/\d+\/([^/]+)\/Png/i);
  return m ? m[1] : null;
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