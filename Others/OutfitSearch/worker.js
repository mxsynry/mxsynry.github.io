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
          version: "2026-06-23.5",
          routes: [
            "/api/resolve?q=USERNAME",
            "/api/report/USER_ID",
            "/api/outfit/OUTFIT_ID"
          ]
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
  const res = json(data, 200, {
    "cache-control": `public, max-age=${CACHE_TTL_SECONDS}`
  });

  try {
    ctx.waitUntil(cache.put(key, res.clone()));
  } catch (_) {
    // Never break the API response because cache failed.
  }

  return res;
}

function withCors(res) {
  const headers = new Headers(res.headers);
  for (const [k, v] of Object.entries(JSON_HEADERS)) {
    headers.set(k, v);
  }

  return new Response(res.body, {
    status: res.status,
    headers
  });
}

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      ...JSON_HEADERS,
      ...extraHeaders
    }
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
    return {
      ok: true,
      users: [],
      count: 0,
      logs: ["No query entered."],
      fetchedAt: new Date().toISOString()
    };
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
      logs.push(
        exact.length
          ? `Exact username "${q}" returned ${exact.length} account(s).`
          : `Exact username "${q}" returned no accounts.`
      );

      const searchMatches = await searchUsers(q, true).catch(err => {
        logs.push(`Extra duplicate-friendly search for "${q}" failed: ${err.message}`);
        return [];
      });

      users.push(...searchMatches);

      if (searchMatches.length) {
        logs.push(`Extra search found ${searchMatches.length} exact-name match(es) for "${q}".`);
      }
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

  if (duplicatedIds.length) {
    logs.push(
      `Removed duplicate currently-wearing IDs: ${duplicatedIds
        .map(x => `${x.id} x${x.count}`)
        .join(", ")}.`
    );
  }

  const avatarAssetMap = mapBy(avatarAssets, a => a.id);

  if (avatarAssets.length) {
    const avatarNamed = avatarAssets.filter(a => {
      const name = a.name || a.Name || a.assetName || a.AssetName;
      return !isFallbackAssetName(name, a.id);
    }).length;

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
  logs.push(`Loaded ${normalizedOutfits.length} saved outfit/costume entrie(s).`);

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

  const detail = await robloxJson(
    `https://avatar.roblox.com/v3/outfits/${outfitId}/details`,
    {},
    "outfit details"
  );

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
    assets: ids.map(id => {
      const raw = rawMap[id] || {};
      const full = catalog[id] || {};

      return normalizeAsset({
        id,
        ...raw,
        ...full,
        name: pickAssetName(id, full, raw),
        imageUrl: thumbs[id]?.imageUrl || null,
        imageKind: thumbnailKind(thumbs[id]?.imageUrl || null)
      });
    }),
    bodyColors: detail.bodyColors || null,
    scale: detail.scale || null,
    playerAvatarType: detail.playerAvatarType || null,
    debug: {
      logs
    },
    fetchedAt: new Date().toISOString()
  };
}

async function getUser(userId) {
  assertId(userId, "Roblox user ID");
  return robloxJson(`https://users.roblox.com/v1/users/${userId}`, {}, "user profile");
}

async function usersByUsernames(usernames) {
  const data = await robloxJson(
    "https://users.roblox.com/v1/usernames/users",
    {
      method: "POST",
      body: JSON.stringify({
        usernames,
        excludeBannedUsers: false
      })
    },
    "username lookup"
  );

  return data.data || [];
}

async function searchUsers(keyword, exactOnly) {
  if (!keyword) return [];

  const data = await robloxJson(
    `https://users.roblox.com/v1/users/search?keyword=${encodeURIComponent(keyword)}&limit=${MAX_SEARCH_RESULTS}`,
    {},
    "user search"
  );

  const list = data.data || [];

  return exactOnly
    ? list.filter(u => (u.name || "").toLowerCase() === keyword.toLowerCase())
    : list;
}

async function getOutfits(userId) {
  assertId(userId, "Roblox user ID");

  const all = [];
  let cursor = "";

  for (let page = 1; page <= 5; page++) {
    const qs = cursor
      ? `itemsPerPage=100&cursor=${encodeURIComponent(cursor)}`
      : `itemsPerPage=100&page=${page}`;

    const data = await robloxJson(
      `https://avatar.roblox.com/v1/users/${userId}/outfits?${qs}`,
      {},
      "saved outfits"
    );

    all.push(...(data.data || []));

    if (data.nextPageCursor) {
      cursor = data.nextPageCursor;
    } else if (!data.data || data.data.length < 100) {
      break;
    }
  }

  return uniqueBy(all, o => o.id).slice(0, MAX_OUTFITS);
}

