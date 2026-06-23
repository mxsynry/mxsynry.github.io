const DEFAULT_API_BASE = "https://YOUR-WORKER.workers.dev";
const apiParam = new URL(location.href).searchParams.get("api");
if (apiParam) localStorage.setItem("robloxOutfitApiBase", apiParam.replace(/\/$/, ""));
let API_BASE = (localStorage.getItem("robloxOutfitApiBase") || DEFAULT_API_BASE).replace(/\/$/, "");

const $ = (sel, root = document) => root.querySelector(sel);
const results = $("#results");
const statusEl = $("#status");
const searchForm = $("#searchForm");
const queryInput = $("#query");
const searchBtn = $("#searchBtn");
const setupPanel = $("#setupPanel");
const apiBaseInput = $("#apiBaseInput");

apiBaseInput.value = API_BASE === DEFAULT_API_BASE ? "" : API_BASE;
setupPanel.style.display = API_BASE === DEFAULT_API_BASE ? "block" : "none";

$("#saveApiBtn").addEventListener("click", () => {
  const v = apiBaseInput.value.trim().replace(/\/$/, "");
  if (!/^https:\/\//i.test(v)) return setStatus("Use a full https:// Worker URL.", true);
  localStorage.setItem("robloxOutfitApiBase", v);
  API_BASE = v;
  setupPanel.style.display = "none";
  setStatus("API saved. You can search now.");
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
  if (API_BASE === DEFAULT_API_BASE) return setStatus("Set your Cloudflare Worker URL first.", true);
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
  const res = await fetch(`${API_BASE}${path}`);
  const text = await res.text();
  let data;
  try { data = text ? JSON.parse(text) : {}; } catch { data = { error: text }; }
  if (!res.ok) throw new Error(data.error || data.message || `HTTP ${res.status}`);
  return data;
}

function renderUser(report) {
  const tpl = $("#userCardTpl").content.cloneNode(true);
  const card = $(".user-card", tpl);
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
function cleanError(err) { return err?.message || String(err); }
function uniqueBy(arr, fn) {
  const seen = new Set();
  return arr.filter(x => { const k = fn(x); if (seen.has(k)) return false; seen.add(k); return true; });
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
  return String(v ?? "").replace(/[&<>'"]/g, ch => ({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;",'"':"&quot;"}[ch]));
}
function escapeAttr(v) { return escapeHtml(v).replace(/`/g, "&#96;"); }
