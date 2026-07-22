const ENDPOINTS = Object.freeze({
  weaoExploits: "https://weao.xyz/api/status/exploits",
  weaoVersions: "https://weao.xyz/api/versions/current",
  weaoExploitsFallback: "https://whatexpsare.online/api/status/exploits",
  weaoVersionsFallback: "https://whatexpsare.online/api/versions/current",
  voxlisContents: "https://api.github.com/repos/localscripts/voxlis.NET/contents/public/data/roblox?ref=main",
  voxlisFlatTree: "https://data.jsdelivr.com/v1/package/gh/localscripts/voxlis.NET@main/flat",
  voxlisRaw: "https://raw.githubusercontent.com/localscripts/voxlis.NET/main/public/data/roblox",
  voxlisPrices: "https://raw.githubusercontent.com/localscripts/voxlis.NET/main/public/data/roblox/prices.json"
});

const CACHE_KEY = "synchrose:catalog:v3";
const CACHE_MAX_AGE = 24 * 60 * 60 * 1000;
const COMPARE_LIMIT = 4;

const PLATFORM_LABELS = Object.freeze({
  windows: "Windows",
  mac: "macOS",
  android: "Android",
  ios: "iOS",
  unknown: "Unknown"
});

const NAME_ALIASES = Object.freeze({
  arceusxneo: "arceusx",
  arceusx: "arceusx",
  vegax: "vegax",
  yubx: "yubx",
  macsploit: "macsploit",
  matrixhub: "matrix",
  matrix: "matrix",
  dx9warev2: "dx9ware",
  bunnifun: "bunni"
});

const PRICE_ALIASES = Object.freeze({
  arceusxneo: "arceusx",
  arceusx: "arceusx",
  vegax: "vegax",
  macsploit: "macsploit",
  matrixhub: "matrix",
  matrix: "matrix",
  yubx: "yub-x",
  dx9warev2: "dx9ware",
  bunnifun: "bunni"
});

const state = {
  weaoRows: [],
  voxlisRows: [],
  all: [],
  filtered: [],
  versions: {},
  compare: new Set(),
  view: readStoredView(),
  loading: false,
  loadedAt: null,
  health: { weao: "loading", voxlis: "loading" }
};

const dom = {
  body: document.body,
  filterForm: document.querySelector("#filterForm"),
  searchInput: document.querySelector("#searchInput"),
  platformFilter: document.querySelector("#platformFilter"),
  statusFilter: document.querySelector("#statusFilter"),
  priceFilter: document.querySelector("#priceFilter"),
  sourceFilter: document.querySelector("#sourceFilter"),
  sortFilter: document.querySelector("#sortFilter"),
  clearFilters: document.querySelector("#clearFilters"),
  refreshData: document.querySelector("#refreshData"),
  heroRefresh: document.querySelector("#heroRefresh"),
  catalogResults: document.querySelector("#catalogResults"),
  gridView: document.querySelector("#gridView"),
  tableView: document.querySelector("#tableView"),
  tableBody: document.querySelector("#tableBody"),
  resultSummary: document.querySelector("#resultSummary"),
  versionGrid: document.querySelector("#versionGrid"),
  compareTray: document.querySelector("#compareTray"),
  comparePills: document.querySelector("#comparePills"),
  compareCount: document.querySelector("#compareCount"),
  clearCompare: document.querySelector("#clearCompare"),
  openCompare: document.querySelector("#openCompare"),
  detailDialog: document.querySelector("#detailDialog"),
  detailContent: document.querySelector("#detailContent"),
  compareDialog: document.querySelector("#compareDialog"),
  compareContent: document.querySelector("#compareContent"),
  toastRegion: document.querySelector("#toastRegion")
};

let searchTimer = 0;

bindEvents();
setView(state.view, { render: false });
hydrateFromCache();
loadData();

function bindEvents() {
  dom.filterForm?.addEventListener("submit", event => event.preventDefault());

  dom.searchInput?.addEventListener("input", () => {
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(applyFilters, 120);
  });

  [dom.platformFilter, dom.statusFilter, dom.priceFilter, dom.sourceFilter, dom.sortFilter]
    .filter(Boolean)
    .forEach(control => control.addEventListener("change", applyFilters));

  dom.clearFilters?.addEventListener("click", () => {
    dom.filterForm?.reset();
    applyFilters();
    dom.searchInput?.focus();
  });

  dom.refreshData?.addEventListener("click", () => loadData({ force: true }));
  dom.heroRefresh?.addEventListener("click", () => loadData({ force: true }));

  document.querySelectorAll("[data-view]").forEach(button => {
    button.addEventListener("click", () => setView(button.dataset.view));
  });

  dom.catalogResults?.addEventListener("click", event => {
    const detailsButton = event.target.closest("[data-details]");
    if (detailsButton) {
      openDetails(detailsButton.dataset.details);
      return;
    }

    const compareInput = event.target.closest("input[data-compare]");
    if (compareInput) {
      toggleCompare(compareInput.dataset.compare, compareInput.checked);
    }
  });

  dom.clearCompare?.addEventListener("click", clearCompare);
  dom.openCompare?.addEventListener("click", openComparison);

  document.querySelectorAll("[data-close-dialog]").forEach(button => {
    button.addEventListener("click", () => document.querySelector(`#${button.dataset.closeDialog}`)?.close());
  });

  [dom.detailDialog, dom.compareDialog].filter(Boolean).forEach(dialog => {
    dialog.addEventListener("click", event => {
      if (event.target === dialog) dialog.close();
    });
  });

  document.addEventListener("keydown", event => {
    const activeTag = document.activeElement?.tagName?.toLowerCase();
    const isTyping = activeTag === "input" || activeTag === "textarea" || activeTag === "select";
    if (event.key === "/" && !isTyping && !event.metaKey && !event.ctrlKey && !event.altKey) {
      event.preventDefault();
      dom.searchInput?.focus();
    }
  });

  document.querySelectorAll(".mobile-menu nav a").forEach(link => {
    link.addEventListener("click", () => link.closest("details")?.removeAttribute("open"));
  });
}

