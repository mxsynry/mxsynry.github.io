const APP_VERSION = "2026-09-25.rolimons-first-lazy3";

const DEFAULT_API_BASE = document.querySelector('meta[name="outfit-api-base"]')?.content?.trim() || "";
const API_STORAGE_KEY = "robloxOutfitApiBase";
const LOG_STORAGE_KEY = "robloxOutfitDebugLogs";
const LAZY_LOAD_STORAGE_KEY = "robloxOutfitLazyLoading";
const THEME_STORAGE_KEY = "robloxOutfitTheme";
const PROVIDER_MODE_STORAGE_KEY = "robloxOutfitProviderMode";

const MAX_LOGS = 300;
const SEARCH_CONCURRENCY = 3;
const API_TIMEOUT_MS = 35000;
const REPORT_TIMEOUT_MS = 45000;
const OUTFIT_TIMEOUT_MS = 40000;
const DETAIL_CACHE_TTL_MS = 5 * 60 * 1000;
const PREFETCH_CONCURRENCY = 2;
const PREFETCH_LIMIT = 80;

const DEMAND_LABELS = new Map([
  [-1, "Unassigned"],
  [0, "Terrible"],
  [1, "Low"],
  [2, "Normal"],
  [3, "High"],
  [4, "Amazing"]
]);

const TREND_LABELS = new Map([
  [-1, "Unassigned"],
  [0, "Lowering"],
  [1, "Unstable"],
  [2, "Stable"],
  [3, "Raising"],
  [4, "Fluctuating"]
]);

const $ = (selector, root = document) => root.querySelector(selector);

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
const rolimonsFirstToggle = $("#rolimonsFirstToggle");
const themeBtn = $("#themeBtn");

const apiParam = new URL(location.href).searchParams.get("api");
if (apiParam === "clear") {
  localStorage.removeItem(API_STORAGE_KEY);
} else if (isHttpUrl(apiParam)) {
  localStorage.setItem(API_STORAGE_KEY, normalizeApiBase(apiParam));
}

let API_BASE = normalizeApiBase(apiParam)
  || normalizeApiBase(localStorage.getItem(API_STORAGE_KEY))
  || normalizeApiBase(DEFAULT_API_BASE);
let debugLogs = loadLogs();
let activeSearchController = null;
let activeSearchGeneration = 0;
let apiConnectionState = hasConfiguredApi() ? "saved" : "offline";
let workerCapabilities = { rolimons: false, version: null, requestModes: [] };

const knownOutfitEntries = new Map();

class OutfitDetailStore {
  constructor() {
    this.cache = new Map();
    this.inflight = new Map();
    this.queue = [];
    this.queued = new Set();
    this.activePrefetch = 0;
    this.prefetchGeneration = 0;
    this.prefetchController = new AbortController();
  }

  cacheKey(id) {
    return `${API_BASE}|${getProviderMode()}|${Number(id)}`;
  }

  clearAll() {
    this.cancelPrefetch("detail store reset");
    this.cache.clear();
    this.inflight.clear();
  }

  cancelPrefetch(reason = "prefetch cancelled") {
    this.prefetchGeneration += 1;
    this.queue = [];
    this.queued.clear();
    try {
      this.prefetchController.abort(reason);
    } catch {}
    this.prefetchController = new AbortController();
  }

  getCached(id) {
    const key = this.cacheKey(id);
    const entry = this.cache.get(key);
    if (!entry) return null;
    if (Date.now() - entry.savedAt > DETAIL_CACHE_TTL_MS) {
      this.cache.delete(key);
      return null;
    }
    return entry.data;
  }

  async get(id, options = {}) {
    const outfitId = Number(id);
    if (!Number.isSafeInteger(outfitId) || outfitId <= 0) {
      throw new Error("Invalid outfit ID.");
    }

    const cached = this.getCached(outfitId);
    if (cached) {
      logInfo("Outfit detail cache hit.", { outfitId });
      return cached;
    }

    const key = this.cacheKey(outfitId);
    const existing = this.inflight.get(key);
    if (existing) {
      logInfo("Outfit detail request deduplicated.", { outfitId, source: existing.kind });
      try {
        return await existing.promise;
      } catch (err) {
        // A foreground click should recover if it joined a prefetch that was cancelled.
        if (!options.prefetch && err?.name === "AbortError") {
          // The shared prefetch promise can be aborted when click-only mode/search state changes.
          // Drop that stale in-flight entry before retrying as a foreground request.
          if (this.inflight.get(key)?.promise === existing.promise) this.inflight.delete(key);
          return this.get(outfitId, { ...options, prefetch: false });
        }
        throw err;
      }
    }

    const request = (async () => {
      const detail = await api(`/api/outfit/${outfitId}?mode=${encodeURIComponent(getProviderMode())}`, {
        signal: options.signal,
        timeoutMs: OUTFIT_TIMEOUT_MS,
        logQuietly: Boolean(options.prefetch)
      });
      addServerLogs(`outfit:${outfitId}`, detail.debug?.logs);
      this.cache.set(key, { data: detail, savedAt: Date.now() });
      return detail;
    })();

    this.inflight.set(key, {
      promise: request,
      kind: options.prefetch ? "prefetch" : "foreground"
    });

    try {
      return await request;
    } finally {
      if (this.inflight.get(key)?.promise === request) {
        this.inflight.delete(key);
      }
    }
  }

  schedule(entries = [], context = {}) {
    if (isLazyLoadingEnabled()) return;

    const uniqueEntries = uniqueBy(entries.filter(Boolean), entry => Number(entry.id))
      .filter(entry => Number.isSafeInteger(Number(entry.id)))
      .slice(0, PREFETCH_LIMIT);

    let added = 0;
    for (const entry of uniqueEntries) {
      const id = Number(entry.id);
      const key = this.cacheKey(id);
      if (this.getCached(id) || this.inflight.has(key) || this.queued.has(key)) continue;
      this.queue.push({ id, name: entry.name || null, context });
      this.queued.add(key);
      added += 1;
    }

    if (added) {
      logInfo("Queued outfit detail prefetch.", {
        added,
        pending: this.queue.length,
        concurrency: PREFETCH_CONCURRENCY,
        userId: context.userId || null
      });
      this.drain();
    }
  }

