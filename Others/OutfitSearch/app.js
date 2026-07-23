const DEFAULT_API_BASE = document.querySelector('meta[name="outfit-api-base"]')?.content?.trim() || "";
const API_STORAGE_KEY = "robloxOutfitApiBase";
const LOG_STORAGE_KEY = "robloxOutfitDebugLogs";
const LAZY_LOAD_STORAGE_KEY = "robloxOutfitLazyLoading";
const THEME_STORAGE_KEY = "robloxOutfitTheme";
const MAX_LOGS = 300;
const PREFETCH_LIMIT = 24;
const PREFETCH_DELAY_MS = 275;
const SEARCH_CONCURRENCY = 3;
const API_TIMEOUT_MS = 30000;

const outfitDetailCache = new Map();

const apiParam = new URL(location.href).searchParams.get("api");
if (apiParam) {
  localStorage.setItem(API_STORAGE_KEY, apiParam.trim().replace(/\/$/, ""));
}

let API_BASE = (apiParam || localStorage.getItem(API_STORAGE_KEY) || DEFAULT_API_BASE).trim().replace(/\/$/, "");
let debugLogs = loadLogs();
let activeSearchController = null;
let apiConnectionState = hasConfiguredApi() ? "saved" : "offline";

const $ = (sel, root = document) => root.querySelector(sel);
const results = $("#results");
const statusEl = $("#status");
const statusWrap = $("#statusWrap");
const resultProgress = $("#resultProgress");
const emptyState = $("#emptyState");
const searchForm = $("#searchForm");
const queryInput = $("#query");
const searchBtn = $("#searchBtn");
const clearQueryBtn = $("#clearQueryBtn");
const cancelSearchBtn = $("#cancelSearchBtn");
const apiBaseInput = $("#apiBaseInput");
const apiStatus = $("#apiStatus");
const apiDialog = $("#apiDialog");
const apiDot = $("#apiDot");
const apiState = $("#apiState");
const apiButtonLabel = $("#apiButtonLabel");
const changeApiBtn = $("#changeApiBtn");
const saveApiBtn = $("#saveApiBtn");
const clearApiBtn = $("#clearApiBtn");
const openGuideBtn = $("#openGuideBtn");
const consoleBtn = $("#consoleBtn");
const instructionsBtn = $("#instructionsBtn");
const consoleDialog = $("#consoleDialog");
const instructionsDialog = $("#instructionsDialog");
const outfitDialog = $("#outfitDialog");
const debugConsole = $("#debugConsole");
const copyConsoleBtn = $("#copyConsoleBtn");
const clearConsoleBtn = $("#clearConsoleBtn");
const copyLinkBtn = $("#copyLinkBtn");
const lazyLoadToggle = $("#lazyLoadToggle");
const themeBtn = $("#themeBtn");
applyTheme(getSavedTheme());

function hasConfiguredApi() {
  return Boolean(API_BASE);
}

function refreshApiUi(message = "", state = apiConnectionState) {
  apiConnectionState = state;
  apiBaseInput.value = hasConfiguredApi() ? API_BASE : "";
  apiDot.className = `status-dot${state === "online" ? " online" : state === "error" ? " error" : ""}`;
  apiState.className = `connection-state${state === "online" ? " online" : state === "error" ? " error" : ""}`;
  apiButtonLabel.textContent = hasConfiguredApi() ? "API setup" : "Connect API";
  apiState.textContent = state === "online"
    ? "API connected"
    : state === "error"
      ? "API connection failed"
      : hasConfiguredApi()
        ? "API URL saved"
        : "API not connected";
  apiStatus.textContent = message || (hasConfiguredApi() ? `Saved: ${API_BASE}` : "No Worker URL saved in this browser.");
}

refreshApiUi();
initLazyLoadingOption();
renderConsole();
logInfo("App loaded.", {
  apiConfigured: hasConfiguredApi(),
  apiBase: hasConfiguredApi() ? API_BASE : null,
  lazyLoading: isLazyLoadingEnabled()
});

saveApiBtn.addEventListener("click", async () => {
  const v = apiBaseInput.value.trim().replace(/\/$/, "");

  if (!/^https:\/\//i.test(v)) {
    apiStatus.textContent = "Use the full https:// URL.";
    return;
  }

  if (v.includes("github.io")) {
    apiStatus.textContent = "That is the page URL. Paste the Cloudflare Worker URL instead.";
    return;
  }

  localStorage.setItem(API_STORAGE_KEY, v);
  API_BASE = v;
  saveApiBtn.disabled = true;
  saveApiBtn.textContent = "Checking…";
  refreshApiUi("Checking the Worker…", "saved");
  logInfo("API URL saved.", { apiBase: API_BASE });

  try {
    const health = await api("/api/health", { timeoutMs: 9000 });
    logSuccess("API health check succeeded.", health);
    refreshApiUi(`Connected · Worker ${health.version || "ready"}`, "online");
    setStatus("API connected. Search whenever you’re ready.");
    setTimeout(() => apiDialog.close(), 350);
  } catch (err) {
    logError("API health check failed.", err);
    refreshApiUi(cleanError(err), "error");
  } finally {
    saveApiBtn.disabled = false;
    saveApiBtn.textContent = "Connect";
  }
});