async function getUserAvatarThumbnails(userIds) {
  const ids = unique(userIds);
  if (!ids.length) return {};

  const data = await robloxJson(
    `https://thumbnails.roblox.com/v1/users/avatar?userIds=${ids.join(",")}&size=420x420&format=Png&isCircular=false`,
    {},
    "user avatar thumbnails"
  );

  return mapBy(data.data || [], x => x.targetId);
}

async function getAssetThumbnails(assetIds) {
  const out = {};

  for (const chunk of chunks(unique(assetIds), 100)) {
    if (!chunk.length) continue;

    const data = await robloxJson(
      `https://thumbnails.roblox.com/v1/assets?assetIds=${chunk.join(",")}&returnPolicy=PlaceHolder&size=150x150&format=Png&isCircular=false`,
      {},
      "asset thumbnails"
    );

    Object.assign(out, mapBy(data.data || [], x => x.targetId));
  }

  return out;
}

async function getOutfitThumbnails(outfitIds) {
  const out = {};

  for (const chunk of chunks(unique(outfitIds), 100)) {
    if (!chunk.length) continue;

    const data = await robloxJson(
      `https://thumbnails.roblox.com/v1/users/outfits?userOutfitIds=${chunk.join(",")}&size=150x150&format=Png&isCircular=false`,
      {},
      "outfit thumbnails"
    );

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
  let economyNamed = 0;
  let legacyNamed = 0;
  let missingAfterFallback = 0;

  for (const chunk of chunks(unique(assetIds), 100)) {
    if (!chunk.length) continue;

    try {
      const data = await robloxJson(
        "https://catalog.roblox.com/v1/catalog/items/details",
        {
          method: "POST",
          body: JSON.stringify({
            items: chunk.map(id => ({
              itemType: "Asset",
              id
            }))
          })
        },
        "catalog batch details"
      );

      for (const item of data.data || []) {
        const normalized = normalizeAsset({
          ...item,
          detailsSource: "catalog"
        });

        if (Number.isFinite(normalized.id)) {
          out[normalized.id] = mergeAssetDetails(out[normalized.id], normalized);

          if (!isFallbackAssetName(out[normalized.id].name, normalized.id)) {
            catalogNamed += 1;
          }
        }
      }
    } catch (err) {
      logs.push(`Catalog batch details failed for ${chunk.length} item(s): ${err.message}`);
    }

    const needsFallback = chunk.filter(id => {
      const item = out[id];

      return (
        !item ||
        isFallbackAssetName(item.name, id) ||
        !item.creatorName ||
        !getAssetTypeName(item) ||
        item.price === null ||
        item.price === undefined
      );
    });

    if (needsFallback.length) {
      const results = await Promise.allSettled(
        needsFallback.map(async id => {
          const data = await robloxJson(
            `https://economy.roblox.com/v2/assets/${id}/details`,
            {},
            `economy asset ${id}`
          );

          return normalizeAsset({
            ...data,
            id,
            detailsSource: "economy"
          });
        })
      );

      results.forEach((result, index) => {
        const id = needsFallback[index];

        if (result.status === "fulfilled") {
          out[id] = mergeAssetDetails(out[id], result.value);

          if (!isFallbackAssetName(out[id].name, id)) {
            economyNamed += 1;
          }
        } else if (!out[id]) {
          out[id] = normalizeAsset({
            id,
            name: `Asset ${id}`,
            detailsSource: "fallback"
          });
        }
      });
    }

    const needsLegacy = chunk.filter(id => {
      const item = out[id];

      return (
        !item ||
        isFallbackAssetName(item.name, id) ||
        item.price === null ||
        item.price === undefined
      );
    });

    if (needsLegacy.length) {
      const legacyResults = await Promise.allSettled(
        needsLegacy.map(async id => {
          const data = await robloxJson(
            `https://api.roblox.com/marketplace/productinfo?assetId=${id}`,
            {},
            `legacy product info ${id}`
          );

          return normalizeAsset({
            ...data,
            id,
            detailsSource: "legacy-productinfo"
          });
        })
      );

      legacyResults.forEach((result, index) => {
        const id = needsLegacy[index];

        if (result.status === "fulfilled") {
          out[id] = mergeAssetDetails(out[id], result.value);

          if (!isFallbackAssetName(out[id].name, id)) {
            legacyNamed += 1;
          }
        }
      });
    }

    for (const id of chunk) {
      if (!out[id]) {
        out[id] = normalizeAsset({
          id,
          name: `Asset ${id}`,
          detailsSource: "fallback"
        });
      }

      if (isFallbackAssetName(out[id].name, id)) {
        missingAfterFallback += 1;
      }
    }
  }

  if (assetIds.length) {
    logs.push(
      `Item detail lookup: catalog named ${catalogNamed}, economy fallback named ${economyNamed}, legacy fallback named ${legacyNamed}, still unnamed ${missingAfterFallback}.`
    );
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

  const typeName =
    item.assetType?.name ||
    item.assetType?.Name ||
    item.assetTypeName ||
    ASSET_TYPE_NAMES[rawTypeId] ||
    item.itemType ||
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
    item.RobuxPrice,
    item.lowestPrice,
    item.lowestResalePrice,
    item.LowestPrice
  );

  const lowestPrice = firstNumber(
    item.lowestPrice,
    item.lowestResalePrice,
    item.LowestPrice,
    item.resaleLowestPrice
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
    itemRestrictions.includes("LimitedUnique")
  );

  const isFree =
    price === 0 ||
    item.isPublicDomain === true ||
    item.IsPublicDomain === true ||
    String(priceStatus || "").toLowerCase() === "free";

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

  const bestType =
    extraTypeName && extraTypeName !== "Asset"
      ? extraTypeName
      : (baseTypeName || ASSET_TYPE_NAMES[rawTypeId] || "Asset");

  return {
    ...base,
    ...extra,
    id,
    name: bestName,
    creatorName:
      extra.creatorName ||
      base.creatorName ||
      extra.creator?.name ||
      base.creator?.name ||
      null,
    creatorId:
      extra.creatorId ||
      base.creatorId ||
      extra.creator?.id ||
      base.creator?.id ||
      null,
    price: extra.price ?? base.price ?? null,
    lowestPrice: extra.lowestPrice ?? base.lowestPrice ?? null,
    priceStatus: extra.priceStatus || base.priceStatus || null,
    isForSale: extra.isForSale ?? base.isForSale ?? null,
    isLimited: extra.isLimited ?? base.isLimited ?? false,
    isFree: extra.isFree ?? base.isFree ?? false,
    detailsSource: extra.detailsSource || base.detailsSource || null,
    assetType: extra.assetType || base.assetType || {
      id: Number.isFinite(rawTypeId) ? rawTypeId : undefined,
      name: bestType
    },
    assetTypeName: bestType
  };
}

function getAssetTypeName(item = {}) {
  const rawTypeId = Number(
    item.assetType?.id ||
    item.assetType?.Id ||
    item.assetTypeId ||
    item.AssetTypeId
  );

  return (
    item.assetType?.name ||
    item.assetType?.Name ||
    item.assetTypeName ||
    ASSET_TYPE_NAMES[rawTypeId] ||
    null
  );
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
    const name =
      item?.name ||
      item?.Name ||
      item?.assetName ||
      item?.AssetName;

    if (!isFallbackAssetName(name, id)) {
      return name;
    }
  }

  const typeName = getAssetTypeName(items.find(Boolean) || {});

  if (typeName && typeName !== "Asset") {
    return `${typeName} #${id}`;
  }

  return `Asset ${id}`;
}