  drain() {
    if (isLazyLoadingEnabled()) return;
    const generation = this.prefetchGeneration;

    while (this.activePrefetch < PREFETCH_CONCURRENCY && this.queue.length) {
      const job = this.queue.shift();
      const key = this.cacheKey(job.id);
      this.queued.delete(key);
      this.activePrefetch += 1;

      const run = async () => {
        if (generation !== this.prefetchGeneration || isLazyLoadingEnabled()) return;
        try {
          await this.get(job.id, {
            prefetch: true,
            signal: this.prefetchController.signal
          });
          logSuccess("Prefetched outfit detail.", { id: job.id, name: job.name });
        } catch (err) {
          if (err?.name !== "AbortError") {
            logError("Outfit prefetch failed.", err, { id: job.id, name: job.name });
          }
        } finally {
          this.activePrefetch = Math.max(0, this.activePrefetch - 1);
          if (generation === this.prefetchGeneration) {
            scheduleIdle(() => this.drain());
          }
        }
      };

      scheduleIdle(run);
    }
  }
}

const outfitDetails = new OutfitDetailStore();

init();

function init() {
  applyTheme(getSavedTheme());
  refreshApiUi();
  initLazyLoadingOption();
  initProviderModeOption();
  renderConsole();
  bindUi();

  logInfo("App loaded.", {
    appVersion: APP_VERSION,
    apiConfigured: hasConfiguredApi(),
    apiBase: hasConfiguredApi() ? API_BASE : null,
    lazyLoading: isLazyLoadingEnabled(),
    providerMode: getProviderMode()
  });

  const initialQuery = getInitialQueryFromUrl();
  if (initialQuery) {
    queryInput.value = initialQuery;
    setStatus(`Ready to search: ${initialQuery}`);
  }

  if (hasConfiguredApi()) {
    verifyApiConnection().finally(() => {
      if (initialQuery) setTimeout(() => searchForm.requestSubmit(), 80);
    });
  } else if (initialQuery) {
    setStatus("Search link loaded. Connect the Worker to run it.");
  }
}

function bindUi() {
  saveApiBtn?.addEventListener("click", saveApiConnection);
  changeApiBtn?.addEventListener("click", () => {
    refreshApiUi();
    openDialog(apiDialog);
    setTimeout(() => apiBaseInput?.focus(), 60);
  });

  clearApiBtn?.addEventListener("click", () => {
    localStorage.removeItem(API_STORAGE_KEY);
    API_BASE = "";
    workerCapabilities = { rolimons: false, version: null, requestModes: [] };
    outfitDetails.clearAll();
    knownOutfitEntries.clear();
    results.innerHTML = "";
    emptyState.hidden = false;
    refreshApiUi("Saved URL removed.", "offline");
    setStatus("API URL removed. Connect a Worker before searching.");
    logInfo("API setting cleared.");
    apiBaseInput?.focus();
  });

  openGuideBtn?.addEventListener("click", () => {
    apiDialog?.close();
    openDialog(instructionsDialog);
  });

  themeBtn?.addEventListener("click", () => {
    const nextTheme = document.documentElement.classList.contains("light") ? "dark" : "light";
    applyTheme(nextTheme);
    localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
    localStorage.setItem("theme", nextTheme);
    logInfo("Theme changed.", { theme: nextTheme });
  });

  instructionsBtn?.addEventListener("click", () => openDialog(instructionsDialog));
  consoleBtn?.addEventListener("click", () => {
    renderConsole();
    openDialog(consoleDialog);
  });

  for (const btn of document.querySelectorAll("[data-close-dialog]")) {
    btn.addEventListener("click", () => document.getElementById(btn.dataset.closeDialog)?.close());
  }

  for (const dialog of document.querySelectorAll("dialog")) {
    dialog.addEventListener("click", event => {
      if (event.target === dialog) dialog.close();
    });
  }

  copyConsoleBtn?.addEventListener("click", async () => {
    const text = debugLogs.map(formatLogLine).join("\n");
    try {
      await navigator.clipboard.writeText(text || "No logs yet.");
      copyConsoleBtn.textContent = "Copied";
      setTimeout(() => copyConsoleBtn.textContent = "Copy", 1000);
    } catch {
      setStatus("Could not copy logs from this browser.", true);
    }
  });

  clearConsoleBtn?.addEventListener("click", () => {
    debugLogs = [];
    saveLogs();
    renderConsole();
  });

  lazyLoadToggle?.addEventListener("change", () => {
    localStorage.setItem(LAZY_LOAD_STORAGE_KEY, lazyLoadToggle.checked ? "on" : "off");

    if (lazyLoadToggle.checked) {
      outfitDetails.cancelPrefetch("click-only mode enabled");
      setStatus("Load details on click enabled. No outfit-detail requests will run in the background.");
    } else {
      setStatus("Background detail loading enabled. Requests are deduplicated and limited to two at a time.");
      outfitDetails.schedule([...knownOutfitEntries.values()], { reason: "toggle" });
    }

    logInfo("Lazy loading option changed.", {
      clickOnly: lazyLoadToggle.checked,
      knownOutfits: knownOutfitEntries.size
    });
  });

  rolimonsFirstToggle?.addEventListener("change", () => {
    localStorage.setItem(PROVIDER_MODE_STORAGE_KEY, rolimonsFirstToggle.checked ? "rolimons-first" : "full");
    outfitDetails.clearAll();

    if (rolimonsFirstToggle.checked) {
      const supportsMode = workerCapabilities.rolimons && workerCapabilities.requestModes.includes("rolimons-first");
      setStatus(supportsMode
        ? "Rolimons-first enabled. Search again to reduce Roblox catalog requests."
        : "Rolimons-first selected, but the connected Worker is too old. Deploy the new worker.js first.", !supportsMode);
    } else {
      setStatus("Full Roblox enrichment enabled. This uses more Roblox catalog/economy requests.");
    }

    logInfo("Provider preference changed.", {
      mode: getProviderMode(),
      workerSupportsRolimons: workerCapabilities.rolimons
    });
  });

  copyLinkBtn?.addEventListener("click", async () => {
    const url = buildShareUrl(queryInput.value.trim()).toString();
    try {
      await navigator.clipboard.writeText(url);
      copyLinkBtn.textContent = "Copied link";
      setTimeout(() => copyLinkBtn.textContent = "Copy search link", 1100);
    } catch {
      setStatus(`Share link: ${url}`);
    }
  });

  for (const chip of document.querySelectorAll("[data-example]")) {
    chip.addEventListener("click", () => {
      queryInput.value = chip.dataset.example || "";
      queryInput.focus();
    });
  }

  clearQueryBtn?.addEventListener("click", () => {
    queryInput.value = "";
    queryInput.focus();
  });

  cancelSearchBtn?.addEventListener("click", () => activeSearchController?.abort("cancelled"));
  searchForm?.addEventListener("submit", runSearch);
}