changeApiBtn.addEventListener("click", () => {
  refreshApiUi();
  openDialog(apiDialog);
  setTimeout(() => apiBaseInput.focus(), 60);
});

clearApiBtn.addEventListener("click", () => {
  localStorage.removeItem(API_STORAGE_KEY);
  API_BASE = "";
  outfitDetailCache.clear();
  results.innerHTML = "";
  emptyState.hidden = false;
  refreshApiUi("Saved URL removed.", "offline");
  setStatus("API URL removed. Connect a Worker before searching.");
  logInfo("API setting cleared.");
  apiBaseInput.focus();
});

openGuideBtn.addEventListener("click", () => {
  apiDialog.close();
  openDialog(instructionsDialog);
});

themeBtn?.addEventListener("click", () => {
  const nextTheme = document.documentElement.classList.contains("light") ? "dark" : "light";
  applyTheme(nextTheme);
  localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
  localStorage.setItem("theme", nextTheme);
  logInfo("Theme changed.", { theme: nextTheme });
});

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

for (const dialog of document.querySelectorAll("dialog")) {
  dialog.addEventListener("click", event => {
    if (event.target === dialog) dialog.close();
  });
}

copyConsoleBtn.addEventListener("click", async () => {
  const text = debugLogs.map(formatLogLine).join("\n");
  try {
    await navigator.clipboard.writeText(text || "No logs yet.");
    copyConsoleBtn.textContent = "Copied";
    setTimeout(() => copyConsoleBtn.textContent = "Copy", 1000);
  } catch {
    setStatus("Could not copy logs from this browser.", true);
  }
});

clearConsoleBtn.addEventListener("click", () => {
  debugLogs = [];
  saveLogs();
  renderConsole();
});

lazyLoadToggle?.addEventListener("change", () => {
  localStorage.setItem(LAZY_LOAD_STORAGE_KEY, lazyLoadToggle.checked ? "on" : "off");
  logInfo("Lazy loading option changed.", { lazyLoading: lazyLoadToggle.checked });
  setStatus(lazyLoadToggle.checked
    ? "Lazy loading enabled. Outfit items load only when clicked."
    : "Lazy loading disabled. Outfit details will be prefetched after each search.");
});

copyLinkBtn?.addEventListener("click", async () => {
  const q = queryInput.value.trim();
  const url = buildShareUrl(q).toString();
  try {
    await navigator.clipboard.writeText(url);
    copyLinkBtn.textContent = "Copied link";
    setTimeout(() => copyLinkBtn.textContent = "Copy search link", 1100);
    logSuccess("Search link copied.", { url });
  } catch {
    setStatus(`Share link: ${url}`, false);
  }
});

for (const chip of document.querySelectorAll("[data-example]")) {
  chip.addEventListener("click", () => {
    queryInput.value = chip.dataset.example || "";
    queryInput.focus();
  });
}

clearQueryBtn.addEventListener("click", () => {
  queryInput.value = "";
  queryInput.focus();
});

cancelSearchBtn.addEventListener("click", () => activeSearchController?.abort());

searchForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const q = queryInput.value.trim();
  if (!q) return;
  updateUrlForSearch(q);
  if (!hasConfiguredApi()) {
    setStatus("Connect the included Cloudflare Worker first.", true);
    openDialog(apiDialog);
    return;
  }

  activeSearchController?.abort();
  const controller = new AbortController();
  activeSearchController = controller;
  results.innerHTML = "";
  emptyState.hidden = true;
  setStatus("Finding Roblox account(s)…", false, { loading: true });
  searchBtn.disabled = true;
  cancelSearchBtn.hidden = false;
  logInfo("Search started.", { query: q });

  try {
    const resolved = await api(`/api/resolve?q=${encodeURIComponent(q)}`, { signal: controller.signal });
    addServerLogs("resolve", resolved.logs);
    const candidates = uniqueBy((resolved.users || []), u => u.id);
    logSuccess("Resolve completed.", { count: candidates.length, users: candidates.map(u => ({ id: u.id, name: u.name, displayName: u.displayName })) });

    if (!candidates.length) {
      setStatus("No public Roblox accounts matched that search.", true);
      emptyState.hidden = false;
      logInfo("Search stopped because no users were found.");
      return;
    }

    const slots = candidates.map((user, index) => createSkeletonSlot(user, index));
    slots.forEach(slot => results.append(slot));
    setStatus(`Found ${candidates.length}. Loading avatar data…`, false, {
      loading: true,
      progress: `0 / ${candidates.length}`
    });
    let shown = 0;
    let finished = 0;

    await mapLimit(candidates, SEARCH_CONCURRENCY, async (user, index) => {
      try {
        logInfo("Loading account report.", { id: user.id, name: user.name });
        const report = await api(`/api/report/${user.id}`, { signal: controller.signal });
        addServerLogs(`report:${user.id}`, report.debug?.logs);
        renderUser(report, slots[index], index);
        shown += 1;
        logSuccess("Account report rendered.", {
          id: user.id,
          name: user.name,
          wearing: report.currentlyWearing?.length || 0,
          outfits: report.outfits?.length || 0,
          duplicateIdsRemoved: report.debug?.duplicateIds || []
        });
      } catch (err) {
        if (err.name === "AbortError") throw err;
        renderErrorCard(user, err, slots[index]);
        logError("Account report failed.", err, { id: user.id, name: user.name });
      } finally {
        finished += 1;
        if (!controller.signal.aborted) {
          setStatus("Loading account data…", false, {
            loading: finished < candidates.length,
            progress: `${finished} / ${candidates.length}`
          });
        }
      }
    });

    setStatus(`Loaded ${shown} of ${candidates.length} account${candidates.length === 1 ? "" : "s"}.`, false, {
      progress: `${shown} shown`
    });
  } catch (err) {
    if (err.name === "AbortError") {
      logInfo("Search cancelled.", { query: q });
      results.querySelectorAll(".skeleton-card").forEach(card => card.closest(".result-slot")?.remove());
      setStatus("Search cancelled.");
      return;
    }
    logError("Search failed.", err);
    setStatus(cleanError(err), true);
  } finally {
    if (activeSearchController === controller) {
      activeSearchController = null;
      searchBtn.disabled = false;
      cancelSearchBtn.hidden = true;
    }
  }
});