async function loadData({ force = false } = {}) {
  if (state.loading) return;

  state.loading = true;
  dom.body.classList.add("is-refreshing");
  dom.catalogResults?.setAttribute("aria-busy", "true");
  setHealth("weao", "loading");
  setHealth("voxlis", "loading");

  const weaoJob = fetchWeaoData()
    .then(({ rows, versions }) => {
      state.weaoRows = rows;
      state.versions = versions;
      state.loadedAt = new Date();
      setHealth("weao", "ready", rows.length);
      renderVersions();
      rebuildCatalog();
      saveCache();
      return true;
    })
    .catch(error => {
      console.warn("WEAO data unavailable", error);
      setHealth("weao", state.weaoRows.length ? "cached" : "error", state.weaoRows.length);
      if (!state.weaoRows.length) toast(`WEAO unavailable: ${friendlyError(error)}`, "error");
      return false;
    });

  const voxlisJob = fetchVoxlisData()
    .then(rows => {
      state.voxlisRows = rows;
      state.loadedAt = new Date();
      setHealth("voxlis", "ready", rows.length);
      rebuildCatalog();
      saveCache();
      return true;
    })
    .catch(error => {
      console.warn("Voxlis data unavailable", error);
      setHealth("voxlis", state.voxlisRows.length ? "cached" : "error", state.voxlisRows.length);
      if (!state.voxlisRows.length) toast(`Voxlis unavailable: ${friendlyError(error)}`, "error");
      return false;
    });

  const [weaoOkay, voxlisOkay] = await Promise.all([weaoJob, voxlisJob]);
  state.loading = false;
  dom.body.classList.remove("is-refreshing");
  dom.catalogResults?.setAttribute("aria-busy", "false");
  updateSyncHeadline();

  if (!state.all.length) renderLoadFailure();
  if (force && (weaoOkay || voxlisOkay)) toast("Live data refreshed.");
}

async function fetchWeaoData() {
  const [exploitsResult, versionsResult] = await Promise.allSettled([
    fetchJsonWithFallback(ENDPOINTS.weaoExploits, ENDPOINTS.weaoExploitsFallback),
    fetchJsonWithFallback(ENDPOINTS.weaoVersions, ENDPOINTS.weaoVersionsFallback)
  ]);

  if (exploitsResult.status === "rejected") throw exploitsResult.reason;

  const payload = exploitsResult.value;
  const items = Array.isArray(payload)
    ? payload
    : Array.isArray(payload?.data)
      ? payload.data
      : Array.isArray(payload?.exploits)
        ? payload.exploits
        : [];

  if (!items.length) throw new Error("The public status API returned no entries.");

  const versionsPayload = versionsResult.status === "fulfilled" ? versionsResult.value : {};
  const versions = versionsPayload?.data && !Array.isArray(versionsPayload.data)
    ? versionsPayload.data
    : versionsPayload || {};

  return {
    rows: items.map(item => normalizeWeaoRow(item, versions)).filter(row => row.name !== "Unknown"),
    versions
  };
}

async function fetchVoxlisData() {
  const [folders, prices] = await Promise.all([
    discoverVoxlisFolders(),
    fetchJson(ENDPOINTS.voxlisPrices).catch(error => {
      console.warn("Voxlis pricing unavailable", error);
      return {};
    })
  ]);

  if (!folders.length) throw new Error("No catalog folders were discovered.");

  const rows = await mapWithConcurrency(folders, 8, async folder => {
    try {
      const [info, points] = await Promise.all([
        fetchJson(voxlisFileUrl(folder, "info.json"), { allow404: true }),
        fetchJson(voxlisFileUrl(folder, "points.json"), { allow404: true })
      ]);

      if (!info || info.hidden === true) return null;
      return normalizeVoxlisRow(folder, info, points || {}, prices || {});
    } catch (error) {
      console.warn(`Skipping Voxlis entry ${folder}`, error);
      return null;
    }
  });

  const visibleRows = rows.filter(Boolean);
  if (!visibleRows.length) throw new Error("The catalog was reachable but no visible entries loaded.");
  return visibleRows;
}

async function discoverVoxlisFolders() {
  try {
    const contents = await fetchJson(ENDPOINTS.voxlisContents);
    const folders = Array.isArray(contents)
      ? contents.filter(entry => entry?.type === "dir" && entry?.name).map(entry => entry.name)
      : [];
    if (folders.length) return folders.sort((a, b) => a.localeCompare(b));
  } catch (error) {
    console.warn("GitHub folder discovery failed; trying jsDelivr", error);
  }

  const flat = await fetchJson(ENDPOINTS.voxlisFlatTree);
  const folders = new Set();
  for (const file of flat?.files || []) {
    const match = String(file?.name || "").match(/^\/?public\/data\/roblox\/([^/]+)\/info\.json$/i);
    if (match) folders.add(decodeURIComponent(match[1]));
  }
  return [...folders].sort((a, b) => a.localeCompare(b));
}

