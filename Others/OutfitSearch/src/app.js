import { $, chip, downloadJson, openDialog } from "./dom.js";
import { assetCard, outfitCard, createSkeletonSlot } from "./cards.js";
import {
  mapLimit,
  isHttpUrl,
  normalizeApiBase,
  uniqueBy,
  formatDate,
  escapeHtml,
} from "./format.js";

import {
  splitOutfits,
  classifyOutfitEntry,
  prepareDisplayAssets,
} from "./outfits.js";

const APP_VERSION = "2026-09-27.ui4-compact-motion-commerce";
const DEFAULT_API_BASE =
  document.querySelector('meta[name="outfit-api-base"]')?.content?.trim() || "";
const API_STORAGE_KEY = "robloxOutfitApiBase";
const LOG_STORAGE_KEY = "robloxOutfitDebugLogs";
const THEME_STORAGE_KEY = "robloxOutfitTheme";
const PROVIDER_MODE_STORAGE_KEY = "robloxOutfitProviderMode";
const MAX_LOGS = 300;
const SEARCH_CONCURRENCY = 3;
const API_TIMEOUT_MS = 35000;
const REPORT_TIMEOUT_MS = 45000;
const OUTFIT_TIMEOUT_MS = 40000;
const DETAIL_CACHE_TTL_MS = 5 * 60 * 1000;
const OUTFIT_WARM_LIMIT = 12;
const OUTFIT_WARM_CONCURRENCY = 2;
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
const resultsToolbar = $("#resultsToolbar");
const resultsSummary = $("#resultsSummary");
const expandAllBtn = $("#expandAllBtn");
const collapseAllBtn = $("#collapseAllBtn");
const rolimonsFirstToggle = $("#rolimonsFirstToggle");
const themeBtn = $("#themeBtn");
const apiParam = new URL(location.href).searchParams.get("api");

if (apiParam === "clear") {
  localStorage.removeItem(API_STORAGE_KEY);
} else if (isHttpUrl(apiParam)) {
  localStorage.setItem(API_STORAGE_KEY, normalizeApiBase(apiParam));
}

let apiBase =
  normalizeApiBase(apiParam) ||
  normalizeApiBase(localStorage.getItem(API_STORAGE_KEY)) ||
  normalizeApiBase(DEFAULT_API_BASE);
let debugLogs = loadLogs();
let activeSearchController = null;
let activeSearchGeneration = 0;
let apiConnectionState = hasConfiguredApi() ? "saved" : "offline";
let workerCapabilities = { rolimons: false, version: null, requestModes: [] };

class OutfitDetailStore {
  constructor() {
    this.cache = new Map();
    this.inflight = new Map();
    this.warming = new Set();
  }

  cacheKey(id) {
    return `${apiBase}|${getProviderMode()}|${Number(id)}`;
  }

  clearAll() {
    this.cache.clear();
    this.inflight.clear();
    this.warming.clear();
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
    if (!Number.isSafeInteger(outfitId) || outfitId <= 0)
      throw new Error("Invalid outfit ID.");

    const cached = this.getCached(outfitId);
    if (cached) {
      if (!options.quiet) logInfo("Outfit detail cache hit.", { outfitId });
      return cached;
    }

    const key = this.cacheKey(outfitId);
    const existing = this.inflight.get(key);
    if (existing) {
      if (!options.quiet)
        logInfo("Outfit detail request deduplicated.", { outfitId });
      return existing;
    }

    const request = (async () => {
      const detail = await api(
        `/api/outfit/${outfitId}?mode=${encodeURIComponent(getProviderMode())}`,
        {
          signal: options.signal,
          timeoutMs: OUTFIT_TIMEOUT_MS,
          logQuietly: Boolean(options.quiet),
        },
      );
      addServerLogs(`outfit:${outfitId}`, detail.debug?.logs);
      this.cache.set(key, { data: detail, savedAt: Date.now() });
      return detail;
    })();

    this.inflight.set(key, request);
    try {
      return await request;
    } finally {
      if (this.inflight.get(key) === request) this.inflight.delete(key);
    }
  }