const initialQuery = getInitialQueryFromUrl();
if (initialQuery) {
  queryInput.value = initialQuery;
  setStatus(`Ready to search: ${initialQuery}`);
  logInfo("Query loaded from URL.", { query: initialQuery });
  if (hasConfiguredApi()) {
    setTimeout(() => searchForm.requestSubmit(), 80);
  } else {
    setStatus("Search link loaded. Connect the Worker to run it.");
  }
}

if (hasConfiguredApi()) {
  verifyApiConnection();
}

async function verifyApiConnection() {
  try {
    const health = await api("/api/health", { timeoutMs: 7000 });
    refreshApiUi(`Connected · Worker ${health.version || "ready"}`, "online");
  } catch (err) {
    refreshApiUi(cleanError(err), "error");
    logError("Startup API check failed.", err);
  }
}

async function api(path, options = {}) {
  const url = `${API_BASE}${path}`;
  const started = performance.now();
  logInfo("API request started.", { path, url });

  const requestController = new AbortController();
  const timeoutMs = options.timeoutMs || API_TIMEOUT_MS;
  const timeoutId = setTimeout(() => requestController.abort("timeout"), timeoutMs);
  const abortFromParent = () => requestController.abort("cancelled");
  if (options.signal) {
    if (options.signal.aborted) abortFromParent();
    else options.signal.addEventListener("abort", abortFromParent, { once: true });
  }

  let res;
  try {
    res = await fetch(url, { method: "GET", signal: requestController.signal });
  } catch (err) {
    if (options.signal?.aborted) {
      const cancelled = new Error("Search cancelled.");
      cancelled.name = "AbortError";
      throw cancelled;
    }
    if (requestController.signal.aborted) {
      const timedOut = new Error(`The API took longer than ${Math.round(timeoutMs / 1000)} seconds.`);
      timedOut.status = 504;
      logError("API request timed out.", timedOut, { path, url, timeoutMs });
      throw timedOut;
    }
    const wrapped = new Error(`Could not connect to ${API_BASE}. Check that your Worker URL is correct and deployed.`);
    wrapped.original = err.message;
    logError("API request network error.", wrapped, { path, url });
    throw wrapped;
  } finally {
    clearTimeout(timeoutId);
    options.signal?.removeEventListener("abort", abortFromParent);
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


async function getOutfitDetail(outfitId) {
  const key = String(outfitId);
  if (outfitDetailCache.has(key)) {
    const cached = outfitDetailCache.get(key);
    logInfo("Outfit detail cache hit.", { outfitId });
    return cached;
  }

  const detail = await api(`/api/outfit/${outfitId}`);
  addServerLogs(`outfit:${outfitId}`, detail.debug?.logs);
  outfitDetailCache.set(key, detail);
  return detail;
}

async function prefetchOutfitDetails(entries = [], userId = null) {
  const uniqueEntries = uniqueBy(entries, entry => entry.id).slice(0, PREFETCH_LIMIT);
  if (!uniqueEntries.length || isLazyLoadingEnabled()) return;

  logInfo("Lazy loading disabled; prefetching outfit entry details in the background.", {
    userId,
    entries: uniqueEntries.length,
    limit: PREFETCH_LIMIT,
    note: "using lazy loading to prevent spamming is appreciated, mwah"
  });

  for (const entry of uniqueEntries) {
    if (isLazyLoadingEnabled()) {
      logInfo("Prefetch stopped because lazy loading was re-enabled.", { userId });
      return;
    }

    try {
      await getOutfitDetail(entry.id);
      logSuccess("Prefetched outfit entry detail.", { id: entry.id, name: entry.name || null });
    } catch (err) {
      logError("Prefetch outfit entry failed.", err, { id: entry.id, name: entry.name || null });
    }

    await sleep(PREFETCH_DELAY_MS);
  }

  logSuccess("Background outfit detail prefetch finished.", { userId, entries: uniqueEntries.length });
}

function getSavedTheme() {
  const saved = localStorage.getItem(THEME_STORAGE_KEY) || localStorage.getItem("theme");
  if (saved === "light" || saved === "dark") return saved;
  return window.matchMedia?.("(prefers-color-scheme: light)")?.matches ? "light" : "dark";
}

function applyTheme(theme) {
  const isLight = theme === "light";
  document.documentElement.classList.toggle("light", isLight);
  document.documentElement.dataset.theme = isLight ? "light" : "dark";
  if (themeBtn) {
    themeBtn.setAttribute("aria-pressed", String(isLight));
    themeBtn.setAttribute("aria-label", isLight ? "Switch to dark theme" : "Switch to light theme");
    themeBtn.title = isLight ? "Switch to dark theme" : "Switch to light theme";
  }
}

function initLazyLoadingOption() {
  if (!lazyLoadToggle) return;
  lazyLoadToggle.checked = isLazyLoadingEnabled();
}

function isLazyLoadingEnabled() {
  return localStorage.getItem(LAZY_LOAD_STORAGE_KEY) !== "off";
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function looksLikeGithub404(text, res) {
  return (
    res.status === 404 &&
    (text.includes("Page not found") || text.includes("GitHub Pages") || text.includes("File not found"))
  );
}

function createSkeletonSlot(user, index) {
  const slot = document.createElement("div");
  slot.className = "result-slot";
  slot.dataset.userId = String(user.id);
  slot.innerHTML = `
    <article class="skeleton-card" aria-label="Loading ${escapeAttr(user.name || `account ${index + 1}`)}">
      <div class="skeleton skeleton-avatar"></div>
      <div class="skeleton-lines">
        <div class="skeleton skeleton-line"></div>
        <div class="skeleton skeleton-line"></div>
        <div class="skeleton skeleton-line"></div>
      </div>
    </article>`;
  return slot;
}

async function mapLimit(items, limit, mapper) {
  const input = Array.from(items || []);
  let next = 0;

  async function run() {
    while (next < input.length) {
      const index = next++;
      await mapper(input[index], index);
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, input.length) }, run));
}

function setupUserTabs(article) {
  const tabs = [...article.querySelectorAll(".result-tab")];
  const sections = [...article.querySelectorAll("[data-result-kind]")];

  for (const tab of tabs) {
    const view = tab.dataset.view;
    if (view !== "all" && !sections.some(section => section.dataset.resultKind === view)) {
      tab.classList.add("unavailable");
      tab.setAttribute("aria-disabled", "true");
    }

    tab.addEventListener("click", () => {
      if (tab.classList.contains("unavailable")) return;
      tabs.forEach(item => item.classList.toggle("active", item === tab));
      sections.forEach(section => {
        section.hidden = view !== "all" && section.dataset.resultKind !== view;
      });
    });
  }
}

function renderUser(report, mount = null, index = 0) {
  const tpl = $("#userCardTpl").content.cloneNode(true);
  const article = $(".user-card", tpl);
  const p = report.profile || {};
  const avatarUrl = report.avatarThumbnail?.imageUrl || "";

  const avatarImg = $(".avatar-img", tpl);
  avatarImg.src = avatarUrl;
  avatarImg.alt = `${p.displayName || p.name || "Roblox user"} avatar`;
  avatarImg.onerror = () => {
    avatarImg.removeAttribute("src");
    avatarImg.classList.add("avatar-empty");
  };
  $(".avatar-index", tpl).textContent = `#${String(index + 1).padStart(2, "0")}`;
  $(".profile-handle", tpl).textContent = `@${p.name || "unknown"}`;
  $(".profile-title", tpl).textContent = `${p.displayName || p.name || "Unknown"} ${p.hasVerifiedBadge ? "✓" : ""}`;
  $(".profile-meta", tpl).textContent = `ID ${p.id} · joined ${formatDate(p.created)}`;
  $(".profile-link", tpl).href = `https://www.roblox.com/users/${p.id}/profile`;
  $(".description-text", tpl).textContent = p.description || "No public description.";

  const chips = $(".chips", tpl);
  chips.append(chip(p.isBanned ? "Banned" : "Account active", p.isBanned ? "bad" : "good"));
  if (p.hasVerifiedBadge) chips.append(chip("Verified"));
  if (report.debug?.duplicateIds?.length) chips.append(chip(`${report.debug.duplicateIds.length} duplicate ID(s) removed`));

  const wearing = uniqueBy((report.currentlyWearing || []), item => item.id);
  $(".wearing-count", tpl).textContent = `${wearing.length} item${wearing.length === 1 ? "" : "s"}`;
  $(".wearing-stat", tpl).textContent = wearing.length;
  const wearingGrid = $(".wearing-grid", tpl);
  if (!wearing.length) wearingGrid.innerHTML = `<div class="empty">Roblox returned no public currently-wearing assets.</div>`;
  for (const item of wearing) wearingGrid.append(assetCard(item));

  const emoteSection = createEmoteSection(report.emotes || [], report.debug?.emoteLogs || []);
  wearingGrid.closest("section")?.after(emoteSection);

  const outfitGroups = splitOutfits(report.outfits || []);
  const outfits = outfitGroups.saved;
  const costumeLike = outfitGroups.costumeLike;
  const animationPacks = outfitGroups.animationPacks;
  const characterPackages = outfitGroups.characterPackages;

  $(".outfit-count", tpl).textContent = `${outfits.length} outfit${outfits.length === 1 ? "" : "s"}`;
  $(".outfit-stat", tpl).textContent = outfits.length;
  $(".extra-stat", tpl).textContent = (report.emotes?.length || 0) + costumeLike.length + animationPacks.length + characterPackages.length;
  const outfitGrid = $(".outfit-grid", tpl);
  const sectionsRoot = $(".user-sections", tpl);
  if (!outfits.length) outfitGrid.innerHTML = `<div class="empty">No normal saved outfits were returned.</div>`;
  for (const outfit of outfits) outfitGrid.append(outfitCard(outfit));

  if (characterPackages.length) {
    sectionsRoot.append(createExtraOutfitSection(
      "Character presets",
      "Marketplace character and package entries Roblox returned beside saved looks.",
      characterPackages,
      "Package entry",
      "packs"
    ));
  }

  if (animationPacks.length) {
    sectionsRoot.append(createExtraOutfitSection(
      "Animation packs",
      "Open a pack to inspect its run, walk, jump, and other component animations.",
      animationPacks,
      "Animation pack",
      "packs"
    ));
  }

  if (costumeLike.length) {
    sectionsRoot.append(createCostumeSection(costumeLike));
  }

  $(".json-btn", tpl).addEventListener("click", () => downloadJson(`roblox-${p.id}-outfits.json`, report));
  setupUserTabs(article);
  if (mount) mount.replaceChildren(tpl);
  else results.append(tpl);

  const prefetchEntries = [...outfits, ...characterPackages, ...animationPacks, ...costumeLike];
  if (!isLazyLoadingEnabled() && prefetchEntries.length) {
    prefetchOutfitDetails(prefetchEntries, p.id);
  }
}

function thumbnailMarkup(img, fallbackText) {
  return `
    <div class="thumb-placeholder" aria-hidden="true"><span>${fallbackText || "ITEM"}</span></div>
    ${img ? `<img src="${img}" alt="" loading="lazy" data-thumb-img>` : ""}
  `;
}

function hydrateThumbs(root) {
  for (const img of root.querySelectorAll("[data-thumb-img]")) {
    const wrap = img.closest(".thumb-wrap");
    const markLoaded = () => wrap?.classList.add("has-image");
    const markFailed = () => {
      wrap?.classList.remove("has-image");
      img.remove();
    };

    img.addEventListener("load", markLoaded, { once: true });
    img.addEventListener("error", markFailed, { once: true });
    if (img.complete && img.naturalWidth > 0) markLoaded();
  }
}

function assetCard(item) {
  const display = getDisplayItem(item);
  const el = document.createElement("article");
  el.className = "asset";
  if (display.missingName) el.classList.add("missing-name");

  const id = Number(item.id || display.id);
  const displayName = escapeHtml(display.name);
  const img = escapeAttr(item.imageUrl || display.imageUrl || "");
  const creator = escapeHtml(display.creatorName || "Unknown creator");
  const price = formatPrice(display);
  const type = escapeHtml(display.metaType || "Asset");
  const source = display.detailsSource ? ` • ${escapeHtml(display.detailsSource)}` : "";
  const fallbackText = escapeHtml((display.metaType || "Asset").slice(0, 2).toUpperCase());
  const url = escapeAttr(display.url || `https://www.roblox.com/catalog/${id}`);
  const linkLabel = display.purchasableType === "Bundle" ? "Bundle" : "Catalog";

  el.innerHTML = `
    <div class="thumb-wrap" aria-label="${displayName}">
      ${thumbnailMarkup(img, fallbackText)}
    </div>
    <div class="asset-body">
      <p class="item-name" title="${displayName}">${displayName}</p>
      <p class="item-meta">${type} • ID ${id}${display.bundleId ? ` • Bundle ${display.bundleId}` : ""}${source}</p>
      <p class="item-meta">${creator}</p>
      <p class="item-meta">${escapeHtml(price)}</p>
      ${display.componentNote ? `<p class="item-note">${escapeHtml(display.componentNote)}</p>` : ""}
      <div class="item-links">
        <a target="_blank" rel="noopener" href="${url}">${linkLabel}</a>
        <button class="small-btn" type="button" data-copy="${id}">Copy ID</button>
      </div>
    </div>`;

  hydrateThumbs(el);
  $("[data-copy]", el).addEventListener("click", () => navigator.clipboard?.writeText(String(id)));
  return el;
}

function getDisplayItem(item = {}) {
  const id = Number(item.id || item.assetId);
  const bundle = item.parentBundle || null;
  const rawName = item.name || item.Name || "";
  const missingName = isFallbackAssetName(rawName, id);
  const assetType = item.assetType?.name || item.assetType?.Name || item.assetTypeName || item.itemType || "Asset";

  if (item.componentDisplayMode === "pack-component") {
    const bundleName = bundle?.name || item.bundleName || "Animation pack";
    return {
      ...item,
      id,
      name: missingName ? fallbackAssetLabel(item, id) : rawName,
      missingName,
      creatorName: item.creatorName || bundle?.creatorName || "Roblox",
      price: null,
      lowestPrice: null,
      priceStatus: "Included in pack",
      isForSale: false,
      isFree: false,
      purchasableType: "Bundle",
      bundleId: bundle?.id || item.bundleId || null,
      url: bundle?.url || (bundle?.id ? `https://www.roblox.com/bundles/${bundle.id}` : `https://www.roblox.com/catalog/${id}`),
      metaType: `${assetType} component`,
      detailsSource: item.detailsSource || "pack-component",
      componentNote: `Included in ${bundleName}. Not sold as a standalone avatar item.`
    };
  }

  if (bundle?.id) {
    return {
      ...item,
      id,
      name: bundle.name || rawName || `Bundle ${bundle.id}`,
      missingName: false,
      creatorName: bundle.creatorName || item.creatorName || item.creator?.name || null,
      price: bundle.price ?? item.price ?? null,
      lowestPrice: bundle.lowestPrice ?? item.lowestPrice ?? null,
      priceStatus: bundle.priceStatus || item.priceStatus || null,
      isForSale: bundle.isForSale ?? item.isForSale ?? null,
      isFree: bundle.isFree ?? item.isFree ?? false,
      purchasableType: "Bundle",
      bundleId: bundle.id,
      url: bundle.url || `https://www.roblox.com/bundles/${bundle.id}`,
      metaType: `${bundle.bundleType || "Bundle"} component: ${assetType}`,
      detailsSource: item.detailsSource || bundle.detailsSource || null
    };
  }

  return {
    ...item,
    id,
    name: missingName ? fallbackAssetLabel(item, id) : rawName,
    missingName,
    creatorName: item.creatorName || item.creator?.name || item.creator?.Name || null,
    url: item.purchasableUrl || `https://www.roblox.com/catalog/${id}`,
    metaType: assetType,
    detailsSource: item.detailsSource || null
  };
}

function outfitCard(outfit, label = "Outfit") {
  const el = document.createElement("article");
  el.className = "outfit";
  const name = escapeHtml(outfit.name || `Outfit ${outfit.id}`);

  el.innerHTML = `
    <div class="thumb-wrap" aria-label="${name}">
      ${thumbnailMarkup(escapeAttr(outfit.imageUrl || ""), "OUTFIT")}
    </div>
    <div class="outfit-body">
      <p class="item-name" title="${name}">${name}</p>
      <p class="item-meta">${label} ID ${outfit.id}</p>
      <div class="item-links">
        <button class="small-btn" type="button">Open outfit</button>
      </div>
    </div>`;

  hydrateThumbs(el);
  $("button", el).addEventListener("click", async () => {
    const title = $("#selectedOutfitTitle");
    const count = $("#selectedOutfitCount");
    const grid = $("#selectedOutfitGrid");
    title.textContent = outfit.name || `Outfit ${outfit.id}`;
    count.textContent = "Loading…";
    grid.innerHTML = `<div class="empty">Loading outfit items…</div>`;
    openDialog(outfitDialog);

    try {
      const detail = await getOutfitDetail(outfit.id);
      const entryKind = classifyOutfitEntry(outfit);
      const prepared = prepareDisplayAssets(detail.assets || [], { mode: entryKind === "animation" ? "animationPack" : "normal", outfitName: detail.name || outfit.name || "Animation pack" });
      const assets = prepared.assets;
      count.textContent = `${assets.length} item${assets.length === 1 ? "" : "s"}`;
      grid.innerHTML = "";
      if (!assets.length) {
        grid.innerHTML = `<div class="empty">No displayable assets returned for this entry.</div>`;
      } else {
        assets.forEach(a => grid.append(assetCard(a)));
        if (prepared.hiddenStandaloneAnimations || prepared.groupedBundleComponents) {
          const note = document.createElement("div");
          note.className = "empty";
          note.textContent = prepared.packComponentMode
            ? `Showing ${prepared.packComponentsShown} animation-pack component(s). Purchase/use the pack itself, not the internal component IDs.`
            : `Grouped ${prepared.groupedBundleComponents} bundle component(s) and hid ${prepared.hiddenStandaloneAnimations} standalone non-emote animation asset(s).`;
          grid.append(note);
        }
      }
      logSuccess("Outfit items rendered.", { outfitId: outfit.id, assets: assets.length, hiddenStandaloneAnimations: prepared.hiddenStandaloneAnimations, groupedBundleComponents: prepared.groupedBundleComponents, packComponentsShown: prepared.packComponentsShown });
    } catch (err) {
      count.textContent = "Error";
      grid.innerHTML = `<div class="empty danger-text">${escapeHtml(cleanError(err))}</div>`;
      logError("Outfit items failed.", err, { outfitId: outfit.id });
    }
  });

  return el;
}

function createEmoteSection(emotes = [], logs = []) {
  const section = document.createElement("section");
  section.className = "emote-section";
  section.dataset.resultKind = "emotes";
  const visible = Array.isArray(emotes) ? emotes.filter(Boolean) : [];
  const logText = logs.length ? logs.join(" ") : "Roblox did not return public equipped-emote data for this user.";
  section.innerHTML = `
    <div class="section-title">
      <div>
        <p class="section-number">04 / EMOTES</p>
        <h3>Equipped emotes</h3>
        <p class="section-note">Only the equipped emotes Roblox exposes publicly.</p>
      </div>
      <span class="count-badge">${visible.length} ${visible.length === 1 ? "emote" : "emotes"}</span>
    </div>
    <div class="asset-grid emote-grid"></div>`;

  const grid = $(".emote-grid", section);
  if (!visible.length) {
    grid.innerHTML = `<div class="empty">${escapeHtml(logText)}</div>`;
  } else {
    visible.forEach(e => grid.append(assetCard({ ...e, itemType: "Emote", assetTypeName: "Emote Animation" })));
  }
  return section;
}

function splitOutfits(outfits = []) {
  const saved = [];
  const costumeLike = [];
  const animationPacks = [];
  const characterPackages = [];

  for (const outfit of outfits) {
    const kind = classifyOutfitEntry(outfit);
    if (kind === "costume") costumeLike.push(outfit);
    else if (kind === "animation") animationPacks.push(outfit);
    else if (kind === "package") characterPackages.push(outfit);
    else saved.push(outfit);
  }

  return { saved, costumeLike, animationPacks, characterPackages };
}

function classifyOutfitEntry(outfit = {}) {
  const name = normalizeName(outfit.name || "");
  const text = `${outfit.imageKind || ""} ${outfit.outfitKind || ""} ${outfit.thumbnailType || ""} ${outfit.imageUrl || ""} ${name}`;

  if (/DynamicHeadCostume|Costume/i.test(text)) return "costume";
  if (/\b(animation pack|animation package)\b/i.test(name)) return "animation";

  const knownPackages = new Set([
    "roblox girl",
    "roblox boy",
    "man",
    "woman",
    "city life woman",
    "city life man",
    "knights of redcliff paladin",
    "rthro normal",
    "rthro animation package"
  ]);

  if (knownPackages.has(name.toLowerCase())) return /animation/i.test(name) ? "animation" : "package";
  if (/\b(character|package|bundle)\b/i.test(name) && !/outfit/i.test(name)) return "package";
  return "saved";
}

function isCostumeLikeOutfit(outfit = {}) {
  return classifyOutfitEntry(outfit) === "costume";
}

function createExtraOutfitSection(title, note, items, label, kind = "outfits") {
  const section = document.createElement("section");
  section.className = "costume-like-section";
  section.dataset.resultKind = kind;
  section.innerHTML = `
    <div class="section-title">
      <div>
        <p class="section-number">${kind === "packs" ? "03 / PACKS" : "02 / SAVED"}</p>
        <h3>${escapeHtml(title)}</h3>
        <p class="section-note">${escapeHtml(note)}</p>
      </div>
      <span class="count-badge">${items.length} ${items.length === 1 ? "entry" : "entries"}</span>
    </div>
    <div class="outfit-grid"></div>`;

  const grid = $(".outfit-grid", section);
  items.forEach(item => grid.append(outfitCard(item, label)));
  return section;
}

function createCostumeSection(items) {
  return createExtraOutfitSection(
    "Avatar costume entries",
    "Costume-style entries returned beside the account’s normal saved outfits.",
    items,
    "Costume entry",
    "outfits"
  );
}

function prepareDisplayAssets(rawAssets = [], options = {}) {
  const mode = options.mode || "normal";
  const assets = uniqueBy(rawAssets, a => Number(a.id || a.assetId));
  const output = [];
  const seenBundles = new Set();
  let hiddenStandaloneAnimations = 0;
  let groupedBundleComponents = 0;
  let packComponentsShown = 0;

  for (const asset of assets) {
    const type = getAssetTypeText(asset);
    const isAnimation = /Animation/i.test(type);
    const isEmote = /EmoteAnimation|Emote Animation/i.test(type);
    const bundle = asset.parentBundle;

    if (mode === "animationPack") {
      output.push({
        ...asset,
        componentDisplayMode: "pack-component",
        parentBundle: bundle || asset.parentBundle || null,
        bundleName: bundle?.name || options.outfitName || "Animation pack"
      });
      packComponentsShown += 1;
      continue;
    }

    if (isAnimation && !isEmote) {
      if (bundle?.id) {
        if (!seenBundles.has(bundle.id)) {
          output.push(makeBundleDisplayAsset(asset, bundle));
          seenBundles.add(bundle.id);
        }
        groupedBundleComponents += 1;
      } else {
        hiddenStandaloneAnimations += 1;
      }
      continue;
    }

    if (bundle?.id && shouldGroupAsBundle(asset)) {
      if (!seenBundles.has(bundle.id)) {
        output.push(makeBundleDisplayAsset(asset, bundle));
        seenBundles.add(bundle.id);
      }
      groupedBundleComponents += 1;
      continue;
    }

    output.push(asset);
  }

  return { assets: output, hiddenStandaloneAnimations, groupedBundleComponents, packComponentsShown, packComponentMode: mode === "animationPack" };
}

function makeBundleDisplayAsset(asset, bundle) {
  return {
    ...asset,
    id: asset.id,
    name: bundle.name || asset.name || `Bundle ${bundle.id}`,
    parentBundle: bundle,
    creatorName: bundle.creatorName || asset.creatorName || null,
    price: bundle.price ?? asset.price ?? null,
    lowestPrice: bundle.lowestPrice ?? asset.lowestPrice ?? null,
    isForSale: bundle.isForSale ?? asset.isForSale ?? null,
    isFree: bundle.isFree ?? asset.isFree ?? false,
    purchasableType: "Bundle",
    purchasableId: bundle.id,
    purchasableUrl: bundle.url || `https://www.roblox.com/bundles/${bundle.id}`,
    assetTypeName: bundle.bundleType || "Bundle",
    itemType: "Bundle",
    detailsSource: "bundle-group"
  };
}

function shouldGroupAsBundle(asset = {}) {
  const type = getAssetTypeText(asset);
  const name = String(asset.name || "");
  return /DynamicHead|MoodAnimation|Torso|Right Arm|Left Arm|Right Leg|Left Leg|Head/i.test(type)
    || /Dynamic Head|Animation Pack|Animation Package|Bundle|Package/i.test(name);
}

function getAssetTypeText(asset = {}) {
  return String(asset.assetType?.name || asset.assetType?.Name || asset.assetTypeName || asset.itemType || "Asset");
}

function normalizeName(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

function fallbackAssetLabel(item, id) {
  const type = getShortTypeLabel(item);
  return type && type !== "Asset" ? `${type} #${id}` : `Asset #${id}`;
}

function getShortTypeLabel(item = {}) {
  const raw = item.assetType?.name || item.assetType?.Name || item.assetTypeName || item.itemType || "Asset";
  return String(raw)
    .replace(/Accessory$/i, "Accessory")
    .replace(/Animation$/i, "Animation")
    .trim() || "Asset";
}

function getInitialQueryFromUrl() {
  const params = new URL(location.href).searchParams;
  const parts = [];

  collectParamValues(params, ["id", "ids", "userId", "userid", "uid"]).forEach(v => {
    for (const part of splitParamList(v)) {
      const id = part.replace(/^id:/i, "").trim();
      if (/^\d+$/.test(id)) parts.push(`id:${id}`);
    }
  });

  collectParamValues(params, ["username", "user", "name", "usernames"]).forEach(v => {
    parts.push(...splitParamList(v).map(x => x.replace(/^@/, "").trim()).filter(Boolean));
  });

  collectParamValues(params, ["search"]).forEach(v => {
    for (const part of splitParamList(v)) if (part) parts.push(`search:${part}`);
  });

  const direct = collectParamValues(params, ["q", "query"])
    .flatMap(splitParamList)
    .filter(Boolean);
  parts.push(...direct);

  return uniqueBy(parts, x => x.toLowerCase()).join(", ");
}

function collectParamValues(params, keys) {
  return keys.flatMap(key => params.getAll(key)).filter(v => v !== null && v !== undefined && String(v).trim() !== "");
}

function splitParamList(value) {
  return String(value || "")
    .split(/[\n,;]+/)
    .map(v => v.trim())
    .filter(Boolean);
}

function updateUrlForSearch(q) {
  const next = buildShareUrl(q);
  history.replaceState(null, "", next);
}

function buildShareUrl(q) {
  const url = new URL(location.href);
  ["q", "query", "username", "user", "name", "usernames", "id", "ids", "userId", "userid", "uid", "search"].forEach(key => url.searchParams.delete(key));

  const value = String(q || "").trim();
  if (!value) return url;

  if (/^id:\s*\d+$/i.test(value)) {
    url.searchParams.set("id", value.replace(/^id:\s*/i, ""));
  } else if (/^search:\s*.+$/i.test(value)) {
    url.searchParams.set("search", value.replace(/^search:\s*/i, ""));
  } else if (/^[A-Za-z0-9_]{3,20}$/.test(value)) {
    url.searchParams.set("username", value);
  } else {
    url.searchParams.set("q", value);
  }

  return url;
}

function isFallbackAssetName(name, id) {
  const s = String(name || "").trim();
  if (!s) return true;
  if (/^asset$/i.test(s)) return true;
  if (/^asset\s+\d+$/i.test(s)) return true;
  return Number.isFinite(Number(id)) && s === `Asset ${id}`;
}

function renderErrorCard(user, err, mount = null) {
  const el = document.createElement("article");
  el.className = "user-card error-card";
  el.innerHTML = `
    <p class="section-number">ACCOUNT FAILED</p>
    <h2>@${escapeHtml(user.name || "unknown")}</h2>
    <p>ID ${escapeHtml(String(user.id))} · ${escapeHtml(cleanError(err))}</p>`;
  if (mount) mount.replaceChildren(el);
  else results.append(el);
}

function chip(text, kind = "") {
  const el = document.createElement("span");
  el.className = `chip ${kind}`.trim();
  el.textContent = text;
  return el;
}

function setStatus(msg, isError = false, options = {}) {
  statusEl.textContent = msg || "";
  statusWrap.hidden = !msg;
  statusWrap.classList.toggle("error", Boolean(isError));
  statusWrap.classList.toggle("loading", Boolean(options.loading));
  resultProgress.textContent = options.progress || "";
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


function formatPrice(item = {}) {
  const source = item.parentBundle || item;
  const status = String(source.priceStatus || item.priceStatus || "").trim();

  const direct = Number(source.price);
  if (Number.isFinite(direct)) return direct === 0 ? "Free" : `${direct} Robux`;

  const lowest = Number(source.lowestPrice ?? source.resaleLowestPrice);
  if (Number.isFinite(lowest) && lowest > 0) return `${lowest} Robux+`;

  if (/^free$/i.test(status)) return "Free";
  if (status && !/^off\s*sale$/i.test(status)) return status;

  if (source.isLimited || source.collectibleItemId || item.collectibleItemId) return "Limited / no listings";
  if (source.isForSale === false || /^off\s*sale$/i.test(status)) return "Off sale";

  // Older/fallback API records can contain isFree=true even when Roblox did not return
  // a real price. Do not show “Free” unless price or priceStatus proves it.
  return "Price unavailable";
}