async function saveApiConnection() {
  const value = apiBaseInput.value.trim().replace(/\/$/, "");
  if (!/^https:\/\//i.test(value)) {
    apiStatus.textContent = "Use the full https:// URL.";
    return;
  }

  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    apiStatus.textContent = "Enter a valid Worker URL.";
    return;
  }

  if (parsed.origin === window.location.origin) {
    apiStatus.textContent = "That is this website's URL. Paste the Cloudflare Worker URL instead.";
    return;
  }

  localStorage.setItem(API_STORAGE_KEY, value);
  API_BASE = value;
  outfitDetails.clearAll();
  knownOutfitEntries.clear();
  saveApiBtn.disabled = true;
  saveApiBtn.textContent = "Checking…";
  refreshApiUi("Checking the Worker…", "saved");

  try {
    const health = await verifyApiConnection();
    setStatus(workerCapabilities.rolimons
      ? "Worker connected. Rolimons enrichment is enabled."
      : "Worker connected, but this Worker does not advertise Rolimons support.");
    setTimeout(() => apiDialog.close(), 350);
    return health;
  } catch (err) {
    refreshApiUi(cleanError(err), "error");
  } finally {
    saveApiBtn.disabled = false;
    saveApiBtn.textContent = "Connect";
  }
}

async function verifyApiConnection() {
  const health = await api("/api/health", { timeoutMs: 9000 });
  workerCapabilities = {
    version: health.version || null,
    rolimons: Boolean(health.providers?.rolimons?.enabled),
    requestModes: Array.isArray(health.requestModes?.supported) ? health.requestModes.supported : []
  };

  syncProviderModeUi();

  const providerText = workerCapabilities.rolimons
    ? ` · Rolimons${getProviderMode() === "rolimons-first" ? "-first" : ""}`
    : "";
  refreshApiUi(`Connected · Worker ${health.version || "ready"}${providerText}`, "online");
  logSuccess("API health check succeeded.", {
    version: health.version,
    providers: health.providers || null
  });

  if (workerCapabilities.rolimons) {
    // Do not block connection on this. It warms/verifies the Worker's server-side Rolimons path.
    verifyRolimonsBridge();
  }

  return health;
}

async function verifyRolimonsBridge() {
  try {
    const sample = await api("/api/rolimons/item/1029025", {
      timeoutMs: 16000,
      logQuietly: true
    });
    logSuccess("Rolimons Worker bridge responded.", {
      tracked: sample.tracked,
      name: sample.item?.name || null
    });
  } catch (err) {
    logError("Rolimons Worker bridge check failed; Roblox data can still load.", err);
  }
}

