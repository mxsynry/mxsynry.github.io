const DEFAULT_API_BASE = "https://YOUR-WORKER.workers.dev";
const API_STORAGE_KEY = "robloxOutfitApiBase";
const LOG_STORAGE_KEY = "robloxOutfitDebugLogs";
const MAX_LOGS = 300;

const apiParam = new URL(location.href).searchParams.get("api");
if (apiParam) {
  localStorage.setItem(API_STORAGE_KEY, apiParam.trim().replace(/\/$/, ""));
}

let API_BASE = (localStorage.getItem(API_STORAGE_KEY) || DEFAULT_API_BASE).replace(/\/$/, "");
let debugLogs = loadLogs();

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
const consoleBtn = $("#consoleBtn");
const instructionsBtn = $("#instructionsBtn");
const consoleDialog = $("#consoleDialog");
const instructionsDialog = $("#instructionsDialog");
const debugConsole = $("#debugConsole");
const copyConsoleBtn = $("#copyConsoleBtn");
const clearConsoleBtn = $("#clearConsoleBtn");

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
renderConsole();
logInfo("App loaded.", { apiConfigured: hasConfiguredApi(), apiBase: hasConfiguredApi() ? API_BASE : null });

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
  logInfo("API URL saved.", { apiBase: API_BASE });

  try {
    const health = await api("/api/health");
    logSuccess("API health check succeeded.", health);
    setStatus("API saved and connected. You can search now.");
  } catch (err) {
    setupPanel.style.display = "block";
    logError("API health check failed.", err);
    setStatus(cleanError(err), true);
  }
});

changeApiBtn.addEventListener("click", () => {
  localStorage.removeItem(API_STORAGE_KEY);
  API_BASE = DEFAULT_API_BASE;
  results.innerHTML = "";
  refreshApiUi("API setting cleared. Paste your Cloudflare Worker URL again.");
  setStatus("API setting cleared. Paste your Cloudflare Worker URL again.");
  logInfo("API setting cleared.");
  apiBaseInput.focus();
});

$("#themeBtn").addEventListener("click", () => {
  document.documentElement.classList.toggle("light");
  localStorage.setItem("theme", document.documentElement.classList.contains("light") ? "light" : "dark");
});
if (localStorage.getItem("theme") === "light") document.documentElement.classList.add("light");

instructionsBtn.addEventListener("click", () => openDialog(instructionsDialog));
consoleBtn.addEventListener("click", () => {
  renderConsole();
  openDialog(consoleDialog);
});

for (const btn of document.querySelectorAll("[data-close-dialog]")) {
  btn.addEventListener("click", () => {
    const dlg = document.getElementById(btn.dataset.closeDialog);
    dlg?.close();
  });
}

copyConsoleBtn.addEventListener("click", async () => {
  const text = debugLogs.map(formatLogLine).join("\n");
  try {
    await navigator.clipboard.writeText(text || "No logs yet.");
    copyConsoleBtn.textContent = "Copied";
    setTimeout(() => copyConsoleBtn.textContent = "Copy logs", 1000);
  } catch {
    setStatus("Could not copy logs from this browser.", true);
  }
});

clearConsoleBtn.addEventListener("click", () => {
  debugLogs = [];
  saveLogs();
  renderConsole();
});

searchForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const q = queryInput.value.trim();
  if (!q) return;
  if (!hasConfiguredApi()) return setStatus("Set your Cloudflare Worker URL first.", true);

  results.innerHTML = "";
  setStatus("Resolving account(s)…");
  searchBtn.disabled = true;
  logInfo("Search started.", { query: q });

  try {
    const resolved = await api(`/api/resolve?q=${encodeURIComponent(q)}`);
    addServerLogs("resolve", resolved.logs);
    const candidates = uniqueBy((resolved.users || []), u => u.id);
    logSuccess("Resolve completed.", { count: candidates.length, users: candidates.map(u => ({ id: u.id, name: u.name, displayName: u.displayName })) });

    if (!candidates.length) {
      setStatus("No matching public Roblox users found.", true);
      logInfo("Search stopped because no users were found.");
      return;
    }

    setStatus(`Found ${candidates.length} account(s). Loading outfit data…`);

    let shown = 0;
    for (const user of candidates) {
      try {
        logInfo("Loading account report.", { id: user.id, name: user.name });
        const report = await api(`/api/report/${user.id}`);
        addServerLogs(`report:${user.id}`, report.debug?.logs);
        renderUser(report);
        shown += 1;
        logSuccess("Account report rendered.", {
          id: user.id,
          name: user.name,
          wearing: report.currentlyWearing?.length || 0,
          outfits: report.outfits?.length || 0,
          duplicateIdsRemoved: report.debug?.duplicateIds || []
        });
      } catch (err) {
        renderErrorCard(user, err);
        logError("Account report failed.", err, { id: user.id, name: user.name });
      }
    }

    setStatus(`Done. Showing ${shown} account(s).`);
  } catch (err) {
    logError("Search failed.", err);
    setStatus(cleanError(err), true);
  } finally {
    searchBtn.disabled = false;
  }
});

async function api(path) {
  const url = `${API_BASE}${path}`;
  const started = performance.now();
  logInfo("API request started.", { path, url });

  let res;
  try {
    res = await fetch(url, { method: "GET" });
  } catch (err) {
    const wrapped = new Error(`Could not connect to ${API_BASE}. Check that your Worker URL is correct and deployed.`);
    wrapped.original = err.message;
    logError("API request network error.", wrapped, { path, url });
    throw wrapped;
  }

  const text = await res.text();
  const elapsedMs = Math.round(performance.now() - started);
  let data;

  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    const preview = text.slice(0, 600).replace(/\s+/g, " ").trim();
    const htmlMessage = looksLikeGithub404(text, res)
      ? "The saved API URL is returning a GitHub Pages 404 page, not your Cloudflare Worker. Click Change API and paste your Worker URL."
      : `The API returned HTML or non-JSON instead of JSON. Status ${res.status}.`;

    const err = new Error(text.trim().startsWith("<") ? htmlMessage : `The API returned non-JSON text: ${preview.slice(0, 180)}`);
    err.status = res.status;
    err.preview = preview;
    logError("API returned non-JSON response.", err, { path, url, status: res.status, elapsedMs, preview });
    throw err;
  }

  if (!res.ok) {
    const message = data.error || data.message || data.errors?.[0]?.message || `HTTP ${res.status}`;
    const err = new Error(message);
    err.status = res.status;
    err.details = data.details || data;
    logError("API request failed.", err, { path, url, status: res.status, elapsedMs, body: compactForLog(data) });
    throw err;
  }

  logSuccess("API request succeeded.", {
    path,
    status: res.status,
    elapsedMs,
    summary: summarizeApiData(data)
  });

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
  if (report.debug?.duplicateIds?.length) chips.append(chip(`Deduped ${report.debug.duplicateIds.length} repeated ID(s)`));

  const wearing = uniqueBy((report.currentlyWearing || []), item => item.id);
  $(".wearing-count", tpl).textContent = `${wearing.length} item${wearing.length === 1 ? "" : "s"}`;
  const wearingGrid = $(".wearing-grid", tpl);
  if (!wearing.length) wearingGrid.innerHTML = `<div class="empty">No public currently-wearing assets returned.</div>`;
  for (const item of wearing) wearingGrid.append(assetCard(item));

  const outfits = report.outfits || [];
  $(".outfit-count", tpl).textContent = `${outfits.length} outfit${outfits.length === 1 ? "" : "s"}`;
  const outfitGrid = $(".outfit-grid", tpl);
  const selectedOutfit = {
    section: $(".selected-outfit-section", tpl),
    title: $(".selected-outfit-title", tpl),
    count: $(".selected-outfit-count", tpl),
    grid: $(".selected-outfit-grid", tpl)
  };
  if (!outfits.length) outfitGrid.innerHTML = `<div class="empty">No saved outfits returned, or the account has no public saved outfits.</div>`;
  for (const outfit of outfits) outfitGrid.append(outfitCard(outfit, selectedOutfit));

  $(".json-btn", tpl).addEventListener("click", () => downloadJson(`roblox-${p.id}-outfits.json`, report));
  results.append(tpl);
}