function firstNumber(...values) {
  for (const value of values) {
    if (value === undefined || value === null || value === "") continue;

    const n = Number(value);

    if (Number.isFinite(n)) {
      return n;
    }
  }

  return null;
}

async function robloxJson(url, opts = {}, label = "Roblox API") {
  const method = opts.method || "GET";

  const headers = {
    accept: "application/json",
    ...(method !== "GET" ? { "content-type": "application/json" } : {}),
    ...(opts.headers || {})
  };

  let res;

  try {
    res = await fetch(url, {
      method,
      headers,
      body: opts.body
    });
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
    data = {
      raw: text.slice(0, 500)
    };
  }

  if (!res.ok) {
    const msg =
      data.errors?.[0]?.message ||
      data.error ||
      data.message ||
      `${method} ${url} failed with HTTP ${res.status}`;

    const err = new Error(`${label}: ${msg}`);

    err.status =
      res.status === 404
        ? 404
        : res.status === 429
          ? 429
          : 502;

    err.details = {
      robloxStatus: res.status,
      url,
      preview: typeof data.raw === "string" ? data.raw : undefined
    };

    throw err;
  }

  return data;
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

    if (k === undefined || k === null || seen.has(k)) {
      return false;
    }

    seen.add(k);
    return true;
  });
}

function mapBy(arr, fn) {
  const out = {};

  for (const item of arr) {
    const key = fn(item);

    if (key !== undefined && key !== null) {
      out[key] = item;
    }
  }

  return out;
}

function chunks(arr, size) {
  const out = [];

  for (let i = 0; i < arr.length; i += size) {
    out.push(arr.slice(i, i + size));
  }

  return out;
}

function duplicateCounts(arr) {
  const counts = new Map();

  for (const id of arr) {
    counts.set(id, (counts.get(id) || 0) + 1);
  }

  return [...counts.entries()]
    .filter(([, count]) => count > 1)
    .map(([id, count]) => ({
      id,
      count
    }));
}