function normalizeWeaoRow(item, versions = {}) {
  const name = String(item?.title || item?.name || "Unknown").trim();
  const platform = normalizePlatform(item?.platform);
  const cost = String(item?.cost || "").trim();
  const free = item?.free === true || /\bfree\b/i.test(cost);
  const explicitUpdate = typeof item?.updateStatus === "boolean" ? item.updateStatus : null;
  const currentVersion = getVersionForPlatform(versions, platform);
  const productRobloxVersion = item?.rbxversion || item?.rbxVersion || "";
  const inferredUpdate = currentVersion && productRobloxVersion === currentVersion ? true : explicitUpdate;

  return {
    id: canonicalName(name),
    name,
    platforms: [platform],
    platform,
    version: cleanValue(item?.version),
    rbxVersion: cleanValue(productRobloxVersion),
    price: cost || (free ? "Free" : "Paid"),
    free,
    updateStatus: inferredUpdate,
    updateSource: "WEAO",
    detected: typeof item?.detected === "boolean" ? item.detected : null,
    suncPercentage: numericOrNull(item?.suncPercentage),
    uncPercentage: numericOrNull(item?.uncPercentage),
    extType: normalizeType(item?.extype || item?.type),
    description: cleanValue(item?.slug?.fullDescription || item?.description, ""),
    proSummary: "",
    neutralSummary: "",
    conSummary: "",
    website: safeUrl(item?.websitelink || item?.website),
    discord: safeUrl(item?.discordlink || item?.discord),
    purchaseLink: safeUrl(item?.purchaselink),
    owner: cleanValue(item?.slug?.owner, ""),
    updatedDate: cleanValue(item?.updatedDate),
    tags: [],
    badges: [],
    decompiler: item?.decompiler === true,
    multiInject: item?.multiInject === true,
    keysystem: item?.keysystem === true,
    clientmods: item?.clientmods === true,
    beta: item?.beta === true,
    verified: item?.elementCertified === true,
    warning: item?.hasIssues === true,
    sources: ["weao"],
    source: "weao",
    reviewUrl: null,
    review: ""
  };
}

function normalizeVoxlisRow(folder, info, points, prices) {
  const name = String(info?.name || folder).trim();
  const platforms = unique((Array.isArray(info?.platforms) && info.platforms.length
    ? info.platforms
    : [info?.platform || "unknown"]).map(normalizePlatform));
  const tags = unique(toArray(info?.tags).map(normalizeTag));
  const badges = unique(toArray(info?.badges).map(normalizeTag));
  const price = getVoxlisPrice(name, platforms, prices);
  const urls = info?.urls || {};
  const description = [points?.pro_summary, points?.neutral_summary, points?.con_summary]
    .map(value => String(value || "").trim())
    .filter(Boolean)
    .join(" ");

  return {
    id: canonicalName(name),
    name,
    platforms,
    platform: platforms[0] || "unknown",
    version: "N/A",
    rbxVersion: "N/A",
    price: price.label,
    free: price.free,
    updateStatus: null,
    updateSource: "",
    detected: null,
    suncPercentage: null,
    uncPercentage: null,
    extType: normalizeType(info?.type),
    description: description || "Catalog details are available from Voxlis.",
    proSummary: cleanValue(points?.pro_summary, ""),
    neutralSummary: cleanValue(points?.neutral_summary, ""),
    conSummary: cleanValue(points?.con_summary, ""),
    website: safeUrl(firstValue(urls?.website) || info?.website || info?.url),
    discord: safeUrl(firstValue(urls?.discord) || info?.discord),
    purchaseLink: safeUrl(price.purchaseLink),
    owner: "",
    updatedDate: "Voxlis catalog",
    tags,
    badges,
    decompiler: tags.includes("decompiler"),
    multiInject: tags.includes("multi-instance"),
    keysystem: info?.keyed === true || tags.includes("keysystem") || tags.includes("freemium"),
    clientmods: tags.includes("clientmods") || tags.includes("client-mods"),
    beta: badges.includes("beta"),
    verified: badges.includes("verified"),
    warning: badges.includes("warning") || badges.includes("warningred") || tags.includes("insecure"),
    sources: ["voxlis"],
    source: "voxlis",
    reviewUrl: voxlisFileUrl(folder, "review.md"),
    review: ""
  };
}

function rebuildCatalog() {
  const weao = aggregateByName(state.weaoRows);
  const voxlis = aggregateByName(state.voxlisRows);
  const keys = unique([...weao.keys(), ...voxlis.keys()]);

  state.all = keys
    .map(key => mergeRows(weao.get(key), voxlis.get(key), key))
    .filter(Boolean)
    .sort((a, b) => a.name.localeCompare(b.name));

  for (const id of [...state.compare]) {
    if (!state.all.some(item => item.id === id)) state.compare.delete(id);
  }

  updateStats();
  applyFilters();
  updateCompareTray();
  updateSyncHeadline();
}

function aggregateByName(rows) {
  const map = new Map();
  for (const row of rows) {
    const key = canonicalName(row.name);
    const existing = map.get(key);
    map.set(key, existing ? combineSameSource(existing, row) : { ...row, id: key });
  }
  return map;
}

function combineSameSource(a, b) {
  const updateStatus = a.updateStatus === b.updateStatus ? a.updateStatus : null;
  const detected = a.detected === true || b.detected === true
    ? true
    : a.detected === false && b.detected === false
      ? false
      : null;

  return {
    ...a,
    platforms: unique([...a.platforms, ...b.platforms]),
    updateStatus,
    detected,
    suncPercentage: maxNullable(a.suncPercentage, b.suncPercentage),
    uncPercentage: maxNullable(a.uncPercentage, b.uncPercentage),
    tags: unique([...a.tags, ...b.tags]),
    badges: unique([...a.badges, ...b.badges]),
    website: a.website || b.website,
    discord: a.discord || b.discord,
    purchaseLink: a.purchaseLink || b.purchaseLink,
    warning: a.warning || b.warning
  };
}