function assetCard(item) {
  const el = document.createElement("article");
  el.className = "asset";
  const id = Number(item.id);
  const rawName = item.name || item.Name || "";
  const missingName = isFallbackAssetName(rawName, id);
  if (missingName) el.classList.add("missing-name");

  const displayName = escapeHtml(missingName ? "Name unavailable" : rawName);
  const img = escapeAttr(item.imageUrl || "");
  const creator = escapeHtml(item.creatorName || item.creator?.name || item.creator?.Name || "Unknown creator");
  const price = item.price !== undefined && item.price !== null
    ? `${item.price} Robux`
    : (item.lowestPrice ? `${item.lowestPrice} Robux+` : "Price unavailable");
  const type = escapeHtml(item.assetType?.name || item.assetType?.Name || item.assetTypeName || item.itemType || "Asset");
  const source = item.detailsSource ? ` • ${escapeHtml(item.detailsSource)}` : "";
  const fallbackText = escapeHtml((missingName ? "?" : rawName).slice(0, 2).toUpperCase());

  el.innerHTML = `
    <div class="thumb-wrap">
      ${img ? `<img src="${img}" alt="${displayName}" loading="lazy">` : `<div class="no-thumb">${fallbackText}</div>`}
    </div>
    <div class="asset-body">
      <p class="item-name" title="${displayName}">${displayName}</p>
      <p class="item-meta">${type} • ID ${id}${source}</p>
      <p class="item-meta">${creator}</p>
      <p class="item-meta">${escapeHtml(price)}</p>
      <div class="item-links">
        <a target="_blank" rel="noopener" href="https://www.roblox.com/catalog/${id}">Catalog</a>
        <button class="small-btn" type="button" data-copy="${id}">Copy ID</button>
      </div>
    </div>`;

  $("[data-copy]", el).addEventListener("click", () => navigator.clipboard?.writeText(String(id)));
  return el;
}

function outfitCard(outfit, selectedOutfit) {
  const el = document.createElement("article");
  el.className = "outfit";
  const name = escapeHtml(outfit.name || `Outfit ${outfit.id}`);

  el.innerHTML = `
    <div class="thumb-wrap">
      ${outfit.imageUrl ? `<img src="${escapeAttr(outfit.imageUrl)}" alt="${name}" loading="lazy">` : `<div class="no-thumb">OUTFIT</div>`}
    </div>
    <div class="outfit-body">
      <p class="item-name" title="${name}">${name}</p>
      <p class="item-meta">Outfit ID ${outfit.id}</p>
      <div class="item-links">
        <button class="small-btn" type="button">Show items below</button>
      </div>
    </div>`;

  $("button", el).addEventListener("click", async () => {
    selectedOutfit.section.hidden = false;
    selectedOutfit.title.textContent = `${outfit.name || `Outfit ${outfit.id}`} items`;
    selectedOutfit.count.textContent = "Loading…";
    selectedOutfit.grid.innerHTML = `<div class="empty">Loading outfit items…</div>`;
    selectedOutfit.section.scrollIntoView({ behavior: "smooth", block: "start" });

    try {
      const detail = await api(`/api/outfit/${outfit.id}`);
      addServerLogs(`outfit:${outfit.id}`, detail.debug?.logs);
      const assets = uniqueBy((detail.assets || []), a => a.id);
      selectedOutfit.count.textContent = `${assets.length} item${assets.length === 1 ? "" : "s"}`;
      selectedOutfit.grid.innerHTML = "";
      if (!assets.length) {
        selectedOutfit.grid.innerHTML = `<div class="empty">No assets returned for this outfit.</div>`;
      } else {
        assets.forEach(a => selectedOutfit.grid.append(assetCard(a)));
      }
      logSuccess("Outfit items rendered.", { outfitId: outfit.id, assets: assets.length });
    } catch (err) {
      selectedOutfit.count.textContent = "Error";
      selectedOutfit.grid.innerHTML = `<div class="empty danger-text">${escapeHtml(cleanError(err))}</div>`;
      logError("Outfit items failed.", err, { outfitId: outfit.id });
    }
  });

  return el;
}