async function runSearch(event) {
  event.preventDefault();
  const query = queryInput.value.trim();
  if (!query) return;

  updateUrlForSearch(query);
  if (!hasConfiguredApi()) {
    setStatus("Connect the included Cloudflare Worker first.", true);
    openDialog(apiDialog);
    return;
  }

  activeSearchController?.abort("new search");
  activeSearchGeneration += 1;
  const generation = activeSearchGeneration;
  const controller = new AbortController();
  activeSearchController = controller;

  outfitDetails.cancelPrefetch("new search");
  knownOutfitEntries.clear();
  results.innerHTML = "";
  emptyState.hidden = true;
  searchBtn.disabled = true;
  cancelSearchBtn.hidden = false;
  setStatus("Finding Roblox account(s)…", false, { loading: true });
  logInfo("Search started.", { query, generation, providerMode: getProviderMode() });

  try {
    const resolved = await api(`/api/resolve?q=${encodeURIComponent(query)}&mode=${encodeURIComponent(getProviderMode())}`, {
      signal: controller.signal,
      timeoutMs: API_TIMEOUT_MS
    });
    if (generation !== activeSearchGeneration) return;

    addServerLogs("resolve", resolved.logs);
    const candidates = uniqueBy((resolved.users || []), user => user.id);
    if (!candidates.length) {
      setStatus("No public Roblox accounts matched that search.", true);
      emptyState.hidden = false;
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
      if (controller.signal.aborted || generation !== activeSearchGeneration) return;

      try {
        const reportParams = new URLSearchParams({
          mode: getProviderMode()
        });
        if (user.name) reportParams.set("username", user.name);
        if (user.displayName) reportParams.set("displayName", user.displayName);
        if (user.hasVerifiedBadge) reportParams.set("verified", "1");

        const report = await api(`/api/report/${user.id}?${reportParams.toString()}`, {
          signal: controller.signal,
          timeoutMs: REPORT_TIMEOUT_MS
        });
        if (controller.signal.aborted || generation !== activeSearchGeneration) return;

        addServerLogs(`report:${user.id}`, report.debug?.logs);
        renderUser(report, slots[index], index);
        shown += 1;
        logSuccess("Account report rendered.", {
          id: user.id,
          name: user.name,
          wearing: report.currentlyWearing?.length || 0,
          outfits: report.outfits?.length || 0,
          rolimons: report.debug?.rolimons || null
        });
      } catch (err) {
        if (err?.name === "AbortError") return;
        renderErrorCard(user, err, slots[index]);
        logError("Account report failed.", err, { id: user.id, name: user.name });
      } finally {
        finished += 1;
        if (!controller.signal.aborted && generation === activeSearchGeneration) {
          setStatus("Loading account data…", false, {
            loading: finished < candidates.length,
            progress: `${finished} / ${candidates.length}`
          });
        }
      }
    });

    if (generation === activeSearchGeneration && !controller.signal.aborted) {
      setStatus(`Loaded ${shown} of ${candidates.length} account${candidates.length === 1 ? "" : "s"}.`, false, {
        progress: `${shown} shown`
      });
    }
  } catch (err) {
    if (err?.name === "AbortError") {
      if (generation === activeSearchGeneration) setStatus("Search cancelled.");
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
}

async function api(path, options = {}) {
  const url = `${API_BASE}${path}`;
  const timeoutMs = options.timeoutMs || API_TIMEOUT_MS;
  const requestController = new AbortController();
  const started = performance.now();
  const timeoutId = setTimeout(() => requestController.abort("timeout"), timeoutMs);
  const abortFromParent = () => requestController.abort("cancelled");

  if (options.signal) {
    if (options.signal.aborted) abortFromParent();
    else options.signal.addEventListener("abort", abortFromParent, { once: true });
  }

  if (!options.logQuietly) logInfo("API request started.", { path, url });

  try {
    const response = await fetch(url, {
      method: "GET",
      headers: { accept: "application/json" },
      signal: requestController.signal
    });

    const text = await response.text();
    const elapsedMs = Math.round(performance.now() - started);
    let data;

    try {
      data = text ? JSON.parse(text) : {};
    } catch {
      const preview = text.slice(0, 600).replace(/\s+/g, " ").trim();
      const message = looksLikeStaticHost404(text, response)
        ? "The saved API URL is returning a website 404 page, not your Cloudflare Worker."
        : `The API returned non-JSON text. Status ${response.status}.`;
      const err = new Error(message);
      err.status = response.status;
      err.preview = preview;
      throw err;
    }

    if (!response.ok) {
      const err = new Error(data.error || data.message || data.errors?.[0]?.message || `HTTP ${response.status}`);
      err.status = response.status;
      err.details = data.details || data;
      throw err;
    }

    if (!options.logQuietly) {
      logSuccess("API request succeeded.", {
        path,
        status: response.status,
        elapsedMs,
        summary: summarizeApiData(data)
      });
    }

    return data;
  } catch (err) {
    if (options.signal?.aborted || requestController.signal.reason === "cancelled") {
      const cancelled = new Error("Request cancelled.");
      cancelled.name = "AbortError";
      throw cancelled;
    }

    if (requestController.signal.aborted) {
      const timedOut = new Error(`The API took longer than ${Math.round(timeoutMs / 1000)} seconds.`);
      timedOut.status = 504;
      if (!options.logQuietly) logError("API request timed out.", timedOut, { path, timeoutMs });
      throw timedOut;
    }

    if (!options.logQuietly) logError("API request failed.", err, { path, url });
    throw err;
  } finally {
    clearTimeout(timeoutId);
    options.signal?.removeEventListener("abort", abortFromParent);
  }
}

function renderUser(report, mount = null, index = 0) {
  const tpl = $("#userCardTpl").content.cloneNode(true);
  const article = $(".user-card", tpl);
  const profile = report.profile || {};
  const avatarUrl = report.avatarThumbnail?.imageUrl || "";

  const avatarImg = $(".avatar-img", tpl);
  avatarImg.src = avatarUrl;
  avatarImg.alt = `${profile.displayName || profile.name || "Roblox user"} avatar`;
  avatarImg.onerror = () => {
    avatarImg.removeAttribute("src");
    avatarImg.classList.add("avatar-empty");
  };

  $(".avatar-index", tpl).textContent = `#${String(index + 1).padStart(2, "0")}`;
  $(".profile-handle", tpl).textContent = `@${profile.name || "unknown"}`;
  $(".profile-title", tpl).textContent = `${profile.displayName || profile.name || "Unknown"}${profile.hasVerifiedBadge ? " ✓" : ""}`;
  $(".profile-meta", tpl).textContent = `ID ${profile.id} · joined ${formatDate(profile.created)}`;
  $(".profile-link", tpl).href = `https://www.roblox.com/users/${profile.id}/profile`;
  $(".description-text", tpl).textContent = profile.description || "No public description.";

  const chips = $(".chips", tpl);
  chips.append(chip(profile.isBanned ? "Banned" : "Account active", profile.isBanned ? "bad" : "good"));
  if (profile.hasVerifiedBadge) chips.append(chip("Verified"));
  if (report.debug?.duplicateIds?.length) chips.append(chip(`${report.debug.duplicateIds.length} duplicate ID(s) removed`));
  if (report.debug?.mode === "rolimons-first") chips.append(chip("Rolimons-first"));
  if (profile.partialProfile) chips.append(chip("Partial profile"));

  const roliStats = report.debug?.rolimons;
  if (roliStats && Number.isFinite(Number(roliStats.requested))) {
    chips.append(chip(`Rolimons ${Number(roliStats.matched || 0)}/${Number(roliStats.requested || 0)}`));
  }

  const wearing = uniqueBy(report.currentlyWearing || [], item => Number(item.id));
  $(".wearing-count", tpl).textContent = `${wearing.length} item${wearing.length === 1 ? "" : "s"}`;
  $(".wearing-stat", tpl).textContent = wearing.length;
  const wearingGrid = $(".wearing-grid", tpl);
  if (!wearing.length) wearingGrid.innerHTML = `<div class="empty">No public currently-wearing assets were returned.</div>`;
  wearing.forEach(item => wearingGrid.append(assetCard(item)));

  const emoteSection = createEmoteSection(report.emotes || [], report.debug?.emoteLogs || []);
  wearingGrid.closest("section")?.after(emoteSection);

  const groups = splitOutfits(report.outfits || []);
  const outfits = groups.saved;
  const costumeLike = groups.costumeLike;
  const animationPacks = groups.animationPacks;
  const characterPackages = groups.characterPackages;

  $(".outfit-count", tpl).textContent = `${outfits.length} outfit${outfits.length === 1 ? "" : "s"}`;
  $(".outfit-stat", tpl).textContent = outfits.length;
  $(".extra-stat", tpl).textContent = (report.emotes?.length || 0) + costumeLike.length + animationPacks.length + characterPackages.length;

  const outfitGrid = $(".outfit-grid", tpl);
  const sectionsRoot = $(".user-sections", tpl);
  if (!outfits.length) outfitGrid.innerHTML = `<div class="empty">No normal saved outfits were returned.</div>`;
  outfits.forEach(outfit => outfitGrid.append(outfitCard(outfit)));

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

  if (costumeLike.length) sectionsRoot.append(createCostumeSection(costumeLike));

  $(".json-btn", tpl).addEventListener("click", () => downloadJson(`roblox-${profile.id}-outfits.json`, report));
  setupUserTabs(article);

  if (mount) mount.replaceChildren(tpl);
  else results.append(tpl);

  const allEntries = [...outfits, ...characterPackages, ...animationPacks, ...costumeLike];
  allEntries.forEach(registerOutfitEntry);
  outfitDetails.schedule(allEntries, { userId: profile.id });
}

function assetCard(item) {
  const display = getDisplayItem(item);
  const el = document.createElement("article");
  el.className = "asset";
  if (display.missingName) el.classList.add("missing-name");
  if (display.rolimons) el.classList.add("rolimons-item");

  const id = Number(display.id || item.id);
  const displayName = escapeHtml(display.name);
  const imageUrl = escapeAttr(item.imageUrl || display.imageUrl || "");
  const creator = escapeHtml(display.creatorName || "Unknown creator");
  const type = escapeHtml(display.metaType || "Asset");
  const fallbackText = escapeHtml((display.metaType || "Asset").slice(0, 2).toUpperCase());
  const catalogUrl = escapeAttr(display.url || `https://www.roblox.com/catalog/${id}`);
  const linkLabel = display.purchasableType === "Bundle" ? "Bundle" : "Catalog";
  const robloxPrice = formatPrice(display);
  const roli = display.rolimons;
  const roliMarket = formatRolimonsMarket(roli);
  const roliMeta = formatRolimonsMeta(roli);
  const source = formatSourceLabel(display);

  el.innerHTML = `
    <div class="thumb-wrap" aria-label="${displayName}">
      ${thumbnailMarkup(imageUrl, fallbackText)}
    </div>
    <div class="asset-body">
      <p class="item-name" title="${displayName}">${displayName}</p>
      <p class="item-meta">${type} • ID ${id}${display.bundleId ? ` • Bundle ${display.bundleId}` : ""}${source ? ` • ${escapeHtml(source)}` : ""}</p>
      <p class="item-meta">${creator}</p>
      <p class="item-meta">Roblox: ${escapeHtml(robloxPrice)}</p>
      ${roliMarket ? `<p class="item-note"><b>Rolimons:</b> ${escapeHtml(roliMarket)}</p>` : ""}
      ${roliMeta ? `<p class="item-meta">${escapeHtml(roliMeta)}</p>` : ""}
      ${display.componentNote && !String(display.componentNote).startsWith("Rolimons ·") ? `<p class="item-note">${escapeHtml(display.componentNote)}</p>` : ""}
      <div class="item-links">
        <a target="_blank" rel="noopener" href="${catalogUrl}">${linkLabel}</a>
        ${roli?.url ? `<a target="_blank" rel="noopener" href="${escapeAttr(roli.url)}">Rolimons</a>` : ""}
        <button class="small-btn" type="button" data-copy="${id}">Copy ID</button>
      </div>
    </div>`;

  hydrateThumbs(el);
  $("[data-copy]", el)?.addEventListener("click", () => navigator.clipboard?.writeText(String(id)));
  return el;
}

function getDisplayItem(item = {}) {
  const id = Number(item.id || item.assetId);
  const bundle = item.parentBundle || null;
  const roli = normalizeRolimons(item.rolimons);
  const rawName = item.name || item.Name || "";
  const preferredItemName = roli?.name || (!isFallbackAssetName(rawName, id) ? rawName : "");
  const assetType = item.assetType?.name || item.assetType?.Name || item.assetTypeName || item.itemType || "Asset";

  if (item.componentDisplayMode === "pack-component") {
    const bundleName = bundle?.name || item.bundleName || "Animation pack";
    return {
      ...item,
      id,
      rolimons: roli,
      name: preferredItemName || fallbackAssetLabel(item, id),
      missingName: !preferredItemName,
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
      rolimons: roli,
      name: bundle.name || preferredItemName || `Bundle ${bundle.id}`,
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
    rolimons: roli,
    name: preferredItemName || fallbackAssetLabel(item, id),
    missingName: !preferredItemName,
    creatorName: item.creatorName || item.creator?.name || item.creator?.Name || null,
    url: item.purchasableUrl || `https://www.roblox.com/catalog/${id}`,
    metaType: assetType,
    detailsSource: item.detailsSource || null
  };
}

function normalizeRolimons(value) {
  if (!value || typeof value !== "object") return null;
  const id = Number(value.id);
  return {
    ...value,
    id: Number.isSafeInteger(id) ? id : null,
    name: String(value.name || "").trim() || null,
    acronym: String(value.acronym || "").trim() || null,
    rap: finiteOrNull(value.rap),
    value: finiteOrNull(value.value),
    defaultValue: finiteOrNull(value.defaultValue),
    demand: integerOrNull(value.demand),
    trend: integerOrNull(value.trend),
    projected: Boolean(value.projected),
    hyped: Boolean(value.hyped),
    rare: Boolean(value.rare),
    url: isHttpUrl(value.url) ? value.url : (Number.isSafeInteger(id) ? `https://www.rolimons.com/item/${id}` : null)
  };
}

function formatRolimonsMarket(roli) {
  if (!roli) return "";
  const parts = [];

  // Value is the preferred Rolimons market number when assigned; RAP remains visible separately.
  if (Number.isFinite(roli.value) && roli.value > 0) parts.push(`Value ${formatInteger(roli.value)}`);
  if (Number.isFinite(roli.rap) && roli.rap >= 0) parts.push(`RAP ${formatInteger(roli.rap)}`);
  if (!parts.length && Number.isFinite(roli.defaultValue) && roli.defaultValue >= 0) {
    parts.push(`Default ${formatInteger(roli.defaultValue)}`);
  }

  return parts.join(" • ");
}

function formatRolimonsMeta(roli) {
  if (!roli) return "";
  const parts = [];
  if (roli.acronym) parts.push(roli.acronym);
  if (roli.demand !== null && DEMAND_LABELS.has(roli.demand)) parts.push(`Demand ${DEMAND_LABELS.get(roli.demand)}`);
  if (roli.trend !== null && TREND_LABELS.has(roli.trend)) parts.push(`Trend ${TREND_LABELS.get(roli.trend)}`);
  if (roli.projected) parts.push("Projected");
  if (roli.hyped) parts.push("Hyped");
  if (roli.rare) parts.push("Rare");
  return parts.join(" • ");
}

function formatSourceLabel(item = {}) {
  if (item.rolimons) return "Rolimons + Roblox";
  const raw = String(item.detailsSource || "").trim();
  if (!raw) return "Roblox";
  return raw.replace(/\s*\+\s*rolimons/gi, "").trim() || "Roblox";
}

function outfitCard(outfit, label = "Outfit") {
  registerOutfitEntry(outfit);
  const el = document.createElement("article");
  el.className = "outfit";
  el.dataset.outfitId = String(outfit.id);
  const name = escapeHtml(outfit.name || `Outfit ${outfit.id}`);

  el.innerHTML = `
    <div class="thumb-wrap" aria-label="${name}">
      ${thumbnailMarkup(escapeAttr(outfit.imageUrl || ""), "OUTFIT")}
    </div>
    <div class="outfit-body">
      <p class="item-name" title="${name}">${name}</p>
      <p class="item-meta">${escapeHtml(label)} ID ${escapeHtml(outfit.id)}</p>
      <div class="item-links">
        <button class="small-btn" type="button" data-open-outfit>Open outfit</button>
      </div>
    </div>`;

  hydrateThumbs(el);
  $("[data-open-outfit]", el)?.addEventListener("click", () => openOutfit(outfit));
  return el;
}

async function openOutfit(outfit) {
  const title = $("#selectedOutfitTitle");
  const count = $("#selectedOutfitCount");
  const grid = $("#selectedOutfitGrid");
  const outfitId = Number(outfit.id);

  title.textContent = outfit.name || `Outfit ${outfitId}`;
  count.textContent = outfitDetails.getCached(outfitId) ? "Cached" : "Loading…";
  grid.innerHTML = `<div class="empty">Loading outfit items…</div>`;
  openDialog(outfitDialog);

  try {
    const detail = await outfitDetails.get(outfitId, { prefetch: false });
    if (!outfitDialog.open) return;

    const entryKind = classifyOutfitEntry(outfit);
    const prepared = prepareDisplayAssets(detail.assets || [], {
      mode: entryKind === "animation" ? "animationPack" : "normal",
      outfitName: detail.name || outfit.name || "Animation pack"
    });

    const assets = prepared.assets;
    count.textContent = `${assets.length} item${assets.length === 1 ? "" : "s"}`;
    grid.innerHTML = "";

    if (!assets.length) {
      grid.innerHTML = `<div class="empty">No displayable assets returned for this entry.</div>`;
      return;
    }

    assets.forEach(asset => grid.append(assetCard(asset)));
    if (prepared.hiddenStandaloneAnimations || prepared.groupedBundleComponents) {
      const note = document.createElement("div");
      note.className = "empty";
      note.textContent = prepared.packComponentMode
        ? `Showing ${prepared.packComponentsShown} animation-pack component(s). Purchase/use the pack itself, not the internal component IDs.`
        : `Grouped ${prepared.groupedBundleComponents} bundle component(s) and hid ${prepared.hiddenStandaloneAnimations} standalone non-emote animation asset(s).`;
      grid.append(note);
    }

    logSuccess("Outfit items rendered.", {
      outfitId,
      assets: assets.length,
      rolimonsTracked: assets.filter(asset => asset.rolimons).length
    });
  } catch (err) {
    if (err?.name === "AbortError") return;
    count.textContent = "Error";
    grid.innerHTML = `<div class="empty danger-text">${escapeHtml(cleanError(err))}</div>`;
    logError("Outfit items failed.", err, { outfitId });
  }
}

function registerOutfitEntry(entry) {
  const id = Number(entry?.id);
  if (Number.isSafeInteger(id) && id > 0) knownOutfitEntries.set(id, entry);
}

function createEmoteSection(emotes = [], logs = []) {
  const section = document.createElement("section");
  section.className = "emote-section";
  section.dataset.resultKind = "emotes";
  const visible = Array.isArray(emotes) ? emotes.filter(Boolean) : [];
  const logText = logs.length ? logs.join(" ") : "No public equipped-emote data was returned.";

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
  if (!visible.length) grid.innerHTML = `<div class="empty">${escapeHtml(logText)}</div>`;
  else visible.forEach(emote => grid.append(assetCard({ ...emote, itemType: "Emote", assetTypeName: "Emote Animation" })));
  return section;
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
      tabs.forEach(candidate => candidate.classList.toggle("active", candidate === tab));
      sections.forEach(section => {
        section.hidden = view !== "all" && section.dataset.resultKind !== view;
      });
    });
  }
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
    "roblox girl", "roblox boy", "man", "woman", "city life woman", "city life man",
    "knights of redcliff paladin", "rthro normal", "rthro animation package"
  ]);

  if (knownPackages.has(name.toLowerCase())) return /animation/i.test(name) ? "animation" : "package";
  if (/\b(character|package|bundle)\b/i.test(name) && !/outfit/i.test(name)) return "package";
  return "saved";
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
    "Dynamic Heads",
    "Avatar costume entries returned by Roblox.",
    items,
    "Costume entry",
    "outfits"
  );
}