function mergeRows(weao, voxlis, key) {
  if (!weao && !voxlis) return null;
  if (!weao) return { ...voxlis, id: key, source: "voxlis", sources: ["voxlis"] };
  if (!voxlis) return { ...weao, id: key, source: "weao", sources: ["weao"] };

  const price = isSpecificPrice(weao.price) ? weao.price : voxlis.price;
  const description = preferText(voxlis.description, weao.description);

  return {
    ...voxlis,
    ...weao,
    id: key,
    name: preferText(weao.name, voxlis.name),
    platforms: unique([...weao.platforms, ...voxlis.platforms]),
    platform: weao.platform || voxlis.platform,
    price,
    free: typeof weao.free === "boolean" ? weao.free : voxlis.free,
    extType: preferKnown(voxlis.extType, weao.extType),
    description,
    proSummary: voxlis.proSummary || weao.proSummary,
    neutralSummary: voxlis.neutralSummary || weao.neutralSummary,
    conSummary: voxlis.conSummary || weao.conSummary,
    website: weao.website || voxlis.website,
    discord: weao.discord || voxlis.discord,
    purchaseLink: weao.purchaseLink || voxlis.purchaseLink,
    tags: unique([...weao.tags, ...voxlis.tags]),
    badges: unique([...weao.badges, ...voxlis.badges]),
    decompiler: weao.decompiler || voxlis.decompiler,
    multiInject: weao.multiInject || voxlis.multiInject,
    keysystem: weao.keysystem || voxlis.keysystem,
    clientmods: weao.clientmods || voxlis.clientmods,
    beta: weao.beta || voxlis.beta,
    verified: weao.verified || voxlis.verified,
    warning: weao.warning || voxlis.warning,
    source: "both",
    sources: ["weao", "voxlis"],
    reviewUrl: voxlis.reviewUrl,
    review: voxlis.review || ""
  };
}

function applyFilters() {
  const filters = readFilters();
  const term = filters.search.toLowerCase();

  const matches = state.all.filter(item => {
    if (filters.platform !== "all" && !item.platforms.includes(filters.platform)) return false;
    if (filters.status === "updated" && item.updateStatus !== true) return false;
    if (filters.status === "outdated" && item.updateStatus !== false) return false;
    if (filters.status === "unknown" && item.updateStatus !== null) return false;
    if (filters.price === "free" && item.free !== true) return false;
    if (filters.price === "paid" && item.free !== false) return false;
    if (filters.source === "both" && item.source !== "both") return false;
    if (filters.source === "weao" && !item.sources.includes("weao")) return false;
    if (filters.source === "voxlis" && !item.sources.includes("voxlis")) return false;

    if (term) {
      const haystack = [
        item.name,
        item.version,
        item.price,
        item.description,
        item.extType,
        item.owner,
        ...item.platforms.map(platformLabel),
        ...item.tags,
        ...item.badges
      ].join(" ").toLowerCase();
      if (!haystack.includes(term)) return false;
    }

    return true;
  });

  state.filtered = sortRows(matches, filters.sort);
  dom.resultSummary.textContent = `Showing ${state.filtered.length} of ${state.all.length} entries${activeFilterCount(filters) ? ` · ${activeFilterCount(filters)} active filter${activeFilterCount(filters) === 1 ? "" : "s"}` : ""}`;
  renderActiveView();
}

function readFilters() {
  return {
    search: dom.searchInput?.value.trim() || "",
    platform: dom.platformFilter?.value || "all",
    status: dom.statusFilter?.value || "all",
    price: dom.priceFilter?.value || "all",
    source: dom.sourceFilter?.value || "all",
    sort: dom.sortFilter?.value || "recommended"
  };
}

function activeFilterCount(filters) {
  return Number(Boolean(filters.search))
    + Number(filters.platform !== "all")
    + Number(filters.status !== "all")
    + Number(filters.price !== "all")
    + Number(filters.source !== "all");
}

function sortRows(rows, sort) {
  const list = [...rows];
  if (sort === "name") return list.sort((a, b) => a.name.localeCompare(b.name));
  if (sort === "updated") return list.sort((a, b) => statusRank(a) - statusRank(b) || a.name.localeCompare(b.name));
  if (sort === "sunc") return list.sort((a, b) => (b.suncPercentage ?? -1) - (a.suncPercentage ?? -1) || a.name.localeCompare(b.name));
  if (sort === "price") return list.sort((a, b) => sortablePrice(a) - sortablePrice(b) || a.name.localeCompare(b.name));
  return list.sort((a, b) => relevanceScore(b) - relevanceScore(a) || a.name.localeCompare(b.name));
}

function relevanceScore(item) {
  let score = 0;
  if (item.updateStatus === true) score += 35;
  if (item.updateStatus === false) score -= 20;
  if (item.detected === false) score += 20;
  if (item.detected === true) score -= 80;
  if (item.source === "both") score += 12;
  if (item.verified) score += 8;
  if (item.warning) score -= 18;
  if (Number.isFinite(item.suncPercentage)) score += item.suncPercentage / 10;
  return score;
}

function statusRank(item) {
  if (item.updateStatus === true) return 0;
  if (item.updateStatus === null) return 1;
  return 2;
}

function renderActiveView() {
  if (state.view === "table") renderTable();
  else renderGrid();
  syncCompareCheckboxes();
}

function renderGrid() {
  if (!state.all.length && state.loading) return;

  if (!state.filtered.length) {
    dom.gridView.innerHTML = emptyStateMarkup();
    return;
  }

  dom.gridView.innerHTML = state.filtered.map(item => {
    const status = updateUi(item);
    const detection = detectionText(item.detected);
    const description = item.description || "No summary is available for this catalog entry yet.";
    const features = getFeatures(item).slice(0, 4);
    const selected = state.compare.has(item.id);

    return `
      <article class="executor-card${item.warning ? " is-warning" : ""}">
        <div class="card-top">
          <div class="card-title-wrap">
            <h3 title="${h(item.name)}">${h(item.name)}</h3>
            <div class="card-source-row">${sourceBadges(item)}</div>
          </div>
          <span class="status-badge ${status.className}">${h(status.label)}</span>
        </div>
        <p class="card-description">${h(description)}</p>
        <div class="metric-grid">
          ${metricMarkup("Platform", item.platforms.map(platformLabel).join(", "))}
          ${metricMarkup("Price", item.price)}
          ${metricMarkup("Detection", detection)}
          ${metricMarkup("sUNC", percentText(item.suncPercentage))}
        </div>
        <div class="feature-row">
          ${features.length ? features.map(feature => `<span class="feature-chip">${h(feature)}</span>`).join("") : `<span class="feature-chip">${h(item.extType || "Unclassified")}</span>`}
        </div>
        <div class="card-actions">
          <label class="compare-check">
            <input type="checkbox" data-compare="${h(item.id)}" ${selected ? "checked" : ""}>
            Compare
          </label>
          <button class="details-button" type="button" data-details="${h(item.id)}">View details</button>
        </div>
      </article>`;
  }).join("");
}