  warm(entries = [], context = {}) {
    const ids = uniqueBy(entries.filter(Boolean), (entry) => Number(entry.id))
      .map((entry) => Number(entry.id))
      .filter((id) => Number.isSafeInteger(id) && id > 0)
      .filter(
        (id) => !this.getCached(id) && !this.warming.has(this.cacheKey(id)),
      )
      .slice(0, OUTFIT_WARM_LIMIT);

    if (!ids.length) return;
    ids.forEach((id) => this.warming.add(this.cacheKey(id)));

    void mapLimit(ids, OUTFIT_WARM_CONCURRENCY, async (id) => {
      try {
        await this.get(id, { quiet: true });
      } catch (err) {
        if (err?.status === 429) {
          logInfo(
            "Stopped background outfit warming after Roblox rate limiting.",
            { userId: context.userId || null },
          );
          return;
        }
      } finally {
        this.warming.delete(this.cacheKey(id));
      }
    });
  }
}

const outfitDetails = new OutfitDetailStore();

init();

function init() {
  applyTheme(getSavedTheme());
  refreshApiUi();
  initProviderModeOption();
  renderConsole();
  bindUi();

  logInfo("App loaded.", {
    appVersion: APP_VERSION,
    apiConfigured: hasConfiguredApi(),
    apiBase: hasConfiguredApi() ? apiBase : null,
    providerMode: getProviderMode(),
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
    apiBase = "";
    workerCapabilities = { rolimons: false, version: null, requestModes: [] };
    outfitDetails.clearAll();
    results.innerHTML = "";
    resultsToolbar.hidden = true;
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
    const nextTheme = document.documentElement.classList.contains("light")
      ? "dark"
      : "light";
    applyTheme(nextTheme);
    localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
    localStorage.setItem("theme", nextTheme);
    logInfo("Theme changed.", { theme: nextTheme });
  });

  instructionsBtn?.addEventListener("click", () =>
    openDialog(instructionsDialog),
  );
  consoleBtn?.addEventListener("click", () => {
    renderConsole();
    openDialog(consoleDialog);
  });

  for (const btn of document.querySelectorAll("[data-close-dialog]")) {
    btn.addEventListener("click", () =>
      document.getElementById(btn.dataset.closeDialog)?.close(),
    );
  }

  for (const dialog of document.querySelectorAll("dialog")) {
    dialog.addEventListener("click", (event) => {
      if (event.target === dialog) dialog.close();
    });
  }

  copyConsoleBtn?.addEventListener("click", async () => {
    const text = debugLogs.map(formatLogLine).join("\n");
    try {
      await navigator.clipboard.writeText(text || "No logs yet.");
      copyConsoleBtn.textContent = "Copied";
      setTimeout(() => (copyConsoleBtn.textContent = "Copy"), 1000);
    } catch {
      setStatus("Could not copy logs from this browser.", true);
    }
  });

  clearConsoleBtn?.addEventListener("click", () => {
    debugLogs = [];
    saveLogs();
    renderConsole();
  });

  expandAllBtn?.addEventListener("click", () => setAllUsersCollapsed(false));
  collapseAllBtn?.addEventListener("click", () => setAllUsersCollapsed(true));

  rolimonsFirstToggle?.addEventListener("change", () => {
    localStorage.setItem(
      PROVIDER_MODE_STORAGE_KEY,
      rolimonsFirstToggle.checked ? "rolimons-first" : "full",
    );
    outfitDetails.clearAll();

    if (rolimonsFirstToggle.checked) {
      const supportsMode =
        workerCapabilities.rolimons &&
        workerCapabilities.requestModes.includes("rolimons-first");
      setStatus(
        supportsMode
          ? "Rolimons-first enabled. Search again to reduce Roblox catalog requests."
          : "Rolimons-first selected, but the connected Worker is too old. Deploy the new worker.js first.",
        !supportsMode,
      );
    } else {
      setStatus(
        "Full Roblox enrichment enabled. This uses more Roblox catalog/economy requests.",
      );
    }

    logInfo("Provider preference changed.", {
      mode: getProviderMode(),
      workerSupportsRolimons: workerCapabilities.rolimons,
    });
  });

  copyLinkBtn?.addEventListener("click", async () => {
    const url = buildShareUrl(queryInput.value.trim()).toString();
    try {
      await navigator.clipboard.writeText(url);
      copyLinkBtn.textContent = "Copied link";
      setTimeout(() => (copyLinkBtn.textContent = "Copy search link"), 1100);
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

  cancelSearchBtn?.addEventListener("click", () =>
    activeSearchController?.abort("cancelled"),
  );
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
    apiStatus.textContent = "Enter your Worker URL.";
    return;
  }

  localStorage.setItem(API_STORAGE_KEY, value);
  apiBase = value;
  outfitDetails.clearAll();
  saveApiBtn.disabled = true;
  saveApiBtn.textContent = "Checking…";
  refreshApiUi("Checking the Worker…", "saved");

  try {
    const health = await verifyApiConnection();
    setStatus(
      workerCapabilities.rolimons
        ? "Worker connected. Rolimons enrichment is enabled."
        : "Connected. No Rolimons support reported.",
    );
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
    requestModes: Array.isArray(health.requestModes?.supported)
      ? health.requestModes.supported
      : [],
  };

  syncProviderModeUi();

  const providerText = workerCapabilities.rolimons
    ? ` · Rolimons${getProviderMode() === "rolimons-first" ? "-first" : ""}`
    : "";
  refreshApiUi(
    `Connected · Worker ${health.version || "ready"}${providerText}`,
    "online",
  );
  logSuccess("API health check succeeded.", {
    version: health.version,
    providers: health.providers || null,
  });

  if (workerCapabilities.rolimons) {
    // Check market data in the background.
    verifyRolimonsBridge();
  }

  return health;
}

async function verifyRolimonsBridge() {
  try {
    const sample = await api("/api/rolimons/item/1029025", {
      timeoutMs: 16000,
      logQuietly: true,
    });
    logSuccess("Rolimons Worker bridge responded.", {
      tracked: sample.tracked,
      name: sample.item?.name || null,
    });
  } catch (err) {
    logError(
      "Rolimons Worker bridge check failed; Roblox data can still load.",
      err,
    );
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

  outfitDetails.clearAll();
  results.innerHTML = "";
  resultsToolbar.hidden = true;
  emptyState.hidden = true;
  searchBtn.disabled = true;
  cancelSearchBtn.hidden = false;
  setStatus("Finding Roblox account(s)…", false, { loading: true });
  logInfo("Search started.", {
    query,
    generation,
    providerMode: getProviderMode(),
  });

  try {
    const resolved = await api(
      `/api/resolve?q=${encodeURIComponent(query)}&mode=${encodeURIComponent(getProviderMode())}`,
      {
        signal: controller.signal,
        timeoutMs: API_TIMEOUT_MS,
      },
    );
    if (generation !== activeSearchGeneration) return;

    addServerLogs("resolve", resolved.logs);
    const candidates = uniqueBy(resolved.users || [], (user) => user.id);
    if (!candidates.length) {
      setStatus("No public Roblox accounts matched that search.", true);
      resultsToolbar.hidden = true;
      emptyState.hidden = false;
      return;
    }

    resultsToolbar.hidden = false;
    resultsSummary.textContent = `${candidates.length} account${candidates.length === 1 ? "" : "s"}`;

    const slots = candidates.map((user, index) =>
      createSkeletonSlot(user, index),
    );
    slots.forEach((slot) => results.append(slot));
    setStatus(`Found ${candidates.length}. Loading avatar data…`, false, {
      loading: true,
      progress: `0 / ${candidates.length}`,
    });

    let shown = 0;
    let finished = 0;

    await mapLimit(candidates, SEARCH_CONCURRENCY, async (user, index) => {
      if (controller.signal.aborted || generation !== activeSearchGeneration)
        return;

      try {
        const reportParams = new URLSearchParams({
          mode: getProviderMode(),
        });
        if (user.name) reportParams.set("username", user.name);
        if (user.displayName) reportParams.set("displayName", user.displayName);
        if (user.hasVerifiedBadge) reportParams.set("verified", "1");

        const report = await api(
          `/api/report/${user.id}?${reportParams.toString()}`,
          {
            signal: controller.signal,
            timeoutMs: REPORT_TIMEOUT_MS,
          },
        );
        if (controller.signal.aborted || generation !== activeSearchGeneration)
          return;

        addServerLogs(`report:${user.id}`, report.debug?.logs);
        renderUser(report, slots[index], index);
        shown += 1;
        logSuccess("Account report rendered.", {
          id: user.id,
          name: user.name,
          wearing: report.currentlyWearing?.length || 0,
          outfits: report.outfits?.length || 0,
          rolimons: report.debug?.rolimons || null,
        });
      } catch (err) {
        if (err?.name === "AbortError") return;
        renderErrorCard(user, err, slots[index]);
        logError("Account report failed.", err, {
          id: user.id,
          name: user.name,
        });
      } finally {
        finished += 1;
        if (
          !controller.signal.aborted &&
          generation === activeSearchGeneration
        ) {
          setStatus("Loading account data…", false, {
            loading: finished < candidates.length,
            progress: `${finished} / ${candidates.length}`,
          });
        }
      }
    });

    if (generation === activeSearchGeneration && !controller.signal.aborted) {
      setStatus(
        `Loaded ${shown} of ${candidates.length} account${candidates.length === 1 ? "" : "s"}.`,
        false,
        {
          progress: `${shown} shown`,
        },
      );
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
  const url = `${apiBase}${path}`;
  const timeoutMs = options.timeoutMs || API_TIMEOUT_MS;
  const requestController = new AbortController();
  const started = performance.now();
  const timeoutId = setTimeout(
    () => requestController.abort("timeout"),
    timeoutMs,
  );
  const abortFromParent = () => requestController.abort("cancelled");

  if (options.signal) {
    if (options.signal.aborted) abortFromParent();
    else
      options.signal.addEventListener("abort", abortFromParent, { once: true });
  }

  if (!options.logQuietly) logInfo("API request started.", { path, url });

  try {
    const response = await fetch(url, {
      method: "GET",
      headers: { accept: "application/json" },
      signal: requestController.signal,
    });

    const text = await response.text();
    const elapsedMs = Math.round(performance.now() - started);
    let data;

    try {
      data = text ? JSON.parse(text) : {};
    } catch {
      const preview = text.slice(0, 600).replace(/\s+/g, " ").trim();
      const message = looksLikeStaticHost404(text, response)
        ? "API URL returned a website 404."
        : `The API returned non-JSON text. Status ${response.status}.`;
      const err = new Error(message);
      err.status = response.status;
      err.preview = preview;
      throw err;
    }

    if (!response.ok) {
      const err = new Error(
        data.error ||
          data.message ||
          data.errors?.[0]?.message ||
          `HTTP ${response.status}`,
      );
      err.status = response.status;
      err.details = data.details || data;
      throw err;
    }

    if (!options.logQuietly) {
      logSuccess("API request succeeded.", {
        path,
        status: response.status,
        elapsedMs,
        summary: summarizeApiData(data),
      });
    }

    return data;
  } catch (err) {
    if (
      options.signal?.aborted ||
      requestController.signal.reason === "cancelled"
    ) {
      const cancelled = new Error("Request cancelled.");
      cancelled.name = "AbortError";
      throw cancelled;
    }

    if (requestController.signal.aborted) {
      const timedOut = new Error(
        `The API took longer than ${Math.round(timeoutMs / 1000)} seconds.`,
      );
      timedOut.status = 504;
      if (!options.logQuietly)
        logError("API request timed out.", timedOut, { path, timeoutMs });
      throw timedOut;
    }

    if (!options.logQuietly)
      logError("API request failed.", err, { path, url });
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

  $(".avatar-index", tpl).textContent =
    `#${String(index + 1).padStart(2, "0")}`;
  $(".profile-handle", tpl).textContent = `@${profile.name || "unknown"}`;
  $(".profile-title", tpl).textContent =
    `${profile.displayName || profile.name || "Unknown"}${profile.hasVerifiedBadge ? " ✓" : ""}`;
  $(".profile-meta", tpl).textContent =
    `ID ${profile.id} · joined ${formatDate(profile.created)}`;
  $(".profile-link", tpl).href =
    `https://www.roblox.com/users/${profile.id}/profile`;
  $(".description-text", tpl).textContent =
    profile.description || "No public description.";

  const chips = $(".chips", tpl);
  chips.append(
    chip(
      profile.isBanned ? "Banned" : "Account active",
      profile.isBanned ? "bad" : "good",
    ),
  );
  if (profile.hasVerifiedBadge) chips.append(chip("Verified"));
  if (report.debug?.duplicateIds?.length)
    chips.append(
      chip(`${report.debug.duplicateIds.length} duplicate ID(s) removed`),
    );
  if (report.debug?.mode === "rolimons-first")
    chips.append(chip("Rolimons-first"));
  if (profile.partialProfile) chips.append(chip("Partial profile"));

  const roliStats = report.debug?.rolimons;
  if (roliStats && Number.isFinite(Number(roliStats.requested))) {
    chips.append(
      chip(
        `Rolimons ${Number(roliStats.matched || 0)}/${Number(roliStats.requested || 0)}`,
      ),
    );
  }

  const wearing = uniqueBy(report.currentlyWearing || [], (item) =>
    Number(item.id),
  );
  $(".wearing-count", tpl).textContent =
    `${wearing.length} item${wearing.length === 1 ? "" : "s"}`;
  $(".wearing-stat", tpl).textContent = wearing.length;
  const wearingGrid = $(".wearing-grid", tpl);
  if (!wearing.length)
    wearingGrid.innerHTML = `<div class="empty">No public currently-wearing assets were returned.</div>`;
  wearing.forEach((item) => wearingGrid.append(assetCard(item)));

  const emoteSection = createEmoteSection(
    report.emotes || [],
    report.debug?.emoteLogs || [],
  );
  wearingGrid.closest("section")?.after(emoteSection);

  const groups = splitOutfits(report.outfits || []);
  const outfits = groups.saved;
  const costumeLike = groups.costumeLike;
  const animationPacks = groups.animationPacks;
  const characterPackages = groups.characterPackages;

  $(".outfit-count", tpl).textContent =
    `${outfits.length} outfit${outfits.length === 1 ? "" : "s"}`;
  $(".outfit-stat", tpl).textContent = outfits.length;
  $(".extra-stat", tpl).textContent =
    (report.emotes?.length || 0) +
    costumeLike.length +
    animationPacks.length +
    characterPackages.length;

  const outfitGrid = $(".outfit-grid", tpl);
  const sectionsRoot = $(".user-sections", tpl);
  if (!outfits.length)
    outfitGrid.innerHTML = `<div class="empty">No normal saved outfits were returned.</div>`;
  outfits.forEach((outfit) =>
    outfitGrid.append(outfitCard(outfit, "Outfit", openOutfit)),
  );

  if (characterPackages.length) {
    sectionsRoot.append(
      createExtraOutfitSection(
        "Character presets",
        "Marketplace character packages.",
        characterPackages,
        "Package entry",
        "packs",
      ),
    );
  }

  if (animationPacks.length) {
    sectionsRoot.append(
      createExtraOutfitSection(
        "Animation packs",
        "Run, walk and other animations.",
        animationPacks,
        "Animation pack",
        "packs",
      ),
    );
  }

  if (costumeLike.length)
    sectionsRoot.append(createCostumeSection(costumeLike));

  $(".json-btn", tpl).addEventListener("click", () =>
    downloadJson(`roblox-${profile.id}-outfits.json`, report),
  );
  setupUserTabs(article);

  const allEntries = [
    ...outfits,
    ...characterPackages,
    ...animationPacks,
    ...costumeLike,
  ];
  setupUserCollapse(article, index > 0, () =>
    outfitDetails.warm(allEntries, { userId: profile.id }),
  );

  if (mount) mount.replaceChildren(tpl);
  else results.append(tpl);

  if (index === 0) outfitDetails.warm(allEntries, { userId: profile.id });
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
    const detail = await outfitDetails.get(outfitId);
    if (!outfitDialog.open) return;

    const entryKind = classifyOutfitEntry(outfit);
    const prepared = prepareDisplayAssets(detail.assets || [], {
      mode: entryKind === "animation" ? "animationPack" : "normal",
      outfitName: detail.name || outfit.name || "Animation pack",
    });

    const assets = prepared.assets;
    count.textContent = `${assets.length} item${assets.length === 1 ? "" : "s"}`;
    grid.innerHTML = "";

    if (!assets.length) {
      grid.innerHTML = `<div class="empty">No displayable assets returned for this entry.</div>`;
      return;
    }

    assets.forEach((asset) => grid.append(assetCard(asset)));
    if (
      prepared.hiddenStandaloneAnimations ||
      prepared.groupedBundleComponents
    ) {
      const note = document.createElement("div");
      note.className = "empty";
      note.textContent = prepared.packComponentMode
        ? `${prepared.packComponentsShown} pack components.`
        : `${prepared.groupedBundleComponents} bundle components grouped; ${prepared.hiddenStandaloneAnimations} standalone animations hidden.`;
      grid.append(note);
    }

    logSuccess("Outfit items rendered.", {
      outfitId,
      assets: assets.length,
      rolimonsTracked: assets.filter((asset) => asset.rolimons).length,
    });
  } catch (err) {
    if (err?.name === "AbortError") return;
    count.textContent = "Error";
    grid.innerHTML = `<div class="empty danger-text">${escapeHtml(cleanError(err))}</div>`;
    logError("Outfit items failed.", err, { outfitId });
  }
}

function createEmoteSection(emotes = [], logs = []) {
  const section = document.createElement("section");
  section.className = "emote-section";
  section.dataset.resultKind = "emotes";
  const visible = Array.isArray(emotes) ? emotes.filter(Boolean) : [];
  const logText = logs.length
    ? logs.join(" ")
    : "No public equipped-emote data was returned.";

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
  if (!visible.length)
    grid.innerHTML = `<div class="empty">${escapeHtml(logText)}</div>`;
  else
    visible.forEach((emote) =>
      grid.append(
        assetCard({
          ...emote,
          itemType: "Emote",
          assetTypeName: "Emote Animation",
        }),
      ),
    );
  return section;
}

function setupUserCollapse(article, collapsed = false, onExpand = null) {
  const button = $(".user-collapse-btn", article);
  if (!button) return;
  let warmed = false;

  const apply = (value) => {
    setUserCollapsed(article, value);
    if (!value && !warmed && typeof onExpand === "function") {
      warmed = true;
      onExpand();
    }
  };

  button.addEventListener("click", () =>
    apply(!article.classList.contains("is-collapsed")),
  );
  article.addEventListener("outfitsearch:set-collapsed", (event) =>
    apply(Boolean(event.detail?.collapsed)),
  );
  apply(collapsed);
}

function setUserCollapsed(article, collapsed) {
  if (!article) return;
  article.classList.toggle("is-collapsed", Boolean(collapsed));
  const button = $(".user-collapse-btn", article);
  const label = $(".collapse-label", article);
  const icon = $(".collapse-icon", article);
  button?.setAttribute("aria-expanded", String(!collapsed));
  button?.setAttribute(
    "aria-label",
    collapsed ? "Expand account details" : "Collapse account details",
  );
  if (label) label.textContent = collapsed ? "Expand" : "Collapse";
  if (icon) icon.textContent = collapsed ? "⌄" : "⌃";
}

function setAllUsersCollapsed(collapsed) {
  const cards = [...results.querySelectorAll(".user-card:not(.error-card)")];
  cards.forEach((card) =>
    card.dispatchEvent(
      new CustomEvent("outfitsearch:set-collapsed", { detail: { collapsed } }),
    ),
  );
  if (cards.length) {
    setStatus(
      `${collapsed ? "Collapsed" : "Expanded"} ${cards.length} account${cards.length === 1 ? "" : "s"}.`,
    );
  }
}

function setupUserTabs(article) {
  const tabs = [...article.querySelectorAll(".result-tab")];
  const sections = [...article.querySelectorAll("[data-result-kind]")];

  for (const tab of tabs) {
    const view = tab.dataset.view;
    if (
      view !== "all" &&
      !sections.some((section) => section.dataset.resultKind === view)
    ) {
      tab.classList.add("unavailable");
      tab.setAttribute("aria-disabled", "true");
    }

    tab.addEventListener("click", () => {
      if (tab.classList.contains("unavailable")) return;
      tabs.forEach((candidate) =>
        candidate.classList.toggle("active", candidate === tab),
      );
      sections.forEach((section) => {
        const visible = view === "all" || section.dataset.resultKind === view;
        section.hidden = !visible;
        if (visible) {
          section.classList.remove("section-enter");
          void section.offsetWidth;
          section.classList.add("section-enter");
        }
      });
    });
  }
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
  items.forEach((item) => grid.append(outfitCard(item, label, openOutfit)));
  return section;
}

function createCostumeSection(items) {
  return createExtraOutfitSection(
    "Dynamic Heads",
    "Avatar costumes.",
    items,
    "Costume entry",
    "outfits",
  );
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

function initProviderModeOption() {
  if (!rolimonsFirstToggle) return;
  rolimonsFirstToggle.checked =
    localStorage.getItem(PROVIDER_MODE_STORAGE_KEY) !== "full";
  syncProviderModeUi();
}

function syncProviderModeUi() {
  if (!rolimonsFirstToggle) return;
  const modeSupported =
    workerCapabilities.requestModes.includes("rolimons-first");
  const explicitlyUnsupported =
    apiConnectionState === "online" &&
    (!workerCapabilities.rolimons || !modeSupported);
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
    const supported =
      workerCapabilities.rolimons &&
      workerCapabilities.requestModes.includes("rolimons-first");
    if (!supported) return "full";
  }
  return "rolimons-first";
}

function hasConfiguredApi() {
  return Boolean(apiBase);
}

function refreshApiUi(message = "", state = apiConnectionState) {
  apiConnectionState = state;
  if (apiBaseInput) apiBaseInput.value = hasConfiguredApi() ? apiBase : "";
  if (apiDot)
    apiDot.className = `status-dot${state === "online" ? " online" : state === "error" ? " error" : ""}`;
  if (apiState) {
    apiState.className = `connection-state${state === "online" ? " online" : state === "error" ? " error" : ""}`;
    apiState.textContent =
      state === "online"
        ? workerCapabilities.rolimons
          ? getProviderMode() === "rolimons-first"
            ? "Rolimons-first API"
            : "API + Rolimons connected"
          : "API connected"
        : state === "error"
          ? "API connection failed"
          : hasConfiguredApi()
            ? "API URL saved"
            : "API not connected";
  }
  if (apiButtonLabel)
    apiButtonLabel.textContent = hasConfiguredApi()
      ? "API setup"
      : "Connect API";
  if (apiStatus)
    apiStatus.textContent =
      message ||
      (hasConfiguredApi()
        ? `Saved: ${apiBase}`
        : "No Worker URL saved in this browser.");
}

function getSavedTheme() {
  const saved =
    localStorage.getItem(THEME_STORAGE_KEY) || localStorage.getItem("theme");
  if (saved === "light" || saved === "dark") return saved;
  return window.matchMedia?.("(prefers-color-scheme: light)")?.matches
    ? "light"
    : "dark";
}

function applyTheme(theme) {
  const light = theme === "light";
  document.documentElement.classList.toggle("light", light);
  document.documentElement.dataset.theme = light ? "light" : "dark";
  if (themeBtn) {
    themeBtn.setAttribute("aria-pressed", String(light));
    themeBtn.setAttribute(
      "aria-label",
      light ? "Switch to dark theme" : "Switch to light theme",
    );
    themeBtn.title = light ? "Switch to dark theme" : "Switch to light theme";
  }
}

function getInitialQueryFromUrl() {
  const params = new URL(location.href).searchParams;
  const parts = [];

  collectParamValues(params, ["id", "ids", "userId", "userid", "uid"]).forEach(
    (value) => {
      for (const part of splitParamList(value)) {
        const id = part.replace(/^id:/i, "").trim();
        if (/^\d+$/.test(id)) parts.push(`id:${id}`);
      }
    },
  );

  collectParamValues(params, ["username", "user", "name", "usernames"]).forEach(
    (value) => {
      parts.push(
        ...splitParamList(value)
          .map((part) => part.replace(/^@/, "").trim())
          .filter(Boolean),
      );
    },
  );

  collectParamValues(params, ["search"]).forEach((value) => {
    for (const part of splitParamList(value))
      if (part) parts.push(`search:${part}`);
  });

  parts.push(
    ...collectParamValues(params, ["q", "query"])
      .flatMap(splitParamList)
      .filter(Boolean),
  );
  return uniqueBy(parts, (value) => value.toLowerCase()).join(", ");
}

function collectParamValues(params, keys) {
  return keys
    .flatMap((key) => params.getAll(key))
    .filter((value) => String(value ?? "").trim());
}

function splitParamList(value) {
  return String(value || "")
    .split(/[\n,;]+/)
    .map((part) => part.trim())
    .filter(Boolean);
}

function updateUrlForSearch(query) {
  history.replaceState(null, "", buildShareUrl(query));
}

function buildShareUrl(query) {
  const url = new URL(location.href);
  [
    "q",
    "query",
    "username",
    "user",
    "name",
    "usernames",
    "id",
    "ids",
    "userId",
    "userid",
    "uid",
    "search",
  ].forEach((key) => url.searchParams.delete(key));

  const value = String(query || "").trim();
  if (!value) return url;
  if (/^id:\s*\d+$/i.test(value))
    url.searchParams.set("id", value.replace(/^id:\s*/i, ""));
  else if (/^search:\s*.+$/i.test(value))
    url.searchParams.set("search", value.replace(/^search:\s*/i, ""));
  else if (/^[A-Za-z0-9_]{3,20}$/.test(value))
    url.searchParams.set("username", value);
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
      ? "Roblox rate limit reached. Try again later."
      : "Roblox rate limit reached. Try later or enable Prefer Rolimons.";
  }

  let message = err?.message || String(err);
  message = message
    .replace(/<[^>]*>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return message.length > 260 ? `${message.slice(0, 260)}…` : message;
}

function looksLikeStaticHost404(text, response) {
  return (
    response.status === 404 &&
    (text.includes("Page not found") || text.includes("File not found"))
  );
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
    preview: err?.preview,
  });
}

function pushLog(level, message, data = undefined) {
  debugLogs.push({
    time: new Date().toISOString(),
    level,
    message,
    data: compactForLog(data),
  });
  if (debugLogs.length > MAX_LOGS) debugLogs = debugLogs.slice(-MAX_LOGS);
  saveLogs();
  renderConsole();
}

function compactForLog(data) {
  if (data === undefined) return undefined;
  try {
    return JSON.parse(
      JSON.stringify(data, (_, value) => {
        if (typeof value === "string" && value.length > 800)
          return `${value.slice(0, 800)}…`;
        return value;
      }),
    );
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
    currentlyWearing: Array.isArray(data.currentlyWearing)
      ? data.currentlyWearing.length
      : undefined,
    outfits: Array.isArray(data.outfits) ? data.outfits.length : undefined,
    assets: Array.isArray(data.assets) ? data.assets.length : undefined,
    tracked: data.tracked,
    mode: data.debug?.mode || undefined,
    rolimons: data.debug?.rolimons || undefined,
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
  debugConsole.textContent = debugLogs.length
    ? debugLogs.map(formatLogLine).join("\n")
    : "No logs yet.";
}

function formatLogLine(entry) {
  const data =
    entry.data === undefined ? "" : `\n${JSON.stringify(entry.data, null, 2)}`;
  return `[${entry.time}] ${entry.level.toUpperCase()} ${entry.message}${data}`;
}
