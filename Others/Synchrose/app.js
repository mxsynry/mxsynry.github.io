const SYNCHROSE_API_BASE = resolveSynchroseApiBase();

const ENDPOINTS = Object.freeze({
  weaoExploits: "https://weao.xyz/api/status/exploits",
  weaoVersions: "https://weao.xyz/api/versions/current",
  weaoPastVersions: "https://weao.xyz/api/versions/past",
  weaoExploitsFallback: "https://whatexpsare.online/api/status/exploits",
  weaoVersionsFallback: "https://whatexpsare.online/api/versions/current",
  weaoPastVersionsFallback: "https://whatexpsare.online/api/versions/past",
  voxlisContents: "https://api.github.com/repos/localscripts/voxlis.NET/contents/public/data/roblox?ref=main",
  voxlisFlatTree: "https://data.jsdelivr.com/v1/package/gh/localscripts/voxlis.NET@main/flat",
  voxlisRaw: "https://raw.githubusercontent.com/localscripts/voxlis.NET/main/public/data/roblox",
  voxlisPrices: "https://raw.githubusercontent.com/localscripts/voxlis.NET/main/public/data/roblox/prices.json",
  pulseryStatus: SYNCHROSE_API_BASE ? `${SYNCHROSE_API_BASE}/api/pulsery/status` : "",
  injectCheats: "https://inject.today/api/cheats",
  injectVersions: "https://inject.today/api/versions/current"
});

const CACHE_KEY = "synchrose:catalog:v4";
const CACHE_MAX_AGE = 24 * 60 * 60 * 1000;
const COMPARE_LIMIT = 4;

const SOURCE_LABELS = Object.freeze({
  weao: "WEAO",
  voxlis: "Voxlis",
  pulsery: "Pulsery",
  inject: "Inject"
});

const SOURCE_ORDER = Object.freeze(["weao", "voxlis", "pulsery", "inject"]);

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
  pulseryRows: [],
  injectRows: [],
  all: [],
  filtered: [],
  versions: {},
  pastVersions: {},
  compare: new Set(),
  view: readStoredView(),
  loading: false,
  loadedAt: null,
  health: {
    weao: "loading",
    voxlis: "loading",
    pulsery: "loading",
    inject: "loading"
  }
};

const dom = {
  body: document.body,
  filterForm: document.querySelector("#filterForm"),
  searchInput: document.querySelector("#searchInput"),
  platformFilter: document.querySelector("#platformFilter"),
  statusFilter: document.querySelector("#statusFilter"),
  detectionFilter: document.querySelector("#detectionFilter"),
  typeFilter: document.querySelector("#typeFilter"),
  priceFilter: document.querySelector("#priceFilter"),
  keyFilter: document.querySelector("#keyFilter"),
  featureFilter: document.querySelector("#featureFilter"),
  suncFilter: document.querySelector("#suncFilter"),
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
  versionContextMenu: document.querySelector("#versionContextMenu"),
  versionContextPlatform: document.querySelector("#versionContextPlatform"),
  versionContextHash: document.querySelector("#versionContextHash"),
  versionContextCopyLabel: document.querySelector("#versionContextCopyLabel"),
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
let requestMusicFromIntro = () => {};

document.documentElement.classList.add("is-booting");
document.body.classList.add("boot-active");
bindEvents();
setView(state.view, { render: false });
initRevealMotion();
initMusicPlayer();
initIntro();
hydrateFromCache();
loadData();

function bindEvents() {
  dom.filterForm?.addEventListener("submit", event => event.preventDefault());

  dom.searchInput?.addEventListener("input", () => {
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(applyFilters, 120);
  });

  [
    dom.platformFilter,
    dom.statusFilter,
    dom.detectionFilter,
    dom.typeFilter,
    dom.priceFilter,
    dom.keyFilter,
    dom.featureFilter,
    dom.suncFilter,
    dom.sourceFilter,
    dom.sortFilter
  ]
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

  document.querySelectorAll("[data-rdd-mode]").forEach(button => {
    button.addEventListener("click", () => setRddMode(button.dataset.rddMode));
  });

  bindVersionContextMenu();

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

function setRddMode(mode) {
  const selected = mode === "older" ? "older" : "current";
  document.querySelectorAll("[data-rdd-mode]").forEach(button => {
    const active = button.dataset.rddMode === selected;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", String(active));
  });
  setText("#rddPrompt", selected === "older"
    ? "Find an older Roblox build with:"
    : "Get the newest Roblox build with:");
}

function initRevealMotion() {
  const elements = [...document.querySelectorAll("[data-reveal]")];
  if (!elements.length) return;

  const reducedMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
  if (reducedMotion || typeof IntersectionObserver !== "function") {
    elements.forEach(element => element.classList.add("is-visible"));
    return;
  }

  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("is-visible");
      observer.unobserve(entry.target);
    });
  }, { threshold: 0.12, rootMargin: "0px 0px -8%" });

  elements.forEach(element => observer.observe(element));
}

function initIntro() {
  const screen = document.querySelector("#bootScreen");
  if (!screen) {
    document.documentElement.classList.remove("is-booting");
    document.body.classList.remove("boot-active");
    return;
  }

  const hint = document.querySelector("#bootHint");
  const reducedMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
  let timers = [];
  let finished = false;

  const clearTimers = () => {
    timers.forEach(timer => window.clearTimeout(timer));
    timers = [];
  };

  const complete = () => {
    if (finished) return;
    finished = true;
    clearTimers();
    screen.classList.add("is-gone");
    screen.hidden = true;
    screen.setAttribute("aria-hidden", "true");
    document.documentElement.classList.remove("is-booting");
    document.body.classList.remove("boot-active");
  };

  const enter = ({ userGesture = false, fast = false } = {}) => {
    if (finished || screen.classList.contains("is-entering")) return;
    clearTimers();
    screen.classList.add("is-entering");
    if (fast || reducedMotion) screen.classList.add("is-fast");
    if (hint) hint.textContent = "同期中...";
    if (userGesture) requestMusicFromIntro();

    const flashDelay = fast || reducedMotion ? 100 : 720;
    const finishDelay = fast || reducedMotion ? 420 : 1180;
    timers.push(window.setTimeout(() => screen.classList.add("is-leaving"), flashDelay));
    timers.push(window.setTimeout(complete, finishDelay));
  };

  const start = () => {
    clearTimers();
    finished = false;
    screen.hidden = false;
    screen.className = "intro-screen";
    screen.setAttribute("aria-hidden", "false");
    document.documentElement.classList.add("is-booting");
    document.body.classList.add("boot-active");
    if (hint) hint.textContent = "CLICK / PRESS A KEY TO ENTER";
  };

  screen.addEventListener("pointerdown", event => {
    event.preventDefault();
    enter({ userGesture: true, fast: Boolean(event.target.closest("#bootSkip")) });
  }, { capture: true });

  document.addEventListener("keydown", event => {
    if (finished || screen.hidden) return;
    if (event.key === "Escape") {
      event.preventDefault();
      enter({ userGesture: true, fast: true });
      return;
    }
    const shouldEnter = event.key === "Enter" || event.key === " " || event.key.length === 1;
    if (!shouldEnter) return;
    if (event.key === " ") event.preventDefault();
    enter({ userGesture: true });
  }, { capture: true });

  document.querySelectorAll("[data-replay-intro]").forEach(button => {
    button.addEventListener("click", () => {
      button.closest("details")?.removeAttribute("open");
      start();
    });
  });

  start();
}