function renderTable() {
  if (!state.filtered.length) {
    dom.tableBody.innerHTML = `<tr><td colspan="9">${emptyStateMarkup(true)}</td></tr>`;
    return;
  }

  dom.tableBody.innerHTML = state.filtered.map(item => {
    const status = updateUi(item);
    return `
      <tr>
        <td><label class="compare-check"><input type="checkbox" data-compare="${h(item.id)}" ${state.compare.has(item.id) ? "checked" : ""}><span class="sr-only">Compare ${h(item.name)}</span></label></td>
        <td><span class="table-name">${h(item.name)}</span></td>
        <td><span class="status-badge ${status.className}">${h(status.label)}</span></td>
        <td>${h(item.platforms.map(platformLabel).join(", "))}</td>
        <td>${h(item.price)}</td>
        <td>${h(percentText(item.suncPercentage))}</td>
        <td>${h(item.version)}</td>
        <td>${sourceBadges(item)}</td>
        <td><button class="details-button" type="button" data-details="${h(item.id)}">Details</button></td>
      </tr>`;
  }).join("");
}

function emptyStateMarkup(inTable = false) {
  return `<div class="empty-state${inTable ? " table-empty" : ""}"><h3>No matching entries</h3><p>Try a broader search or clear one of the active filters.</p></div>`;
}

function renderLoadFailure() {
  dom.gridView.innerHTML = `
    <div class="error-state">
      <h3>The live sources could not be reached</h3>
      <p>Check your connection, then try Refresh data. GitHub Pages must be served over HTTPS for the public APIs to load correctly.</p>
    </div>`;
  dom.tableBody.innerHTML = "";
  dom.resultSummary.textContent = "No live or cached catalog data is available.";
  renderVersions();
}

function setView(view, { render = true } = {}) {
  state.view = view === "table" ? "table" : "grid";
  try { localStorage.setItem("synchrose:view", state.view); } catch { /* Storage is optional. */ }

  document.querySelectorAll("[data-view]").forEach(button => {
    const active = button.dataset.view === state.view;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", String(active));
  });

  dom.gridView.hidden = state.view !== "grid";
  dom.tableView.hidden = state.view !== "table";
  if (render) renderActiveView();
}

function updateStats() {
  const total = state.all.length;
  const free = state.all.filter(item => item.free === true).length;
  const updated = state.all.filter(item => item.updateStatus === true).length;
  const clean = state.all.filter(item => item.detected === false).length;
  const platforms = unique(state.all.flatMap(item => item.platforms).filter(platform => platform !== "unknown"));

  setText("#statTotal", total || "—");
  setText("#statFree", total ? free : "—");
  setText("#statUpdated", total ? updated : "—");
  setText("#statClean", total ? clean : "—");
  setText("#heroTotal", total || "—");
  setText("#heroUpdated", total ? updated : "—");
  setText("#heroPlatforms", total ? platforms.length : "—");
}

function renderVersions() {
  const platforms = [
    ["Windows", "Windows"],
    ["Mac", "macOS"],
    ["Android", "Android"],
    ["iOS", "iOS"]
  ];

  dom.versionGrid.innerHTML = platforms.map(([key, label]) => {
    const version = cleanValue(state.versions?.[key]);
    const date = cleanValue(state.versions?.[`${key}Date`], "Update time unavailable");
    return `
      <article class="version-card">
        <span>${h(label)}</span>
        <b title="${h(version)}">${h(version)}</b>
        <small>${h(formatVersionDate(date))}</small>
      </article>`;
  }).join("");
}

function openDetails(id) {
  const item = state.all.find(row => row.id === id);
  if (!item) return;

  dom.detailDialog.dataset.itemId = id;
  renderDetails(item);
  if (!dom.detailDialog.open) dom.detailDialog.showModal();

  if (item.reviewUrl && !item.review && !item.reviewRequested) {
    item.reviewRequested = true;
    fetchText(item.reviewUrl, { allow404: true })
      .then(review => {
        item.review = cleanMarkdown(review) || "No published review notes were found.";
        if (dom.detailDialog.open && dom.detailDialog.dataset.itemId === id) renderDetails(item);
      })
      .catch(error => {
        console.warn(`Review unavailable for ${item.name}`, error);
        item.review = "Review notes could not be loaded from the source.";
        if (dom.detailDialog.open && dom.detailDialog.dataset.itemId === id) renderDetails(item);
      });
  }
}