function isFallbackAssetName(name, id) {
  const s = String(name || "").trim();
  if (!s) return true;
  if (/^asset$/i.test(s)) return true;
  if (/^asset\s+\d+$/i.test(s)) return true;
  return Number.isFinite(Number(id)) && s === `Asset ${id}`;
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
    if (k === undefined || k === null || seen.has(k)) return false;
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

function openDialog(dialog) {
  if (typeof dialog.showModal === "function") dialog.showModal();
  else dialog.setAttribute("open", "");
}

function addServerLogs(scope, logs = []) {
  for (const msg of logs || []) logInfo(`Worker ${scope}: ${msg}`);
}

function logInfo(message, data = undefined) {
  pushLog("info", message, data);
}

function logSuccess(message, data = undefined) {
  pushLog("success", message, data);
}

function logError(message, err, data = undefined) {
  pushLog("error", message, {
    ...(data || {}),
    error: err?.message || String(err),
    status: err?.status,
    details: err?.details,
    preview: err?.preview,
    original: err?.original
  });
}

function pushLog(level, message, data = undefined) {
  debugLogs.push({
    time: new Date().toISOString(),
    level,
    message,
    data: compactForLog(data)
  });

  if (debugLogs.length > MAX_LOGS) debugLogs = debugLogs.slice(-MAX_LOGS);
  saveLogs();
  renderConsole();
}

function compactForLog(data) {
  if (data === undefined) return undefined;
  try {
    return JSON.parse(JSON.stringify(data, (_, value) => {
      if (typeof value === "string" && value.length > 800) return value.slice(0, 800) + "…";
      return value;
    }));
  } catch {
    return String(data);
  }
}

function summarizeApiData(data) {
  if (!data || typeof data !== "object") return data;
  return {
    ok: data.ok,
    count: data.count,
    users: Array.isArray(data.users) ? data.users.length : undefined,
    currentlyWearing: Array.isArray(data.currentlyWearing) ? data.currentlyWearing.length : undefined,
    outfits: Array.isArray(data.outfits) ? data.outfits.length : undefined,
    assets: Array.isArray(data.assets) ? data.assets.length : undefined,
    debug: data.debug ? {
      duplicateIds: data.debug.duplicateIds,
      logs: Array.isArray(data.debug.logs) ? data.debug.logs.length : undefined
    } : undefined
  };
}

function loadLogs() {
  try {
    return JSON.parse(localStorage.getItem(LOG_STORAGE_KEY) || "[]");
  } catch {
    return [];
  }
}

function saveLogs() {
  localStorage.setItem(LOG_STORAGE_KEY, JSON.stringify(debugLogs));
}

function renderConsole() {
  if (!debugConsole) return;
  debugConsole.textContent = debugLogs.length ? debugLogs.map(formatLogLine).join("\n") : "No logs yet.";
}

function formatLogLine(entry) {
  const data = entry.data === undefined ? "" : `\n${JSON.stringify(entry.data, null, 2)}`;
  return `[${entry.time}] ${entry.level.toUpperCase()} ${entry.message}${data}`;
}

function escapeHtml(v) {
  return String(v ?? "").replace(/[&<>'"]/g, ch => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[ch]));
}

function escapeAttr(v) {
  return escapeHtml(v).replace(/`/g, "&#96;");
}