function initMusicPlayer() {
  const player = document.querySelector("#musicPlayer");
  const audio = document.querySelector("#musicAudio");
  if (!player || !audio) return;

  const ui = {
    disc: document.querySelector("#musicDiscToggle"),
    title: document.querySelector("#musicTitle"),
    index: document.querySelector("#musicTrackIndex"),
    play: document.querySelector("#musicPlay"),
    prev: document.querySelector("#musicPrev"),
    next: document.querySelector("#musicNext"),
    seek: document.querySelector("#musicSeek"),
    time: document.querySelector("#musicTime"),
    volume: document.querySelector("#musicVolume"),
    queueToggle: document.querySelector("#musicQueueToggle"),
    queue: document.querySelector("#musicQueue"),
    list: document.querySelector("#musicList"),
    status: document.querySelector("#musicStatus")
  };
  const playIcon = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5v14l11-7L8 5Z"/></svg>';
  const pauseIcon = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 5h4v14H7V5Zm6 0h4v14h-4V5Z"/></svg>';
  const music = {
    tracks: [],
    index: 0,
    sourceIndex: 0,
    pendingPlay: false,
    switchingSource: false
  };
  let queueCloseTimer = 0;

  const setQueueOpen = open => {
    if (!ui.queue) return;
    window.clearTimeout(queueCloseTimer);

    if (open) {
      ui.queue.hidden = false;
      ui.queue.removeAttribute("inert");
      ui.queue.setAttribute("aria-hidden", "false");
      // Flush the hidden state before adding the open class so max-height,
      // opacity, and the panel's total height animate together.
      void ui.queue.offsetHeight;
      player.classList.add("is-queue");
    } else {
      player.classList.remove("is-queue");
      ui.queue.setAttribute("aria-hidden", "true");
      ui.queue.setAttribute("inert", "");
      queueCloseTimer = window.setTimeout(() => {
        if (!player.classList.contains("is-queue")) ui.queue.hidden = true;
      }, 460);
    }

    ui.queueToggle?.setAttribute("aria-expanded", String(open));
  };

  const setStatus = message => {
    if (ui.status) ui.status.textContent = String(message || "").toUpperCase();
  };

  const updatePlayState = () => {
    const playing = !audio.paused && !audio.ended;
    player.classList.toggle("is-playing", playing);
    if (ui.play) {
      ui.play.innerHTML = playing ? pauseIcon : playIcon;
      ui.play.setAttribute("aria-label", playing ? "Pause" : "Play");
      ui.play.title = playing ? "Pause" : "Play";
    }
  };

  const formatTime = seconds => {
    if (!Number.isFinite(seconds) || seconds < 0) return "0:00";
    return `${Math.floor(seconds / 60)}:${String(Math.floor(seconds % 60)).padStart(2, "0")}`;
  };

  const updateTime = () => {
    const duration = Number.isFinite(audio.duration) ? audio.duration : 0;
    const current = Number.isFinite(audio.currentTime) ? audio.currentTime : 0;
    if (ui.seek) ui.seek.value = duration ? String(Math.round((current / duration) * 1000)) : "0";
    if (ui.time) ui.time.textContent = `${formatTime(current)} / ${formatTime(duration)}`;
  };

  const renderQueue = () => {
    if (!ui.list) return;
    ui.list.innerHTML = music.tracks.map((track, index) => `
      <button class="${index === music.index ? "is-active" : ""}" type="button" data-music-index="${index}" title="${h(track.path)}">
        <span>${String(index + 1).padStart(2, "0")}</span><span>${h(track.title)}</span>
      </button>`).join("");
  };

  const selectTrack = (index, { play = false } = {}) => {
    if (!music.tracks.length) return;
    music.index = (index + music.tracks.length) % music.tracks.length;
    music.sourceIndex = 0;
    music.switchingSource = false;
    const track = music.tracks[music.index];
    audio.src = track.sources[0];
    if (ui.title) ui.title.textContent = track.title;
    if (ui.index) ui.index.textContent = `${String(music.index + 1).padStart(2, "0")}/${String(music.tracks.length).padStart(2, "0")}`;
    setStatus("READY");
    updateTime();
    renderQueue();
    try { localStorage.setItem("synchrose:music:track", track.path); } catch { /* Storage is optional. */ }

    if ("mediaSession" in navigator && typeof MediaMetadata === "function") {
      navigator.mediaSession.metadata = new MediaMetadata({ title: track.title, artist: "Synchrose" });
    }
    if (play) playMusic();
  };

  const nextTrack = (play = !audio.paused) => selectTrack(music.index + 1, { play });
  const prevTrack = () => {
    if (audio.currentTime > 3) {
      audio.currentTime = 0;
      updateTime();
      return;
    }
    selectTrack(music.index - 1, { play: !audio.paused });
  };

  async function playMusic() {
    if (!music.tracks.length) {
      music.pendingPlay = true;
      setStatus("STILL SCANNING");
      return;
    }

    music.pendingPlay = false;
    try {
      await audio.play();
      setStatus("PLAYING");
    } catch (error) {
      console.warn("Music playback needs a click on the play button", error);
      setStatus("PRESS PLAY");
    }
  }

  requestMusicFromIntro = () => {
    music.pendingPlay = true;
    playMusic();
  };

  ui.disc?.addEventListener("click", () => {
    const open = !player.classList.contains("is-open");
    player.classList.toggle("is-open", open);
    ui.disc.setAttribute("aria-expanded", String(open));
    if (!open) setQueueOpen(false);
  });

  ui.play?.addEventListener("click", () => {
    if (audio.paused) playMusic();
    else audio.pause();
  });
  ui.prev?.addEventListener("click", prevTrack);
  ui.next?.addEventListener("click", () => nextTrack(!audio.paused));

  ui.seek?.addEventListener("input", () => {
    if (!Number.isFinite(audio.duration) || audio.duration <= 0) return;
    audio.currentTime = (Number(ui.seek.value) / 1000) * audio.duration;
    updateTime();
  });

  const storedVolume = (() => {
    try { return Number(localStorage.getItem("synchrose:music:volume")); }
    catch { return NaN; }
  })();
  audio.volume = Number.isFinite(storedVolume) ? Math.max(0, Math.min(1, storedVolume)) : 0.7;
  if (ui.volume) ui.volume.value = String(audio.volume);
  ui.volume?.addEventListener("input", () => {
    audio.volume = Number(ui.volume.value);
    try { localStorage.setItem("synchrose:music:volume", String(audio.volume)); } catch { /* Storage is optional. */ }
  });

  ui.queueToggle?.addEventListener("click", () => {
    const open = !player.classList.contains("is-queue");
    player.classList.add("is-open");
    setQueueOpen(open);
    ui.disc?.setAttribute("aria-expanded", "true");
  });

  ui.list?.addEventListener("click", event => {
    const button = event.target.closest("[data-music-index]");
    if (!button) return;
    selectTrack(Number(button.dataset.musicIndex), { play: true });
  });

  document.addEventListener("pointerdown", event => {
    if (player.contains(event.target)) return;
    setQueueOpen(false);
    player.classList.remove("is-open");
    ui.disc?.setAttribute("aria-expanded", "false");
  });

  audio.addEventListener("play", updatePlayState);
  audio.addEventListener("pause", updatePlayState);
  audio.addEventListener("timeupdate", updateTime);
  audio.addEventListener("loadedmetadata", updateTime);
  audio.addEventListener("ended", () => nextTrack(true));
  audio.addEventListener("error", () => {
    const track = music.tracks[music.index];
    if (!track || music.switchingSource) return;
    const nextSource = music.sourceIndex + 1;
    if (nextSource < track.sources.length) {
      music.switchingSource = true;
      music.sourceIndex = nextSource;
      const shouldResume = !audio.paused || music.pendingPlay;
      audio.src = track.sources[nextSource];
      music.switchingSource = false;
      setStatus("TRYING BACKUP");
      if (shouldResume) playMusic();
      return;
    }
    setStatus("SKIPPED A BROKEN FILE");
    nextTrack(!audio.paused || music.pendingPlay);
  });

  if ("mediaSession" in navigator) {
    try {
      navigator.mediaSession.setActionHandler("play", playMusic);
      navigator.mediaSession.setActionHandler("pause", () => audio.pause());
      navigator.mediaSession.setActionHandler("previoustrack", prevTrack);
      navigator.mediaSession.setActionHandler("nexttrack", () => nextTrack(true));
    } catch { /* Media Session support varies by browser. */ }
  }

  updatePlayState();
  discoverMusicTracks()
    .then(tracks => {
      music.tracks = tracks;
      player.classList.remove("is-loading");
      if (!tracks.length) {
        player.classList.add("is-empty");
        if (ui.title) ui.title.textContent = "No MP3s found";
        if (ui.index) ui.index.textContent = "00/00";
        setStatus("FOLDER EMPTY");
        return;
      }

      let storedPath = "";
      try { storedPath = localStorage.getItem("synchrose:music:track") || ""; } catch { /* Storage is optional. */ }
      const storedIndex = tracks.findIndex(track => track.path === storedPath);
      selectTrack(storedIndex >= 0 ? storedIndex : 0);
      setStatus(`${tracks.length} TRACKS`);
      if (music.pendingPlay) playMusic();
    })
    .catch(error => {
      player.classList.remove("is-loading");
      player.classList.add("is-empty");
      if (ui.title) ui.title.textContent = "Music scan failed";
      setStatus("TRY AGAIN LATER");
      console.warn("Synchrose music folder could not be scanned", error);
    });
}