function renderDetails(item) {
  const status = updateUi(item);
  const features = getFeatures(item);
  const links = [
    item.website ? `<a class="button button-primary button-small" href="${h(item.website)}" target="_blank" rel="noopener noreferrer">Official website ↗</a>` : "",
    item.discord ? `<a class="button button-secondary button-small" href="${h(item.discord)}" target="_blank" rel="noopener noreferrer">Discord ↗</a>` : "",
    item.purchaseLink ? `<a class="button button-secondary button-small" href="${h(item.purchaseLink)}" target="_blank" rel="noopener noreferrer">Pricing ↗</a>` : ""
  ].filter(Boolean).join("");

  const review = item.review
    ? `<div class="detail-section"><h3>Voxlis review notes</h3><p>${h(item.review)}</p></div>`
    : item.reviewUrl
      ? `<div class="detail-section"><h3>Voxlis review notes</h3><p>Loading review notes…</p></div>`
      : "";

  dom.detailContent.innerHTML = `
    <div class="detail-heading">
      <span class="kicker">${h(item.extType || "Catalog entry")}</span>
      <h2 id="detailTitle">${h(item.name)}</h2>
      <p>${h(item.description || "No description is currently available.")}</p>
      <div class="detail-status-row">
        <span class="status-badge ${status.className}">${h(status.label)}</span>
        ${sourceBadges(item)}
        ${item.warning ? `<span class="status-badge unknown">Warning flagged</span>` : ""}
      </div>
    </div>
    <div class="detail-grid">
      ${metricMarkup("Platforms", item.platforms.map(platformLabel).join(", "))}
      ${metricMarkup("Price", item.price)}
      ${metricMarkup("Detection", detectionText(item.detected))}
      ${metricMarkup("sUNC", percentText(item.suncPercentage))}
      ${metricMarkup("Executor version", item.version)}
      ${metricMarkup("Roblox build", item.rbxVersion)}
      ${metricMarkup("Last reported", item.updatedDate)}
      ${metricMarkup("Source", sourceLabel(item))}
      ${metricMarkup("Type", item.extType)}
    </div>
    ${features.length ? `<div class="detail-section"><h3>Catalog features</h3><div class="feature-row">${features.map(feature => `<span class="feature-chip">${h(feature)}</span>`).join("")}</div></div>` : ""}
    ${item.proSummary ? `<div class="detail-section"><h3>Strength</h3><p>${h(item.proSummary)}</p></div>` : ""}
    ${item.neutralSummary ? `<div class="detail-section"><h3>Context</h3><p>${h(item.neutralSummary)}</p></div>` : ""}
    ${item.conSummary ? `<div class="detail-section"><h3>Trade-off</h3><p>${h(item.conSummary)}</p></div>` : ""}
    ${review}
    ${links ? `<div class="detail-links">${links}</div>` : ""}
  `;
}

function toggleCompare(id, checked) {
  if (checked && !state.compare.has(id) && state.compare.size >= COMPARE_LIMIT) {
    toast(`You can compare up to ${COMPARE_LIMIT} entries at once.`, "error");
    syncCompareCheckboxes();
    return;
  }

  if (checked) state.compare.add(id);
  else state.compare.delete(id);
  updateCompareTray();
  syncCompareCheckboxes();
}

function clearCompare() {
  state.compare.clear();
  updateCompareTray();
  syncCompareCheckboxes();
}

function updateCompareTray() {
  const selected = selectedItems();
  dom.compareTray.hidden = !selected.length;
  dom.compareCount.textContent = selected.length;
  dom.comparePills.innerHTML = selected.map(item => `<span class="compare-pill">${h(item.name)}</span>`).join("");
}

function syncCompareCheckboxes() {
  dom.catalogResults?.querySelectorAll("input[data-compare]").forEach(input => {
    input.checked = state.compare.has(input.dataset.compare);
  });
}

function selectedItems() {
  return [...state.compare]
    .map(id => state.all.find(item => item.id === id))
    .filter(Boolean);
}

function openComparison() {
  const items = selectedItems();
  if (items.length < 2) {
    toast("Select at least two entries to compare.", "error");
    return;
  }

  const rows = [
    ["Status", item => updateUi(item).label],
    ["Detection", item => detectionText(item.detected)],
    ["Platforms", item => item.platforms.map(platformLabel).join(", ")],
    ["Price", item => item.price],
    ["sUNC", item => percentText(item.suncPercentage)],
    ["Version", item => item.version],
    ["Roblox build", item => item.rbxVersion],
    ["Type", item => item.extType],
    ["Source", item => sourceLabel(item)]
  ];

  dom.compareContent.innerHTML = `
    <table class="compare-table">
      <thead><tr><th scope="col">Field</th>${items.map(item => `<th scope="col">${h(item.name)}</th>`).join("")}</tr></thead>
      <tbody>${rows.map(([label, getValue]) => `<tr><th scope="row">${h(label)}</th>${items.map(item => `<td>${h(getValue(item))}</td>`).join("")}</tr>`).join("")}</tbody>
    </table>`;

  if (!dom.compareDialog.open) dom.compareDialog.showModal();
}

function setHealth(source, status, count = 0) {
  state.health[source] = status;
  const icon = document.querySelector(`[data-health-icon="${source}"]`);
  const label = document.querySelector(`[data-health-label="${source}"]`);
  if (!icon || !label) return;

  icon.className = `health-icon is-${status}`;
  const labels = {
    loading: "Syncing",
    ready: `Live${count ? ` · ${count}` : ""}`,
    cached: `Cached${count ? ` · ${count}` : ""}`,
    error: "Unavailable"
  };
  label.textContent = labels[status] || status;
  updateSyncHeadline();
}

function updateSyncHeadline() {
  const statuses = Object.values(state.health);
  let headline = "Connecting to sources";
  if (statuses.every(status => status === "ready")) headline = "Sources synchronized";
  else if (statuses.some(status => status === "ready")) headline = "Partial live data";
  else if (statuses.some(status => status === "cached")) headline = "Using cached data";
  else if (statuses.every(status => status === "error")) headline = "Sources unavailable";

  setText("#syncHeadline", headline);
  const date = state.loadedAt instanceof Date && !Number.isNaN(state.loadedAt.valueOf())
    ? state.loadedAt
    : null;
  setText("#lastSync", date ? `Last synchronized ${date.toLocaleString()}` : "Waiting for the first sync…");
}

