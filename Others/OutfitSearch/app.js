const DEFAULT_API_BASE = "https://YOUR-WORKER.workers.dev";
const API_STORAGE_KEY = "robloxOutfitApiBase";

const apiParam = new URL(location.href).searchParams.get("api");
if (apiParam) {
  localStorage.setItem(API_STORAGE_KEY, apiParam.trim().replace(/\/$/, ""));
}

let API_BASE = (localStorage.getItem(API_STORAGE_KEY) || DEFAULT_API_BASE).replace(/\/$/, "");

const $ = (sel, root = document) => root.querySelector(sel);
const results = $("#results");
const statusEl = $("#status");
const searchForm = $("#searchForm");
const queryInput = $("#query");
const searchBtn = $("#searchBtn");
const setupPanel = $("#setupPanel");
const apiBaseInput = $("#apiBaseInput");
const apiStatus = $("#apiStatus");
const changeApiBtn = $("#changeApiBtn");
const saveApiBtn = $("#saveApiBtn");

function hasConfiguredApi() {
  return API_BASE && API_BASE !== DEFAULT_API_BASE;
}

function refreshApiUi(message = "") {
  apiBaseInput.value = hasConfiguredApi() ? API_BASE : "";
  setupPanel.style.display = hasConfiguredApi() ? "none" : "block";
  changeApiBtn.style.display = hasConfiguredApi() ? "inline-flex" : "none";
  apiStatus.textContent = message || (hasConfiguredApi() ? `Saved API: ${API_BASE}` : "No API saved yet.");
}

refreshApiUi();

saveApiBtn.addEventListener("click", async () => {
  const v = apiBaseInput.value.trim().replace(/\/$/, "");

  if (!/^https:\/\//i.test(v)) {
    return setStatus("Use a full https:// Cloudflare Worker URL.", true);
  }

  if (v.includes("github.io")) {
    return setStatus("That looks like a GitHub Pages URL. Paste your Cloudflare Worker URL instead.", true);
  }

  localStorage.setItem(API_STORAGE_KEY, v);
  API_BASE = v;
  refreshApiUi("API saved. Checking connection…");

  try {
    await api("/api/health");
    setStatus("API saved and connected. You can search now.");
  } catch (err) {
    setupPanel.style.display = "block";
    setStatus(cleanError(err), true);
  }
});

changeApiBtn.addEventListener("click", () => {
  localStorage.removeItem(API_STORAGE_KEY);
  API_BASE = DEFAULT_API_BASE;
  results.innerHTML = "";
  refreshApiUi("API setting cleared. Paste your Cloudflare Worker URL again.");
  setStatus("API setting cleared. Paste your Cloudflare Worker URL again.");
  apiBaseInput.focus();
});

$("#themeBtn").addEventListener("click", () => {
  document.documentElement.classList.toggle("light");
  localStorage.setItem("theme", document.documentElement.classList.contains("light") ? "light" : "dark");
});
if (localStorage.getItem("theme") === "light") document.documentElement.classList.add("light");

searchForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const q = queryInput.value.trim();
  if (!q) return;
  if (!hasConfiguredApi()) return setStatus("Set your Cloudflare Worker URL first.", true);

  results.innerHTML = "";
  setStatus("Resolving account(s)…");
  searchBtn.disabled = true;

  try {
    const resolved = await api(`/api/resolve?q=${encodeURIComponent(q)}`);
    const candidates = uniqueBy((resolved.users || []), u => u.id);

    if (!candidates.length) {
      setStatus("No matching public Roblox users found.", true);
      return;
    }

    setStatus(`Found ${candidates.length} account(s). Loading outfit data…`);

    for (const user of candidates) {
      try {
        const report = await api(`/api/report/${user.id}`);
        renderUser(report);
      } catch (err) {
        renderErrorCard(user, err);
      }
    }

    setStatus(`Done. Showing ${candidates.length} account(s).`);
  } catch (err) {
    setStatus(cleanError(err), true);
  } finally {
    searchBtn.disabled = false;
  }
});

async function api(path) {
  const url = `${API_BASE}${path}`;
  let res;

  try {
    res = await fetch(url, { method: "GET" });
  } catch (err) {
    throw new Error(`Could not connect to ${API_BASE}. Check that your Worker URL is correct and deployed.`);
  }

  const text = await res.text();
  let data;

  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    const preview = text.slice(0, 160).replace(/\s+/g, " ");

    if (looksLikeGithub404(text, res)) {
      throw new Error("The saved API URL is returning a GitHub Pages 404 page, not your Cloudflare Worker. Click Change API and paste your Worker URL.");
    }

    if (text.trim().startsWith("<")) {
      throw new Error(`The API returned HTML instead of JSON. Your saved API URL is probably wrong: ${API_BASE}`);
    }

    throw new Error(`The API returned non-JSON text: ${preview}`);
  }

  if (!res.ok) {
    const message = data.error || data.message || data.errors?.[0]?.message || `HTTP ${res.status}`;
    throw new Error(message);
  }

  return data;
}

function looksLikeGithub404(text, res) {
  return (
    res.status === 404 &&
    (text.includes("Page not found") || text.includes("GitHub Pages") || text.includes("File not found"))
  );
}