async function discoverMusicTracks() {
  const sources = [];

  try {
    const response = await fetch("/tree.json", { cache: "no-store", headers: { Accept: "application/json" } });
    if (response.ok) sources.push(await response.json());
  } catch (error) {
    console.warn("Local tree.json music scan failed", error);
  }

  let files = sources.flatMap(collectMusicFiles);
  if (!files.length) {
    try {
      const response = await fetch("https://api.github.com/repos/mxsynry/mxsynry.github.io/contents/Others/Synchrose?ref=main", {
        cache: "no-store",
        headers: { Accept: "application/vnd.github+json" }
      });
      if (response.ok) files = collectMusicFiles(await response.json());
    } catch (error) {
      console.warn("GitHub music scan failed", error);
    }
  }

  const uniqueFiles = new Map();
  files.forEach(file => uniqueFiles.set(file.path, file));
  return [...uniqueFiles.values()]
    .sort((a, b) => a.path.localeCompare(b.path, undefined, { sensitivity: "base" }))
    .map(file => {
      const encodedPath = file.path.split("/").map(encodeURIComponent).join("/");
      const sameOrigin = `${window.location.origin}/${encodedPath}`;
      const raw = file.downloadUrl || `https://raw.githubusercontent.com/mxsynry/mxsynry.github.io/main/${encodedPath}`;
      return {
        path: file.path,
        title: musicTitleFromPath(file.path),
        sources: unique([sameOrigin, raw])
      };
    });
}

function collectMusicFiles(tree) {
  const files = [];
  const folder = "Others/Synchrose/";
  const audioPattern = /\.(mp3|ogg|wav|m4a)$/i;

  function walk(node) {
    if (!node) return;
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    if (typeof node !== "object") return;

    const path = String(node.path || "").replace(/^\/+/, "");
    if (path.startsWith(folder) && audioPattern.test(path)) {
      files.push({ path, downloadUrl: node.download_url || node.downloadUrl || "" });
    }

    if (Array.isArray(node.children)) node.children.forEach(walk);
    if (Array.isArray(node.tree)) node.tree.forEach(walk);
    if (Array.isArray(node.files)) node.files.forEach(walk);
  }

  walk(tree);
  return files;
}