function hydrateFromCache() {
  try {
    const cached = JSON.parse(localStorage.getItem(CACHE_KEY) || "null");
    if (!cached?.timestamp || Date.now() - cached.timestamp > CACHE_MAX_AGE) return;

    state.weaoRows = Array.isArray(cached.weaoRows) ? cached.weaoRows : [];
    state.voxlisRows = Array.isArray(cached.voxlisRows) ? cached.voxlisRows : [];
    state.versions = cached.versions && typeof cached.versions === "object" ? cached.versions : {};
    state.loadedAt = new Date(cached.timestamp);

    if (state.weaoRows.length) setHealth("weao", "cached", state.weaoRows.length);
    if (state.voxlisRows.length) setHealth("voxlis", "cached", state.voxlisRows.length);
    renderVersions();
    rebuildCatalog();
  } catch (error) {
    console.warn("Cached Synchrose data could not be read", error);
  }
}

function saveCache() {
  if (!state.weaoRows.length && !state.voxlisRows.length) return;
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify({
      timestamp: Date.now(),
      weaoRows: state.weaoRows,
      voxlisRows: state.voxlisRows,
      versions: state.versions
    }));
  } catch (error) {
    console.warn("Synchrose cache could not be saved", error);
  }
}

async function fetchJsonWithFallback(primary, fallback) {
  try {
    return await fetchJson(primary);
  } catch (primaryError) {
    if (!fallback) throw primaryError;
    return fetchJson(fallback);
  }
}

async function fetchJson(url, { allow404 = false, timeout = 16000 } = {}) {
  const controller = new AbortController();
  const timer = window.setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      method: "GET",
      mode: "cors",
      cache: "no-store",
      signal: controller.signal,
      headers: { Accept: "application/json, text/plain, */*" }
    });

    if (allow404 && response.status === 404) return null;
    if (!response.ok) throw new Error(`HTTP ${response.status} from ${new URL(url).hostname}`);
    const text = await response.text();
    try {
      return JSON.parse(text);
    } catch {
      throw new Error(`${new URL(url).hostname} returned invalid JSON`);
    }
  } finally {
    window.clearTimeout(timer);
  }
}

async function fetchText(url, { allow404 = false, timeout = 12000 } = {}) {
  const controller = new AbortController();
  const timer = window.setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      method: "GET",
      mode: "cors",
      cache: "no-store",
      signal: controller.signal,
      headers: { Accept: "text/plain, text/markdown, */*" }
    });
    if (allow404 && response.status === 404) return "";
    if (!response.ok) throw new Error(`HTTP ${response.status} from ${new URL(url).hostname}`);
    return response.text();
  } finally {
    window.clearTimeout(timer);
  }
}

async function mapWithConcurrency(items, limit, worker) {
  const results = new Array(items.length);
  let cursor = 0;

  async function run() {
    while (cursor < items.length) {
      const index = cursor++;
      results[index] = await worker(items[index], index);
    }
  }

  const workers = Array.from({ length: Math.min(limit, items.length) }, run);
  await Promise.all(workers);
  return results;
}

function getVoxlisPrice(name, platforms, prices) {
  const compact = normalizeSlug(name);
  const key = PRICE_ALIASES[compact] || compact;
  const freeProducts = Array.isArray(prices?.freeProducts) ? prices.freeProducts : [];
  const product = prices?.[key];

  if (freeProducts.includes(key)) return { free: true, label: "Free", purchaseLink: null };
  if (!product || !Array.isArray(product.offers) || !product.offers.length) {
    return { free: null, label: "Unknown", purchaseLink: null };
  }

  const normalizedPlatforms = platforms.map(normalizeStatusPlatform);
  let offers = product.offers.filter(offer => normalizedPlatforms.includes(normalizeStatusPlatform(offer?.platform)));
  if (!offers.length) offers = product.offers;

  const freeOffers = offers.filter(offer => Number(offer?.price) === 0);
  const paidOffers = offers
    .filter(offer => Number(offer?.price) > 0)
    .sort((a, b) => Number(a.price) - Number(b.price));

  if (freeOffers.length && paidOffers.length) {
    return { free: true, label: `Free or ${formatOffer(paidOffers[0])}`, purchaseLink: product.purchaseUrl || null };
  }
  if (freeOffers.length) return { free: true, label: "Free", purchaseLink: product.purchaseUrl || null };
  if (paidOffers.length) return { free: false, label: formatOffer(paidOffers[0]), purchaseLink: product.purchaseUrl || null };
  return { free: null, label: "Unknown", purchaseLink: product.purchaseUrl || null };
}

function formatOffer(offer) {
  const amount = Number(offer?.price);
  if (!Number.isFinite(amount)) return "Unknown";
  const currency = offer?.currency || "USD";
  const formatted = currency === "EUR" ? `€${trimNumber(amount)}` : currency === "USD" ? `$${trimNumber(amount)}` : `${currency} ${trimNumber(amount)}`;
  const days = Number(offer?.days);
  if (days === -1) return `${formatted} lifetime`;
  if (days === 1) return `${formatted} daily`;
  if (days === 7) return `${formatted} weekly`;
  if (days === 30) return `${formatted} monthly`;
  return days > 0 ? `${formatted} / ${days} days` : formatted;
}

function sortablePrice(item) {
  if (item.free === true) return 0;
  const match = String(item.price || "").match(/[$€£]\s*(\d+(?:\.\d+)?)/);
  return match ? Number(match[1]) : Number.POSITIVE_INFINITY;
}

function getVersionForPlatform(versions, platform) {
  const keys = { windows: "Windows", mac: "Mac", android: "Android", ios: "iOS" };
  return versions?.[keys[platform]] || null;
}