function prepareDisplayAssets(rawAssets = [], options = {}) {
  const mode = options.mode || "normal";
  const assets = uniqueBy(rawAssets, asset => Number(asset.id || asset.assetId));
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
        parentBundle: bundle || null,
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

  return {
    assets: output,
    hiddenStandaloneAnimations,
    groupedBundleComponents,
    packComponentsShown,
    packComponentMode: mode === "animationPack"
  };
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

function thumbnailMarkup(imageUrl, fallbackText) {
  return `
    <div class="thumb-placeholder" aria-hidden="true"><span>${fallbackText || "ITEM"}</span></div>
    ${imageUrl ? `<img src="${imageUrl}" alt="" loading="lazy" decoding="async" data-thumb-img>` : ""}
  `;
}

function hydrateThumbs(root) {
  for (const img of root.querySelectorAll("[data-thumb-img]")) {
    const wrap = img.closest(".thumb-wrap");
    const loaded = () => wrap?.classList.add("has-image");
    const failed = () => {
      wrap?.classList.remove("has-image");
      img.remove();
    };
    img.addEventListener("load", loaded, { once: true });
    img.addEventListener("error", failed, { once: true });
    if (img.complete && img.naturalWidth > 0) loaded();
  }
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

function formatPrice(item = {}) {
  const source = item.parentBundle || item;
  const status = String(source.priceStatus || item.priceStatus || "").trim();
  const direct = Number(source.price);
  if (Number.isFinite(direct)) return direct === 0 ? "Free" : `${formatInteger(direct)} Robux`;

  const lowest = Number(source.lowestPrice ?? source.resaleLowestPrice);
  if (Number.isFinite(lowest) && lowest > 0) return `${formatInteger(lowest)} Robux+`;
  if (/^free$/i.test(status)) return "Free";
  if (status && !/^off\s*sale$/i.test(status)) return status;
  if (source.isLimited || source.collectibleItemId || item.collectibleItemId || item.rolimons) return "Limited / no Roblox listing";
  if (source.isForSale === false || /^off\s*sale$/i.test(status)) return "Off sale";
  return "Price unavailable";
}

function isFallbackAssetName(name, id) {
  const value = String(name || "").trim();
  if (!value) return true;
  if (/^asset$/i.test(value)) return true;
  if (/^asset\s+#?\d+$/i.test(value)) return true;
  return Number.isFinite(Number(id)) && value === `Asset ${id}`;
}

function fallbackAssetLabel(item, id) {
  const type = getShortTypeLabel(item);
  return type && type !== "Asset" ? `${type} #${id}` : `Asset #${id}`;
}

function getShortTypeLabel(item = {}) {
  const raw = item.assetType?.name || item.assetType?.Name || item.assetTypeName || item.itemType || "Asset";
  return String(raw).replace(/Accessory$/i, "Accessory").replace(/Animation$/i, "Animation").trim() || "Asset";
}

function initLazyLoadingOption() {
  if (lazyLoadToggle) lazyLoadToggle.checked = isLazyLoadingEnabled();
}

function initProviderModeOption() {
  if (!rolimonsFirstToggle) return;
  rolimonsFirstToggle.checked = localStorage.getItem(PROVIDER_MODE_STORAGE_KEY) !== "full";
  syncProviderModeUi();
}

function syncProviderModeUi() {
  if (!rolimonsFirstToggle) return;
  const modeSupported = workerCapabilities.requestModes.includes("rolimons-first");
  const explicitlyUnsupported = apiConnectionState === "online" && (!workerCapabilities.rolimons || !modeSupported);
  rolimonsFirstToggle.disabled = explicitlyUnsupported;
  rolimonsFirstToggle.title = explicitlyUnsupported
    ? "Deploy the new Worker first; this connected Worker does not support Rolimons-first request mode."
    : "Prefer Rolimons and avatar/outfit payload metadata, and skip most per-item Roblox catalog fallbacks.";
}

function getProviderMode() {
  const wantsRolimons = rolimonsFirstToggle
    ? rolimonsFirstToggle.checked
    : localStorage.getItem(PROVIDER_MODE_STORAGE_KEY) !== "full";

  if (!wantsRolimons) return "full";
  if (apiConnectionState === "online") {
    const supported = workerCapabilities.rolimons && workerCapabilities.requestModes.includes("rolimons-first");
    if (!supported) return "full";
  }
  return "rolimons-first";
}

function isLazyLoadingEnabled() {
  return localStorage.getItem(LAZY_LOAD_STORAGE_KEY) !== "off";
}

function scheduleIdle(fn) {
  if (typeof requestIdleCallback === "function") {
    requestIdleCallback(() => fn(), { timeout: 800 });
  } else {
    setTimeout(fn, 0);
  }
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

function hasConfiguredApi() {
  return Boolean(API_BASE);
}

function isHttpUrl(value) {
  try {
    const url = new URL(String(value || ""));
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}

function normalizeApiBase(value) {
  return isHttpUrl(value) ? String(value).trim().replace(/\/$/, "") : "";
}

function refreshApiUi(message = "", state = apiConnectionState) {
  apiConnectionState = state;
  if (apiBaseInput) apiBaseInput.value = hasConfiguredApi() ? API_BASE : "";
  if (apiDot) apiDot.className = `status-dot${state === "online" ? " online" : state === "error" ? " error" : ""}`;
  if (apiState) {
    apiState.className = `connection-state${state === "online" ? " online" : state === "error" ? " error" : ""}`;
    apiState.textContent = state === "online"
      ? (workerCapabilities.rolimons
          ? (getProviderMode() === "rolimons-first" ? "Rolimons-first API" : "API + Rolimons connected")
          : "API connected")
      : state === "error"
        ? "API connection failed"
        : hasConfiguredApi()
          ? "API URL saved"
          : "API not connected";
  }
  if (apiButtonLabel) apiButtonLabel.textContent = hasConfiguredApi() ? "API setup" : "Connect API";
  if (apiStatus) apiStatus.textContent = message || (hasConfiguredApi() ? `Saved: ${API_BASE}` : "No Worker URL saved in this browser.");
}

function getSavedTheme() {
  const saved = localStorage.getItem(THEME_STORAGE_KEY) || localStorage.getItem("theme");
  if (saved === "light" || saved === "dark") return saved;
  return window.matchMedia?.("(prefers-color-scheme: light)")?.matches ? "light" : "dark";
}

function applyTheme(theme) {
  const light = theme === "light";
  document.documentElement.classList.toggle("light", light);
  document.documentElement.dataset.theme = light ? "light" : "dark";
  if (themeBtn) {
    themeBtn.setAttribute("aria-pressed", String(light));
    themeBtn.setAttribute("aria-label", light ? "Switch to dark theme" : "Switch to light theme");
    themeBtn.title = light ? "Switch to dark theme" : "Switch to light theme";
  }
}

function getInitialQueryFromUrl() {
  const params = new URL(location.href).searchParams;
  const parts = [];

  collectParamValues(params, ["id", "ids", "userId", "userid", "uid"]).forEach(value => {
    for (const part of splitParamList(value)) {
      const id = part.replace(/^id:/i, "").trim();
      if (/^\d+$/.test(id)) parts.push(`id:${id}`);
    }
  });

  collectParamValues(params, ["username", "user", "name", "usernames"]).forEach(value => {
    parts.push(...splitParamList(value).map(part => part.replace(/^@/, "").trim()).filter(Boolean));
  });

  collectParamValues(params, ["search"]).forEach(value => {
    for (const part of splitParamList(value)) if (part) parts.push(`search:${part}`);
  });

  parts.push(...collectParamValues(params, ["q", "query"]).flatMap(splitParamList).filter(Boolean));
  return uniqueBy(parts, value => value.toLowerCase()).join(", ");
}

function collectParamValues(params, keys) {
  return keys.flatMap(key => params.getAll(key)).filter(value => String(value ?? "").trim());
}

function splitParamList(value) {
  return String(value || "").split(/[\n,;]+/).map(part => part.trim()).filter(Boolean);
}

function updateUrlForSearch(query) {
  history.replaceState(null, "", buildShareUrl(query));
}

function buildShareUrl(query) {
  const url = new URL(location.href);
  ["q", "query", "username", "user", "name", "usernames", "id", "ids", "userId", "userid", "uid", "search"]
    .forEach(key => url.searchParams.delete(key));

  const value = String(query || "").trim();
  if (!value) return url;
  if (/^id:\s*\d+$/i.test(value)) url.searchParams.set("id", value.replace(/^id:\s*/i, ""));
  else if (/^search:\s*.+$/i.test(value)) url.searchParams.set("search", value.replace(/^search:\s*/i, ""));
  else if (/^[A-Za-z0-9_]{3,20}$/.test(value)) url.searchParams.set("username", value);
  else url.searchParams.set("q", value);
  return url;
}

function setStatus(message, isError = false, options = {}) {
  if (statusEl) statusEl.textContent = message || "";
  if (statusWrap) {
    statusWrap.hidden = !message;
    statusWrap.classList.toggle("error", Boolean(isError));
    statusWrap.classList.toggle("loading", Boolean(options.loading));
  }
  if (resultProgress) resultProgress.textContent = options.progress || "";
}

function cleanError(err) {
  if (Number(err?.status) === 429) {
    return getProviderMode() === "rolimons-first"
      ? "Roblox rate-limited a core account/avatar endpoint. Rolimons-first is already skipping most catalog/economy fallbacks, but Rolimons cannot replace Roblox username, avatar-state, or saved-outfit endpoints."
      : "Roblox rate-limited this Worker. Enable Prefer Rolimons to reduce catalog/economy requests, or wait for Roblox's limit to reset.";
  }

  let message = err?.message || String(err);
  message = message.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
  return message.length > 260 ? `${message.slice(0, 260)}…` : message;
}

function looksLikeStaticHost404(text, response) {
  return response.status === 404 && (text.includes("Page not found") || text.includes("File not found"));
}

function chip(text, kind = "") {
  const el = document.createElement("span");
  el.className = `chip ${kind}`.trim();
  el.textContent = text;
  return el;
}

function uniqueBy(array, keyFn) {
  const seen = new Set();
  return array.filter(item => {
    const key = keyFn(item);
    if (key === undefined || key === null || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function normalizeName(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

function formatDate(value) {
  if (!value) return "unknown";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "unknown";
  return date.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

function formatInteger(value) {
  const number = Number(value);
  return Number.isFinite(number) ? new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 }).format(number) : "?";
}

function finiteOrNull(value) {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 ? number : null;
}

function integerOrNull(value) {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  return Number.isInteger(number) ? number : null;
}

function downloadJson(name, data) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = name;
  link.click();
  URL.revokeObjectURL(url);
}

function openDialog(dialog) {
  if (!dialog) return;
  if (typeof dialog.showModal === "function") dialog.showModal();
  else dialog.setAttribute("open", "");
}

function addServerLogs(scope, logs = []) {
  for (const message of logs || []) logInfo(`Worker ${scope}: ${message}`);
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
    preview: err?.preview
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
      if (typeof value === "string" && value.length > 800) return `${value.slice(0, 800)}…`;
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
    tracked: data.tracked,
    mode: data.debug?.mode || undefined,
    rolimons: data.debug?.rolimons || undefined
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
  try {
    localStorage.setItem(LOG_STORAGE_KEY, JSON.stringify(debugLogs));
  } catch {}
}

function renderConsole() {
  if (!debugConsole) return;
  debugConsole.textContent = debugLogs.length ? debugLogs.map(formatLogLine).join("\n") : "No logs yet.";
}

function formatLogLine(entry) {
  const data = entry.data === undefined ? "" : `\n${JSON.stringify(entry.data, null, 2)}`;
  return `[${entry.time}] ${entry.level.toUpperCase()} ${entry.message}${data}`;
}

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>'"]/g, char => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "'": "&#39;",
    '"': "&quot;"
  })[char]);
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/`/g, "&#96;");
}