function musicTitleFromPath(path) {
  return decodeURIComponent(String(path).split("/").pop() || "Untitled")
    .replace(/\.[^.]+$/, "")
    .replace(/[_]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

async function loadData({ force = false } = {}) {
  if (state.loading) return;

  state.loading = true;
  dom.body.classList.add("is-refreshing");
  dom.catalogResults?.setAttribute("aria-busy", "true");
  setHealth("weao", "loading");
  setHealth("voxlis", "loading");
  setHealth("pulsery", "loading");
  setHealth("inject", "loading");

  const weaoJob = fetchWeaoData()
    .then(({ rows, versions, pastVersions }) => {
      state.weaoRows = rows;
      state.versions = versions;
      state.pastVersions = pastVersions;
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

  const pulseryJob = fetchPulseryData()
    .then(rows => {
      state.pulseryRows = rows;
      state.loadedAt = new Date();
      setHealth("pulsery", "ready", rows.length);
      rebuildCatalog();
      saveCache();
      return true;
    })
    .catch(error => {
      console.warn("Pulsery data unavailable", error);
      setHealth("pulsery", state.pulseryRows.length ? "cached" : "error", state.pulseryRows.length);
      if (!state.pulseryRows.length && SYNCHROSE_API_BASE) {
        toast(`Pulsery unavailable: ${friendlyError(error)}`, "error");
      }
      return false;
    });

  const injectJob = fetchInjectData()
    .then(rows => {
      state.injectRows = rows;
      state.loadedAt = new Date();
      setHealth("inject", "ready", rows.length);
      rebuildCatalog();
      saveCache();
      return true;
    })
    .catch(error => {
      console.warn("Inject data unavailable", error);
      setHealth("inject", state.injectRows.length ? "cached" : "error", state.injectRows.length);
      if (!state.injectRows.length) toast(`Inject unavailable: ${friendlyError(error)}`, "error");
      return false;
    });

  const results = await Promise.all([weaoJob, voxlisJob, pulseryJob, injectJob]);
  state.loading = false;
  dom.body.classList.remove("is-refreshing");
  dom.catalogResults?.setAttribute("aria-busy", "false");
  updateSyncHeadline();

  if (!state.all.length) renderLoadFailure();
  if (force && results.some(Boolean)) toast("Live data refreshed.");
}

async function fetchWeaoData() {
  const [exploitsResult, versionsResult, pastVersionsResult] = await Promise.allSettled([
    fetchJsonWithFallback(ENDPOINTS.weaoExploits, ENDPOINTS.weaoExploitsFallback),
    fetchJsonWithFallback(ENDPOINTS.weaoVersions, ENDPOINTS.weaoVersionsFallback),
    fetchJsonWithFallback(ENDPOINTS.weaoPastVersions, ENDPOINTS.weaoPastVersionsFallback)
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
  const pastPayload = pastVersionsResult.status === "fulfilled" ? pastVersionsResult.value : {};
  const pastVersions = pastPayload?.data && !Array.isArray(pastPayload.data)
    ? pastPayload.data
    : pastPayload || {};

  return {
    rows: items.map(item => normalizeWeaoRow(item, versions)).filter(row => row.name !== "Unknown"),
    versions,
    pastVersions
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

async function fetchPulseryData() {
  if (!ENDPOINTS.pulseryStatus) {
    throw new Error("The Synchrose Worker is not configured.");
  }

  const payload = await fetchJson(ENDPOINTS.pulseryStatus);
  const items = Array.isArray(payload?.executors)
    ? payload.executors
    : Array.isArray(payload?.data?.executors)
      ? payload.data.executors
      : [];

  if (!items.length) throw new Error("Pulsery returned no exploit entries.");
  return items.map(normalizePulseryRow).filter(row => row.name !== "Unknown");
}

async function fetchInjectData() {
  const [cheatsResult, versionsResult] = await Promise.allSettled([
    fetchJson(ENDPOINTS.injectCheats),
    fetchJson(ENDPOINTS.injectVersions)
  ]);

  if (cheatsResult.status === "rejected") throw cheatsResult.reason;
  const versions = versionsResult.status === "fulfilled" ? versionsResult.value : {};
  const payload = cheatsResult.value?.data && typeof cheatsResult.value.data === "object"
    ? cheatsResult.value.data
    : cheatsResult.value;

  if (!payload || Array.isArray(payload) || typeof payload !== "object") {
    throw new Error("Inject returned an unexpected catalog.");
  }

  const rows = Object.entries(payload)
    .filter(([name]) => name && name.toLowerCase() !== "undefined")
    .flatMap(([name, item]) => normalizeInjectRows(name, item, versions));

  if (!rows.length) throw new Error("Inject returned no exploit entries.");
  return rows;
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
    raknet: false,
    rating: null,
    reviewCount: null,
    stabilityScore: null,
    myriadScore: null,
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
    raknet: tags.includes("raknet"),
    rating: null,
    reviewCount: null,
    stabilityScore: null,
    myriadScore: null,
    sources: ["voxlis"],
    source: "voxlis",
    reviewUrl: voxlisFileUrl(folder, "review.md"),
    review: ""
  };
}

function normalizePulseryRow(item) {
  const name = cleanValue(item?.name, "Unknown");
  const platforms = unique(toArray(item?.platforms).map(normalizePlatform));
  const statusText = cleanValue(item?.status, "").toLowerCase();
  const clientmods = /client[\s-]*mod/.test(statusText);
  const detected = clientmods
    ? false
    : typeof item?.is_detected === "boolean"
      ? item.is_detected
      : statusText === "detected"
        ? true
        : statusText === "undetected"
          ? false
          : null;
  const price = cleanValue(item?.price_text, Number(item?.price_num) === 0 ? "Free" : "Paid");
  const free = Number(item?.price_num) === 0 || /\bfree\b|freemium/i.test(price);

  return {
    id: canonicalName(name),
    name,
    platforms: platforms.length ? platforms : ["unknown"],
    platform: platforms[0] || "unknown",
    version: cleanValue(item?.version),
    rbxVersion: cleanValue(item?.roblox_version),
    price,
    free,
    updateStatus: typeof item?.is_working === "boolean" ? item.is_working : null,
    updateSource: "Pulsery",
    detected,
    suncPercentage: percentOrNull(item?.sunc_percent),
    uncPercentage: percentOrNull(item?.unc_percent),
    extType: normalizeType(item?.type),
    description: cleanValue(item?.description, ""),
    proSummary: "",
    neutralSummary: "",
    conSummary: "",
    website: safeUrl(item?.website_url),
    discord: safeUrl(item?.discord_url),
    purchaseLink: safeUrl(item?.purchase_url),
    owner: cleanValue(item?.developer, ""),
    updatedDate: cleanValue(item?.updated || item?.last_status_change),
    tags: [],
    badges: [],
    decompiler: item?.decompiler === true,
    multiInject: item?.multi_instance === true,
    keysystem: /\bkey\b/i.test(price),
    clientmods,
    beta: false,
    verified: item?.safety_certified === true,
    warning: item?.use_with_caution === true,
    raknet: item?.raknet === true,
    rating: numericOrNull(item?.rating),
    reviewCount: numericOrNull(item?.review_count),
    stabilityScore: numericOrNull(item?.stability_score),
    myriadScore: numericOrNull(item?.myriad_score),
    sources: ["pulsery"],
    source: "pulsery",
    reviewUrl: null,
    review: ""
  };
}

function normalizeInjectRows(name, item, versions) {
  if (!item || typeof item !== "object") return [];

  const platformNames = unique([
    ...objectKeys(item?.Platforms),
    ...objectKeys(item?.Attributes),
    ...objectKeys(item?.Cost),
    ...objectKeys(item?.Tags),
    ...objectKeys(item?.Links)
  ]);

  return (platformNames.length ? platformNames : ["Unknown"]).map(platformName => {
    const platform = normalizePlatform(platformName);
    const platformInfo = item?.Platforms?.[platformName] || {};
    const attributes = item?.Attributes?.[platformName] || {};
    const tagsInfo = item?.Tags?.[platformName] || {};
    const links = item?.Links?.[platformName] || {};
    const cost = cleanValue(item?.Cost?.[platformName], "Unknown");
    const pricingModels = toArray(attributes?.PricingModel).map(value => String(value));
    const detection = injectDetectionFlags(platformInfo?.Detection);
    const productRobloxVersion = cleanValue(platformInfo?.Versions?.Roblox, "");
    const currentRobloxVersion = injectCurrentVersion(versions, platform);
    const updateStatus = isUsableVersion(productRobloxVersion) && isUsableVersion(currentRobloxVersion)
      ? productRobloxVersion === currentRobloxVersion
      : null;
    const parent = cleanValue(tagsInfo?.Parent, "");
    const rank = cleanValue(tagsInfo?.Rank, "");
    const free = /\bfree\b|freemium/i.test(cost)
      || pricingModels.some(value => /^free$/i.test(value));
    const normalizedTags = unique([
      rank,
      parent,
      cleanValue(attributes?.Access, ""),
      ...pricingModels
    ].map(normalizeTag));

    return {
      id: canonicalName(name),
      name: cleanValue(name, "Unknown"),
      platforms: [platform],
      platform,
      version: cleanValue(platformInfo?.Versions?.Software),
      rbxVersion: cleanValue(productRobloxVersion),
      price: cost,
      free,
      updateStatus,
      updateSource: "Inject",
      detected: detection.detected,
      suncPercentage: null,
      uncPercentage: numericOrNull(attributes?.UNC),
      extType: /aimbot/i.test(parent) ? "aimbot" : normalizeType(attributes?.Type || parent),
      description: cleanValue(attributes?.About || attributes?.Note, ""),
      proSummary: "",
      neutralSummary: "",
      conSummary: "",
      website: safeUrl(links?.Website),
      discord: safeUrl(links?.Discord),
      purchaseLink: null,
      owner: "",
      updatedDate: "Inject catalog",
      tags: normalizedTags,
      badges: [],
      decompiler: attributes?.Decompiler === true,
      multiInject: attributes?.MultipleInstance === true,
      keysystem: pricingModels.some(value => /key[\s-]*system/i.test(value)) || /\bkey\b/i.test(cost),
      clientmods: detection.clientmods,
      beta: rank.toLowerCase() === "beta",
      verified: false,
      warning: attributes?.Caution === true || attributes?.Issues === true,
      raknet: attributes?.Raknet === true,
      rating: null,
      reviewCount: null,
      stabilityScore: null,
      myriadScore: numericOrNull(attributes?.Myriad),
      sources: ["inject"],
      source: "inject",
      reviewUrl: null,
      review: ""
    };
  });
}

function rebuildCatalog() {
  const weao = aggregateByName(state.weaoRows);
  const voxlis = aggregateByName(state.voxlisRows);
  const pulsery = aggregateByName(state.pulseryRows);
  const inject = aggregateByName(state.injectRows);
  const keys = unique([...weao.keys(), ...voxlis.keys(), ...pulsery.keys(), ...inject.keys()]);

  state.all = keys
    .map(key => mergeRows(weao.get(key), voxlis.get(key), pulsery.get(key), inject.get(key), key))
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
    decompiler: a.decompiler || b.decompiler,
    multiInject: a.multiInject || b.multiInject,
    keysystem: a.keysystem || b.keysystem,
    clientmods: a.clientmods || b.clientmods,
    beta: a.beta || b.beta,
    verified: a.verified || b.verified,
    warning: a.warning || b.warning,
    raknet: a.raknet || b.raknet,
    rating: maxNullable(a.rating, b.rating),
    reviewCount: maxNullable(a.reviewCount, b.reviewCount),
    stabilityScore: maxNullable(a.stabilityScore, b.stabilityScore),
    myriadScore: maxNullable(a.myriadScore, b.myriadScore)
  };
}

function mergeRows(weao, voxlis, pulsery, inject, key) {
  const bySource = { weao, voxlis, pulsery, inject };
  const sources = SOURCE_ORDER.filter(source => Boolean(bySource[source]));
  if (!sources.length) return null;

  const rows = sources.map(source => bySource[source]);
  const statusOwner = firstMatchingRow([weao, pulsery, inject, voxlis], row => typeof row?.updateStatus === "boolean");
  const detectionOwner = firstMatchingRow([weao, pulsery, inject, voxlis], row => detectionKind(row) !== "unknown");
  const priceOwner = firstMatchingRow([weao, pulsery, inject, voxlis], row => isSpecificPrice(row?.price))
    || firstMatchingRow([weao, pulsery, inject, voxlis], row => cleanValue(row?.price, "") !== "");
  const typeOwner = firstMatchingRow([weao, pulsery, inject, voxlis], row => cleanValue(row?.extType, "").toLowerCase() !== "unknown");
  const primary = weao || pulsery || inject || voxlis;
  const details = voxlis || pulsery || inject || weao;
  const conflicts = providerConflicts(bySource);

  return {
    ...primary,
    id: key,
    name: firstUsefulValue([weao, pulsery, inject, voxlis], "name", "Unknown"),
    platforms: unique(rows.flatMap(row => row.platforms || [])),
    platform: firstUsefulValue([weao, pulsery, inject, voxlis], "platform", "unknown"),
    version: firstVersionValue([weao, pulsery, inject, voxlis], "version"),
    rbxVersion: firstVersionValue([weao, pulsery, inject, voxlis], "rbxVersion"),
    price: cleanValue(priceOwner?.price, "Unknown"),
    free: typeof priceOwner?.free === "boolean"
      ? priceOwner.free
      : firstMatchingRow(rows, row => typeof row?.free === "boolean")?.free ?? null,
    updateStatus: statusOwner?.updateStatus ?? null,
    updateSource: statusOwner?.updateSource || "",
    detected: detectionOwner?.detected ?? null,
    clientmods: detectionOwner?.clientmods === true,
    suncPercentage: firstFiniteValue([weao, pulsery, inject, voxlis], "suncPercentage"),
    uncPercentage: firstFiniteValue([weao, pulsery, inject, voxlis], "uncPercentage"),
    extType: cleanValue(typeOwner?.extType, "unknown"),
    description: firstUsefulValue([voxlis, pulsery, inject, weao], "description", ""),
    proSummary: details?.proSummary || "",
    neutralSummary: details?.neutralSummary || "",
    conSummary: details?.conSummary || "",
    website: firstUsefulValue([weao, pulsery, inject, voxlis], "website", null),
    discord: firstUsefulValue([weao, pulsery, inject, voxlis], "discord", null),
    purchaseLink: firstUsefulValue([weao, pulsery, inject, voxlis], "purchaseLink", null),
    owner: firstUsefulValue([weao, pulsery, inject, voxlis], "owner", ""),
    updatedDate: firstUsefulValue([weao, pulsery, inject, voxlis], "updatedDate", "N/A"),
    tags: unique(rows.flatMap(row => row.tags || [])),
    badges: unique(rows.flatMap(row => row.badges || [])),
    decompiler: rows.some(row => row.decompiler === true),
    multiInject: rows.some(row => row.multiInject === true),
    keysystem: rows.some(row => row.keysystem === true),
    beta: rows.some(row => row.beta === true),
    verified: rows.some(row => row.verified === true),
    warning: rows.some(row => row.warning === true),
    raknet: rows.some(row => row.raknet === true),
    rating: firstFiniteValue([pulsery, inject, voxlis, weao], "rating"),
    reviewCount: firstFiniteValue([pulsery, inject, voxlis, weao], "reviewCount"),
    stabilityScore: firstFiniteValue([pulsery, inject, voxlis, weao], "stabilityScore"),
    myriadScore: firstFiniteValue([pulsery, inject, voxlis, weao], "myriadScore"),
    source: sources.length > 1 ? "multi" : sources[0],
    sources,
    observations: providerObservations(bySource),
    conflicts,
    reviewUrl: voxlis?.reviewUrl || null,
    review: voxlis?.review || ""
  };
}

function firstMatchingRow(rows, predicate) {
  return rows.find(row => row && predicate(row)) || null;
}

function firstUsefulValue(rows, field, fallback = "") {
  for (const row of rows) {
    const value = row?.[field];
    if (value === null || value === undefined) continue;
    if (typeof value === "string" && !cleanValue(value, "")) continue;
    return value;
  }
  return fallback;
}

function firstVersionValue(rows, field) {
  const row = firstMatchingRow(rows, candidate => isUsableVersion(candidate?.[field]));
  return row ? cleanValue(row[field]) : "N/A";
}

function firstFiniteValue(rows, field) {
  const row = firstMatchingRow(rows, candidate => Number.isFinite(candidate?.[field]));
  return row ? row[field] : null;
}

function providerObservations(bySource) {
  return Object.fromEntries(SOURCE_ORDER
    .filter(source => bySource[source])
    .map(source => {
      const row = bySource[source];
      return [source, {
        updateStatus: row.updateStatus,
        detection: detectionKind(row),
        platforms: row.platforms || [],
        updatedDate: row.updatedDate || ""
      }];
    }));
}

function providerConflicts(bySource) {
  const rows = SOURCE_ORDER.map(source => bySource[source]).filter(Boolean);
  const detectionValues = unique(rows.map(detectionKind).filter(value => value !== "unknown"));
  const updateValues = unique(rows
    .map(row => typeof row.updateStatus === "boolean" ? String(row.updateStatus) : "")
    .filter(Boolean));
  const conflicts = [];
  if (detectionValues.length > 1) conflicts.push("Detection");
  if (updateValues.length > 1) conflicts.push("Update status");
  return conflicts;
}

function applyFilters() {
  const filters = readFilters();
  const term = filters.search.toLowerCase();

  const matches = state.all.filter(item => {
    if (filters.platform === "mobile" && !item.platforms.some(platform => platform === "android" || platform === "ios")) return false;
    if (filters.platform !== "all" && filters.platform !== "mobile" && !item.platforms.includes(filters.platform)) return false;
    if (filters.status === "updated" && item.updateStatus !== true) return false;
    if (filters.status === "outdated" && item.updateStatus !== false) return false;
    if (filters.status === "unknown" && item.updateStatus !== null) return false;
    if (filters.detection !== "all" && detectionKind(item) !== filters.detection) return false;
    if (filters.type !== "all" && item.extType !== filters.type) return false;
    if (filters.price === "free" && item.free !== true) return false;
    if (filters.price === "paid" && item.free !== false) return false;
    if (filters.key === "keysystem" && item.keysystem !== true) return false;
    if (filters.key === "keyless" && item.keysystem === true) return false;
    if (filters.feature !== "all" && !matchesFeature(item, filters.feature)) return false;
    if (!matchesSunc(item, filters.sunc)) return false;
    if (filters.source === "multi" && item.sources.length < 2) return false;
    if (filters.source !== "all" && filters.source !== "multi" && !item.sources.includes(filters.source)) return false;

    if (term) {
      const haystack = [
        item.name,
        item.version,
        item.price,
        item.description,
        item.extType,
        item.owner,
        detectionText(item),
        sourceLabel(item),
        ...(item.conflicts || []),
        ...getFeatures(item),
        ...item.platforms.map(platformLabel),
        ...item.tags,
        ...item.badges
      ].join(" ").toLowerCase();
      if (!haystack.includes(term)) return false;
    }

    return true;
  });

  state.filtered = sortRows(matches, filters.sort);
  dom.resultSummary.textContent = `${state.filtered.length} / ${state.all.length} shown${activeFilterCount(filters) ? ` · ${activeFilterCount(filters)} filter${activeFilterCount(filters) === 1 ? "" : "s"} on` : ""}`;
  renderActiveView();
}

function readFilters() {
  return {
    search: dom.searchInput?.value.trim() || "",
    platform: dom.platformFilter?.value || "all",
    status: dom.statusFilter?.value || "all",
    detection: dom.detectionFilter?.value || "all",
    type: dom.typeFilter?.value || "all",
    price: dom.priceFilter?.value || "all",
    key: dom.keyFilter?.value || "all",
    feature: dom.featureFilter?.value || "all",
    sunc: dom.suncFilter?.value || "all",
    source: dom.sourceFilter?.value || "all",
    sort: dom.sortFilter?.value || "recommended"
  };
}

function activeFilterCount(filters) {
  return Number(Boolean(filters.search))
    + Number(filters.platform !== "all")
    + Number(filters.status !== "all")
    + Number(filters.detection !== "all")
    + Number(filters.type !== "all")
    + Number(filters.price !== "all")
    + Number(filters.key !== "all")
    + Number(filters.feature !== "all")
    + Number(filters.sunc !== "all")
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
  const detection = detectionKind(item);
  if (detection === "undetected") score += 20;
  if (detection === "clientmods") score += 2;
  if (detection === "detected") score -= 80;
  score += Math.max(0, item.sources.length - 1) * 5;
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

  dom.gridView.innerHTML = state.filtered.map((item, index) => {
    const status = updateUi(item);
    const detection = detectionText(item);
    const description = item.description || "No notes yet.";
    const features = getFeatures(item).slice(0, 4);
    const selected = state.compare.has(item.id);

    return `
      <article class="executor-card card-enter${item.warning ? " is-warning" : ""}" style="--card-i:${index % 12}">
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
    dom.tableBody.innerHTML = `<tr><td colspan="10">${emptyStateMarkup(true)}</td></tr>`;
    return;
  }

  dom.tableBody.innerHTML = state.filtered.map((item, index) => {
    const status = updateUi(item);
    return `
      <tr class="row-enter" style="--row-i:${index % 14}">
        <td><label class="compare-check"><input type="checkbox" data-compare="${h(item.id)}" ${state.compare.has(item.id) ? "checked" : ""}><span class="sr-only">Compare ${h(item.name)}</span></label></td>
        <td><span class="table-name">${h(item.name)}</span></td>
        <td><span class="status-badge ${status.className}">${h(status.label)}</span></td>
        <td>${h(detectionText(item))}</td>
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
  return `<div class="empty-state${inTable ? " table-empty" : ""}"><h3>Nothing here.</h3><p>Try fewer filters.</p></div>`;
}

function renderLoadFailure() {
  dom.gridView.innerHTML = `
    <div class="error-state">
      <h3>No feed answered.</h3>
      <p>Check your connection, then hit Recheck.</p>
    </div>`;
  dom.tableBody.innerHTML = "";
  dom.resultSummary.textContent = "No live or saved data.";
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

  const gridIsActive = state.view === "grid";
  dom.catalogResults.dataset.view = state.view;
  dom.gridView.toggleAttribute("hidden", !gridIsActive);
  dom.tableView.toggleAttribute("hidden", gridIsActive);
  dom.gridView.setAttribute("aria-hidden", String(!gridIsActive));
  dom.tableView.setAttribute("aria-hidden", String(gridIsActive));
  if (render) renderActiveView();
}

function updateStats() {
  const total = state.all.length;
  const free = state.all.filter(item => item.free === true).length;
  const updated = state.all.filter(item => item.updateStatus === true).length;
  const clean = state.all.filter(item => detectionKind(item) === "undetected").length;
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

  dom.versionGrid.innerHTML = platforms.map(([key, label], index) => {
    const version = cleanValue(state.versions?.[key]);
    const previousVersion = cleanValue(state.pastVersions?.[key], "");
    const date = cleanValue(state.versions?.[`${key}Date`], "Update time unavailable");
    const mobile = key === "Android" || key === "iOS";
    return `
      <article
        class="version-card data-fresh"
        style="--version-i:${index}"
        tabindex="0"
        data-version-card
        data-version-platform="${h(key)}"
        data-version-label="${h(label)}"
        data-version-current="${h(version)}"
        data-version-previous="${h(previousVersion)}"
        data-version-mobile="${mobile}"
        aria-label="${h(label)} version ${h(version)}. Open its options for more actions."
      >
        <button class="version-menu-trigger" type="button" data-version-menu aria-label="Open ${h(label)} version options" aria-haspopup="menu">•••</button>
        <span>${h(label)}</span>
        <b title="${h(version)}">${h(version)}</b>
        <small>${h(formatVersionDate(date))}</small>
      </article>`;
  }).join("");
}

function bindVersionContextMenu() {
  const menu = dom.versionContextMenu;
  if (!menu || !dom.versionGrid) return;

  const currentAction = menu.querySelector('[data-version-action="current"]');
  const previousAction = menu.querySelector('[data-version-action="previous"]');
  const mobileAction = menu.querySelector('[data-version-action="mobile"]');
  let activeCard = null;
  let closeTimer = 0;

  const closeMenu = ({ returnFocus = false } = {}) => {
    if (menu.hidden) return;
    window.clearTimeout(closeTimer);
    menu.classList.remove("is-open");
    closeTimer = window.setTimeout(() => {
      if (!menu.classList.contains("is-open")) menu.hidden = true;
    }, 220);
    if (returnFocus) activeCard?.querySelector("[data-version-menu]")?.focus();
  };

  const openMenu = (card, x, y) => {
    if (!card) return;
    window.clearTimeout(closeTimer);
    activeCard = card;
    const isMobile = card.dataset.versionMobile === "true";
    const previous = card.dataset.versionPrevious || "";

    if (dom.versionContextPlatform) dom.versionContextPlatform.textContent = card.dataset.versionLabel || "Roblox";
    if (dom.versionContextHash) dom.versionContextHash.textContent = card.dataset.versionCurrent || "Version unavailable";
    if (dom.versionContextCopyLabel) dom.versionContextCopyLabel.textContent = isMobile ? "Copy Version" : "Copy Hash";

    currentAction.hidden = isMobile;
    previousAction.hidden = isMobile;
    mobileAction.hidden = !isMobile;
    previousAction.disabled = !isUsableVersion(previous);
    previousAction.title = previousAction.disabled ? "Previous version unavailable" : "";

    menu.hidden = false;
    menu.style.visibility = "hidden";
    menu.style.left = "0px";
    menu.style.top = "0px";
    void menu.offsetHeight;

    const width = menu.offsetWidth;
    const height = menu.offsetHeight;
    const left = Math.max(10, Math.min(x, window.innerWidth - width - 10));
    const top = Math.max(10, Math.min(y, window.innerHeight - height - 10));
    menu.style.left = `${left}px`;
    menu.style.top = `${top}px`;
    menu.style.visibility = "";
    menu.classList.add("is-open");

    const firstAction = menu.querySelector('button:not([hidden]):not(:disabled)');
    firstAction?.focus({ preventScroll: true });
  };

  dom.versionGrid.addEventListener("contextmenu", event => {
    const card = event.target.closest("[data-version-card]");
    if (!card) return;
    event.preventDefault();
    openMenu(card, event.clientX, event.clientY);
  });

  dom.versionGrid.addEventListener("click", event => {
    const trigger = event.target.closest("[data-version-menu]");
    if (!trigger) return;
    const card = trigger.closest("[data-version-card]");
    const rect = trigger.getBoundingClientRect();
    openMenu(card, rect.right, rect.bottom + 6);
  });

  dom.versionGrid.addEventListener("keydown", event => {
    const card = event.target.closest("[data-version-card]");
    const contextKey = event.key === "ContextMenu" || (event.shiftKey && event.key === "F10");
    if (!card || !contextKey) return;
    event.preventDefault();
    const rect = card.getBoundingClientRect();
    openMenu(card, rect.left + Math.min(36, rect.width / 2), rect.top + 42);
  });

  menu.addEventListener("click", async event => {
    const action = event.target.closest("[data-version-action]")?.dataset.versionAction;
    if (!action || !activeCard) return;

    const platform = activeCard.dataset.versionPlatform;
    const current = activeCard.dataset.versionCurrent || "";
    const previous = activeCard.dataset.versionPrevious || "";

    if (action === "copy") {
      const copied = await copyText(current);
      toast(copied ? `${platform} version copied.` : "Could not copy the version.", copied ? "default" : "error");
    } else if (action === "current") {
      openRddVersion(platform, current);
    } else if (action === "previous") {
      openRddVersion(platform, previous);
    } else if (action === "mobile") {
      if (dom.platformFilter) dom.platformFilter.value = "mobile";
      applyFilters();
      document.querySelector("#catalog")?.scrollIntoView?.({
        behavior: window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches ? "auto" : "smooth",
        block: "start"
      });
      toast("Showing Android + iOS executors.");
    }

    closeMenu();
  });

  document.addEventListener("pointerdown", event => {
    if (menu.contains(event.target) || event.target.closest("[data-version-menu]")) return;
    closeMenu();
  });

  document.addEventListener("keydown", event => {
    if (event.key !== "Escape" || menu.hidden) return;
    event.preventDefault();
    closeMenu({ returnFocus: true });
  });

  window.addEventListener("resize", closeMenu);
  window.addEventListener("scroll", closeMenu, { passive: true });
}

function isUsableVersion(value) {
  const version = String(value || "").trim();
  return Boolean(version) && !/^(?:n\/a|unknown|version unavailable|—)$/i.test(version);
}

function openRddVersion(platform, version) {
  if (!isUsableVersion(version)) {
    toast("That version is unavailable.", "error");
    return;
  }

  const binaryType = platform === "Mac" ? "MacPlayer" : platform === "Windows" ? "WindowsPlayer" : "";
  if (!binaryType) return;

  const url = new URL("https://rdd.weao.gg/");
  url.searchParams.set("binaryType", binaryType);
  url.searchParams.set("channel", "LIVE");
  url.searchParams.set("version", version);
  window.open(url.toString(), "_blank", "noopener,noreferrer");
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
      ${metricMarkup("Detection", detectionText(item))}
      ${metricMarkup("sUNC", percentText(item.suncPercentage))}
      ${metricMarkup("Executor version", item.version)}
      ${metricMarkup("Roblox build", item.rbxVersion)}
      ${metricMarkup("Last reported", item.updatedDate)}
      ${metricMarkup("Source", sourceLabel(item))}
      ${metricMarkup("Type", item.extType)}
      ${Number.isFinite(item.rating) && (item.rating > 0 || item.reviewCount > 0) ? metricMarkup("Pulsery rating", `${trimNumber(item.rating)} / 5`) : ""}
      ${Number.isFinite(item.stabilityScore) ? metricMarkup("Stability", `${trimNumber(item.stabilityScore)} / 100`) : ""}
      ${Number.isFinite(item.myriadScore) ? metricMarkup("Myriad", `${trimNumber(item.myriadScore)} / 100`) : ""}
    </div>
    ${item.conflicts?.length ? `<div class="detail-section source-conflict"><h3>Sources disagree</h3><p>${h(item.conflicts.join(" and "))}. The primary value follows WEAO, then Pulsery, then Inject.</p></div>` : ""}
    ${features.length ? `<div class="detail-section"><h3>Features</h3><div class="feature-row">${features.map(feature => `<span class="feature-chip">${h(feature)}</span>`).join("")}</div></div>` : ""}
    ${item.proSummary ? `<div class="detail-section"><h3>Why people use it</h3><p>${h(item.proSummary)}</p></div>` : ""}
    ${item.neutralSummary ? `<div class="detail-section"><h3>More notes</h3><p>${h(item.neutralSummary)}</p></div>` : ""}
    ${item.conSummary ? `<div class="detail-section"><h3>The catch</h3><p>${h(item.conSummary)}</p></div>` : ""}
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
    ["Detection", item => detectionText(item)],
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
    loading: "SYNCING",
    ready: `LIVE${count ? ` · ${count}` : ""}`,
    cached: `SAVED${count ? ` · ${count}` : ""}`,
    error: "DOWN"
  };
  label.textContent = labels[status] || status;
  updateSyncHeadline();
}

function updateSyncHeadline() {
  const statuses = Object.values(state.health);
  const readyCount = statuses.filter(status => status === "ready").length;
  const cachedCount = statuses.filter(status => status === "cached").length;
  let headline = "Waking up…";
  if (readyCount === statuses.length) headline = "All four feeds are live";
  else if (readyCount > 0) headline = `${readyCount} of ${statuses.length} feeds answered`;
  else if (cachedCount > 0) headline = `Using ${cachedCount} saved feed${cachedCount === 1 ? "" : "s"}`;
  else if (statuses.every(status => status === "error")) headline = "All feeds are down";

  setText("#syncHeadline", headline);
  const date = state.loadedAt instanceof Date && !Number.isNaN(state.loadedAt.valueOf())
    ? state.loadedAt
    : null;
  setText("#lastSync", date ? `Checked ${date.toLocaleString()}` : "Waiting for data…");
}

function hydrateFromCache() {
  try {
    const cached = JSON.parse(localStorage.getItem(CACHE_KEY) || "null");
    if (!cached?.timestamp || Date.now() - cached.timestamp > CACHE_MAX_AGE) return;

    state.weaoRows = Array.isArray(cached.weaoRows) ? cached.weaoRows : [];
    state.voxlisRows = Array.isArray(cached.voxlisRows) ? cached.voxlisRows : [];
    state.pulseryRows = Array.isArray(cached.pulseryRows) ? cached.pulseryRows : [];
    state.injectRows = Array.isArray(cached.injectRows) ? cached.injectRows : [];
    state.versions = cached.versions && typeof cached.versions === "object" ? cached.versions : {};
    state.pastVersions = cached.pastVersions && typeof cached.pastVersions === "object" ? cached.pastVersions : {};
    state.loadedAt = new Date(cached.timestamp);

    if (state.weaoRows.length) setHealth("weao", "cached", state.weaoRows.length);
    if (state.voxlisRows.length) setHealth("voxlis", "cached", state.voxlisRows.length);
    if (state.pulseryRows.length) setHealth("pulsery", "cached", state.pulseryRows.length);
    if (state.injectRows.length) setHealth("inject", "cached", state.injectRows.length);
    renderVersions();
    rebuildCatalog();
  } catch (error) {
    console.warn("Cached Synchrose data could not be read", error);
  }
}

function saveCache() {
  if (!state.weaoRows.length && !state.voxlisRows.length && !state.pulseryRows.length && !state.injectRows.length) return;
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify({
      timestamp: Date.now(),
      weaoRows: state.weaoRows,
      voxlisRows: state.voxlisRows,
      pulseryRows: state.pulseryRows,
      injectRows: state.injectRows,
      versions: state.versions,
      pastVersions: state.pastVersions
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

function resolveSynchroseApiBase() {
  const queryValue = new URLSearchParams(window.location.search).get("api");
  const metaValue = document.querySelector('meta[name="synchrose-api-base"]')?.content;
  let storedValue = "";
  try { storedValue = localStorage.getItem("synchrose:api-base") || ""; } catch { /* Storage is optional. */ }

  const queryBase = validApiBase(queryValue);
  if (queryBase) {
    try { localStorage.setItem("synchrose:api-base", queryBase); } catch { /* Storage is optional. */ }
    return queryBase;
  }

  return validApiBase(metaValue) || validApiBase(storedValue) || "";
}

function validApiBase(value) {
  const text = String(value || "").trim().replace(/\/+$/, "");
  if (!text) return "";
  try {
    const url = new URL(text);
    const localHttp = url.protocol === "http:" && ["localhost", "127.0.0.1"].includes(url.hostname);
    return url.protocol === "https:" || localHttp ? url.toString().replace(/\/+$/, "") : "";
  } catch {
    return "";
  }
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
  if (type.includes("aimbot")) return "aimbot";
  if (type.includes("external")) return "external";
  if (type.includes("internal")) return "internal";
  if (type.includes("server-side") || type.includes("serverside")) return "serverside";
  if (type === "executor") return "internal";
  if (type.endsWith("executor")) return "internal";
  return type || "unknown";
}

function injectDetectionFlags(value) {
  const readable = cleanValue(value?.Readable ?? value, "").toLowerCase();
  if (/client[\s-]*mod/.test(readable)) return { detected: false, clientmods: true };
  if (readable.includes("undetected")) return { detected: false, clientmods: false };
  if (readable.includes("detected")) return { detected: true, clientmods: false };
  return { detected: null, clientmods: false };
}

function injectCurrentVersion(versions, platform) {
  const key = normalizePlatform(platform) === "mac" ? "Macintosh" : "Windows";
  return cleanValue(versions?.[key]?.Version ?? versions?.[key], "");
}

function updateUi(item) {
  if (item.updateStatus === true) return { label: "Updated", className: "updated" };
  if (item.updateStatus === false) return { label: "Outdated", className: "outdated" };
  return { label: "Unknown", className: "unknown" };
}

function detectionKind(item) {
  if (item?.clientmods === true) return "clientmods";
  if (item?.detected === true) return "detected";
  if (item?.detected === false) return "undetected";
  return "unknown";
}

function detectionText(item) {
  const kind = detectionKind(item);
  if (kind === "clientmods") return "Client-mod bypass only";
  if (kind === "detected") return "Detected";
  if (kind === "undetected") return "Full undetected";
  return "Unknown";
}

function matchesFeature(item, feature) {
  if (feature === "warning") return item.warning === true;
  return item?.[feature] === true;
}

function matchesSunc(item, filter) {
  if (filter === "all") return true;
  if (filter === "unknown") return !Number.isFinite(item.suncPercentage);
  if (filter === "measured") return Number.isFinite(item.suncPercentage);
  const minimum = Number(filter);
  return Number.isFinite(minimum) && Number.isFinite(item.suncPercentage) && item.suncPercentage >= minimum;
}

function sourceLabel(item) {
  const sources = Array.isArray(item?.sources) ? item.sources : [];
  return sources.length
    ? sources.map(source => SOURCE_LABELS[source] || source).join(" + ")
    : "Unknown";
}

function sourceBadges(item) {
  const sources = Array.isArray(item?.sources) ? item.sources : [];
  const badges = sources.map(source => `<span class="source-badge source-${h(source)}">${h(SOURCE_LABELS[source] || source)}</span>`);
  if (item?.conflicts?.length) {
    badges.push(`<span class="source-badge conflict" title="${h(`${item.conflicts.join(", ")} differs between sources`)}">Conflict</span>`);
  }
  return badges.join("");
}

function getFeatures(item) {
  const features = [];
  if (item.verified) features.push("Verified");
  if (item.decompiler) features.push("Decompiler");
  if (item.multiInject) features.push("Multi-instance");
  if (item.raknet) features.push("RakNet");
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
  if (value === null || value === undefined || String(value).trim() === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function percentOrNull(value) {
  if (value === null || value === undefined) return null;
  const number = Number(String(value).replace(/[%\s,]/g, ""));
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

function objectKeys(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? Object.keys(value) : [];
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

async function copyText(value) {
  const text = String(value || "");
  if (!text) return false;

  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    // Fall through to the selection-based copy path.
  }

  const field = document.createElement("textarea");
  field.value = text;
  field.setAttribute("readonly", "");
  field.style.position = "fixed";
  field.style.opacity = "0";
  document.body.append(field);
  field.select();
  let copied = false;
  try {
    copied = document.execCommand?.("copy") === true;
  } catch {
    copied = false;
  }
  field.remove();
  return copied;
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