function renderUser(report) {
  const tpl = $("#userCardTpl").content.cloneNode(true);
  const p = report.profile || {};
  const avatarUrl = report.avatarThumbnail?.imageUrl || "";

  $(".avatar-img", tpl).src = avatarUrl;
  $(".profile-title", tpl).textContent = `${p.displayName || p.name || "Unknown"} ${p.hasVerifiedBadge ? "✓" : ""}`;
  $(".profile-meta", tpl).textContent = `@${p.name || "unknown"} • ID ${p.id} • joined ${formatDate(p.created)}`;
  $(".profile-link", tpl).href = `https://www.roblox.com/users/${p.id}/profile`;
  $(".description-text", tpl).textContent = p.description || "No public description.";

  const chips = $(".chips", tpl);
  chips.append(chip(`Display: ${p.displayName || "—"}`));
  chips.append(chip(`Username: ${p.name || "—"}`));
  chips.append(chip(p.isBanned ? "Banned" : "Not banned", p.isBanned ? "bad" : "good"));
  if (report.sourceNote) chips.append(chip(report.sourceNote));

  const wearing = report.currentlyWearing || [];
  $(".wearing-count", tpl).textContent = `${wearing.length} item${wearing.length === 1 ? "" : "s"}`;
  const wearingGrid = $(".wearing-grid", tpl);
  if (!wearing.length) wearingGrid.innerHTML = `<div class="empty">No public currently-wearing assets returned.</div>`;
  for (const item of wearing) wearingGrid.append(assetCard(item));

  const outfits = report.outfits || [];
  $(".outfit-count", tpl).textContent = `${outfits.length} outfit${outfits.length === 1 ? "" : "s"}`;
  const outfitGrid = $(".outfit-grid", tpl);
  if (!outfits.length) outfitGrid.innerHTML = `<div class="empty">No saved outfits returned, or the account has no public saved outfits.</div>`;
  for (const outfit of outfits) outfitGrid.append(outfitCard(outfit));

  $(".json-btn", tpl).addEventListener("click", () => downloadJson(`roblox-${p.id}-outfits.json`, report));
  results.append(tpl);
}

function assetCard(item) {
  const el = document.createElement("article");
  el.className = "asset";
  const name = escapeHtml(item.name || `Asset ${item.id}`);
  const img = escapeAttr(item.imageUrl || "");
  const creator = escapeHtml(item.creatorName || item.creator?.name || "Unknown creator");
  const price = item.price !== undefined && item.price !== null ? `${item.price} Robux` : (item.lowestPrice ? `${item.lowestPrice} Robux+` : "Price unavailable");
  const type = escapeHtml(item.assetType?.name || item.itemType || "Asset");

  el.innerHTML = `
    <img src="${img}" alt="${name}" loading="lazy">
    <div class="asset-body">
      <p class="item-name">${name}</p>
      <p class="item-meta">${type} • ID ${item.id}</p>
      <p class="item-meta">${creator}</p>
      <p class="item-meta">${escapeHtml(price)}</p>
      <div class="item-links">
        <a target="_blank" rel="noopener" href="https://www.roblox.com/catalog/${item.id}">Catalog</a>
        <button class="small-btn" type="button" data-copy="${item.id}">Copy ID</button>
      </div>
    </div>`;

  $("[data-copy]", el).addEventListener("click", () => navigator.clipboard?.writeText(String(item.id)));
  return el;
}

function outfitCard(outfit) {
  const el = document.createElement("article");
  el.className = "outfit";
  const name = escapeHtml(outfit.name || `Outfit ${outfit.id}`);

  el.innerHTML = `
    <img src="${escapeAttr(outfit.imageUrl || "")}" alt="${name}" loading="lazy">
    <div class="outfit-body">
      <p class="item-name">${name}</p>
      <p class="item-meta">Outfit ID ${outfit.id}</p>
      <div class="item-links">
        <button class="small-btn" type="button">View items</button>
      </div>
    </div>`;

  $("button", el).addEventListener("click", async () => {
    const existing = el.nextElementSibling;
    if (existing?.classList.contains("outfit-assets")) return existing.remove();

    const box = document.createElement("div");
    box.className = "outfit-assets";
    box.textContent = "Loading outfit items…";
    el.after(box);

    try {
      const detail = await api(`/api/outfit/${outfit.id}`);
      const assets = detail.assets || [];
      box.innerHTML = `<h4>${escapeHtml(outfit.name || `Outfit ${outfit.id}`)} items (${assets.length})</h4>`;
      const grid = document.createElement("div");
      grid.className = "asset-grid";
      if (!assets.length) grid.innerHTML = `<div class="empty">No assets returned for this outfit.</div>`;
      assets.forEach(a => grid.append(assetCard(a)));
      box.append(grid);
    } catch (err) {
      box.textContent = cleanError(err);
      box.style.color = "var(--danger)";
    }
  });

  return el;
}

function renderErrorCard(user, err) {
  const el = document.createElement("article");
  el.className = "panel user-card";
  el.innerHTML = `<h2>@${escapeHtml(user.name || "unknown")} • ID ${escapeHtml(String(user.id))}</h2><p class="status error">${escapeHtml(cleanError(err))}</p>`;
  results.append(el);
}

function chip(text, kind = "") {
  const el = document.createElement("span");
  el.className = `chip ${kind}`.trim();
  el.textContent = text;
  return el;
}

function setStatus(msg, isError = false) {
  statusEl.textContent = msg || "";
  statusEl.classList.toggle("error", Boolean(isError));
}

function cleanError(err) {
  let message = err?.message || String(err);
  message = message.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
  if (message.length > 260) message = message.slice(0, 260) + "…";
  return message;
}

function uniqueBy(arr, fn) {
  const seen = new Set();
  return arr.filter(x => {
    const k = fn(x);
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

function formatDate(value) {
  if (!value) return "unknown";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "unknown";
  return d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

function downloadJson(name, data) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  a.click();
  URL.revokeObjectURL(url);
}

function escapeHtml(v) {
  return String(v ?? "").replace(/[&<>'"]/g, ch => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[ch]));
}

function escapeAttr(v) {
  return escapeHtml(v).replace(/`/g, "&#96;");
}