function voxlisFileUrl(folder, filename) {
  return `${ENDPOINTS.voxlisRaw}/${encodeURIComponent(folder)}/${encodeURIComponent(filename)}`;
}

function canonicalName(name) {
  const compact = normalizeSlug(name);
  return NAME_ALIASES[compact] || compact || `unknown-${Math.random().toString(36).slice(2, 8)}`;
}

function normalizeSlug(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]/g, "");
}

function normalizePlatform(value) {
  const platform = String(value || "unknown").toLowerCase();
  if (platform.includes("win")) return "windows";
  if (platform.includes("mac")) return "mac";
  if (platform.includes("android") || platform.includes("mobile")) return "android";
  if (platform.includes("ios")) return "ios";
  return platform || "unknown";
}

function normalizeStatusPlatform(value) {
  const normalized = normalizePlatform(value);
  return normalized === "mac" ? "macos" : normalized;
}

function normalizeTag(value) {
  const raw = String(value || "").trim().toLowerCase();
  const compact = raw.replace(/[^a-z0-9]+/g, "");
  if (compact === "multiinstance") return "multi-instance";
  if (compact === "key" || compact === "keysystem") return "keysystem";
  if (compact === "serverside") return "serverside";
  if (compact === "inviteonly") return "invite-only";
  return raw;
}

function normalizeType(value) {
  const type = String(value || "unknown").trim().toLowerCase();
  if (type === "executor") return "internal";
  if (type === "server-side") return "serverside";
  return type || "unknown";
}

function updateUi(item) {
  if (item.updateStatus === true) return { label: "Updated", className: "updated" };
  if (item.updateStatus === false) return { label: "Outdated", className: "outdated" };
  return { label: "Unknown", className: "unknown" };
}

function detectionText(value) {
  if (value === true) return "Detected";
  if (value === false) return "Undetected";
  return "Unknown";
}

function sourceLabel(item) {
  if (item.source === "both") return "WEAO + Voxlis";
  if (item.source === "weao") return "WEAO";
  if (item.source === "voxlis") return "Voxlis";
  return "Unknown";
}

function sourceBadges(item) {
  if (item.source === "both") return `<span class="source-badge both">WEAO + Voxlis</span>`;
  return `<span class="source-badge">${h(sourceLabel(item))}</span>`;
}

function getFeatures(item) {
  const features = [];
  if (item.verified) features.push("Verified");
  if (item.decompiler) features.push("Decompiler");
  if (item.multiInject) features.push("Multi-instance");
  if (item.keysystem) features.push("Key system");
  if (item.clientmods) features.push("Client mods");
  if (item.beta) features.push("Beta");
  for (const tag of item.tags || []) {
    const label = tag.replace(/-/g, " ");
    if (!features.some(value => value.toLowerCase() === label.toLowerCase())) features.push(label);
  }
  return features;
}

function metricMarkup(label, value) {
  return `<div class="metric"><span>${h(label)}</span><strong title="${h(cleanValue(value))}">${h(cleanValue(value))}</strong></div>`;
}

function platformLabel(value) {
  return PLATFORM_LABELS[normalizePlatform(value)] || String(value || "Unknown");
}

function percentText(value) {
  return Number.isFinite(value) ? `${trimNumber(value)}%` : "N/A";
}

function cleanValue(value, fallback = "N/A") {
  if (value === null || value === undefined) return fallback;
  const text = String(value).trim();
  return text && text !== "undefined" && text !== "null" ? text : fallback;
}

function numericOrNull(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function maxNullable(a, b) {
  const values = [a, b].filter(Number.isFinite);
  return values.length ? Math.max(...values) : null;
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function toArray(value) {
  if (Array.isArray(value)) return value.filter(Boolean);
  return value ? [value] : [];
}

function firstValue(value) {
  return Array.isArray(value) ? value[0] : value;
}

function safeUrl(value) {
  const first = firstValue(value);
  if (!first) return null;
  try {
    const url = new URL(String(first));
    return url.protocol === "https:" || url.protocol === "http:" ? url.toString() : null;
  } catch {
    return null;
  }
}

function preferText(primary, fallback) {
  const first = cleanValue(primary, "");
  return first || cleanValue(fallback);
}

function preferKnown(primary, fallback) {
  const first = cleanValue(primary, "");
  return first && first !== "unknown" ? first : cleanValue(fallback);
}

function isSpecificPrice(value) {
  const normalized = String(value || "").trim().toLowerCase();
  return normalized && !["paid", "free", "unknown", "n/a"].includes(normalized);
}

function trimNumber(value) {
  return Number(value).toFixed(2).replace(/\.00$/, "").replace(/(\.\d)0$/, "$1");
}

function formatVersionDate(value) {
  const raw = cleanValue(value, "Update time unavailable");
  const date = new Date(raw);
  if (raw === "Update time unavailable" || Number.isNaN(date.valueOf())) return raw;
  return `Updated ${date.toLocaleString()}`;
}

function cleanMarkdown(markdown) {
  return String(markdown || "")
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/!\[[^\]]*\]\([^)]*\)/g, " ")
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .replace(/^>\s?/gm, "")
    .replace(/^#{1,6}\s+/gm, "")
    .replace(/[\*_~]/g, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function friendlyError(error) {
  if (error?.name === "AbortError") return "request timed out";
  return String(error?.message || error || "unknown error").slice(0, 120);
}

function toast(message, kind = "default") {
  const node = document.createElement("div");
  node.className = `toast${kind === "error" ? " error" : ""}`;
  node.textContent = message;
  dom.toastRegion.append(node);
  window.setTimeout(() => node.remove(), 4200);
}

function readStoredView() {
  try { return localStorage.getItem("synchrose:view") === "table" ? "table" : "grid"; }
  catch { return "grid"; }
}

function setText(selector, value) {
  const element = document.querySelector(selector);
  if (element) element.textContent = String(value);
}

function h(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
