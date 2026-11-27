import { normalizeNode, findNode, getAllFiles, countFiles } from "./tree.js";

const SITE_LABEL = window.location.hostname || "Site files";
document.title = `${SITE_LABEL} // files`;
document.getElementById("siteHostLabel").textContent = SITE_LABEL;

const CONFIG = {
  owner: "mxsynry",
  repo: "mxsynry.github.io",
  branch: "main",
  pagesOrigin: window.location.origin,
};

let snapshot = null;
let viewMode =
  localStorage.getItem("mxsynry:viewMode") ||
  localStorage.getItem("repoBrowser:viewMode") ||
  "grid";
let currentPath = "";
let searchQuery = "";
let expandedDirs = new Set();
let htmlOpenMode =
  localStorage.getItem("mxsynry:htmlOpenMode") ||
  localStorage.getItem("repoBrowser:htmlOpenMode") ||
  "pages";

function formatSize(bytes) {
  if (bytes == null) return "";
  const units = ["B", "KB", "MB", "GB"];
  let i = 0;
  while (bytes >= 1024 && i < units.length - 1) {
    bytes /= 1024;
    i++;
  }
  return bytes.toFixed(i === 0 ? 0 : 1) + " " + units[i];
}

function extOf(name = "") {
  return (String(name).split(".").pop() || "").toLowerCase();
}
function isHtmlFile(node) {
  return (
    node && node.type !== "dir" && ["html", "htm"].includes(extOf(node.name))
  );
}
function encodePath(path = "") {
  return path.split("/").filter(Boolean).map(encodeURIComponent).join("/");
}
function getPagesUrl(path = "") {
  return CONFIG.pagesOrigin.replace(/\/$/, "") + "/" + encodePath(path);
}
function getGitHubUrl(path = "", type = "file") {
  const kind = type === "dir" ? "tree" : "blob";
  return `https://github.com/${CONFIG.owner}/${CONFIG.repo}/${kind}/${CONFIG.branch}/${encodePath(path)}`;
}
function getRawUrl(path = "") {
  return `https://raw.githubusercontent.com/${CONFIG.owner}/${CONFIG.repo}/${CONFIG.branch}/${encodePath(path)}`;
}

function getIcon(node) {
  if (node.type === "dir") return { char: "📁", color: "var(--dir)" };
  const ext = extOf(node.name);
  const map = {
    html: { char: "🌐", color: "var(--pink)" },
    htm: { char: "🌐", color: "var(--pink)" },
    css: { char: "🎨", color: "var(--blue)" },
    scss: { char: "🎨", color: "var(--blue)" },
    js: { char: "📜", color: "var(--code)" },
    ts: { char: "📜", color: "var(--code)" },
    lua: { char: "📜", color: "var(--code)" },
    luau: { char: "📜", color: "var(--code)" },
    rb: { char: "📜", color: "var(--code)" },
    md: { char: "📄", color: "var(--text)" },
    txt: { char: "📄", color: "var(--text)" },
    yml: { char: "⚙️", color: "var(--text-muted)" },
    yaml: { char: "⚙️", color: "var(--text-muted)" },
    json: { char: "📦", color: "var(--archive)" },
    mp4: { char: "🎬", color: "var(--media)" },
    webm: { char: "🎬", color: "var(--media)" },
    mov: { char: "🎬", color: "var(--media)" },
    mp3: { char: "🎧", color: "var(--green)" },
    wav: { char: "🎧", color: "var(--green)" },
    ogg: { char: "🎧", color: "var(--green)" },
    m4a: { char: "🎧", color: "var(--green)" },
    flac: { char: "🎧", color: "var(--green)" },
    png: { char: "🖼️", color: "var(--media)" },
    jpg: { char: "🖼️", color: "var(--media)" },
    jpeg: { char: "🖼️", color: "var(--media)" },
    gif: { char: "🖼️", color: "var(--media)" },
    webp: { char: "🖼️", color: "var(--media)" },
    svg: { char: "🖼️", color: "var(--media)" },
    ico: { char: "🖼️", color: "var(--media)" },
    rar: { char: "🗜️", color: "var(--archive)" },
    zip: { char: "🗜️", color: "var(--archive)" },
    tar: { char: "🗜️", color: "var(--archive)" },
    gz: { char: "🗜️", color: "var(--archive)" },
  };
  if (String(node.name).toLowerCase() === "gemfile")
    return { char: "💎", color: "var(--archive)" };
  return map[ext] || { char: "📄", color: "var(--file)" };
}

function escapeHtml(str) {
  if (str == null) return "";
  return String(str).replace(
    /[&<>"']/g,
    (m) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        m
      ],
  );
}

function showToast(message) {
  const toast = document.getElementById("toast");
  toast.textContent = message;
  toast.classList.add("show");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.classList.remove("show"), 2600);
}

function buildTreeHTML(node, path = "", level = 0) {
  if (!node || !node.children) return "";
  const sorted = [...node.children].sort(sortDirsFirst);
  return sorted
    .map((child) => {
      const childPath = path ? path + "/" + child.name : child.name;
      const isDir = child.type === "dir";
      const icon = getIcon(child);
      const isExpanded = expandedDirs.has(childPath);
      const isActive =
        currentPath === childPath ||
        (currentPath && currentPath.startsWith(childPath + "/"));
      const indent = level * 16;
      let html = `<div class="tree-item" data-path="${escapeHtml(childPath)}" data-type="${child.type}" style="padding-left:${indent + 8}px" title="${escapeHtml(child.name)}">`;
      html += isDir
        ? `<span class="tree-toggle" data-path="${escapeHtml(childPath)}">${isExpanded ? "▼" : "▶"}</span>`
        : '<span class="tree-spacer"></span>';
      html += `<span class="tree-icon" style="color:${icon.color}">${icon.char}</span>`;
      html += `<span class="tree-label${isActive ? " active" : ""}">${escapeHtml(child.name)}</span></div>`;
      if (isDir && isExpanded)
        html += buildTreeHTML(child, childPath, level + 1);
      return html;
    })
    .join("");
}

function sortDirsFirst(a, b) {
  if (a.type === b.type) return a.name.localeCompare(b.name);
  return a.type === "dir" ? -1 : 1;
}

function actionButtons(item, path, isDir) {
  if (isDir) {
    return `<a class="mini-btn primary btn-open" href="#" data-action="open-folder">Open</a><a class="mini-btn" href="${escapeHtml(item.html_url || getGitHubUrl(path, "dir"))}" target="_blank" rel="noopener" data-action="external">GitHub</a>`;
  }
  const raw = item.download_url || getRawUrl(path);
  const gh = item.html_url || getGitHubUrl(path, "file");
  const site = getPagesUrl(path);
  const htmlSite = isHtmlFile(item)
    ? `<a class="mini-btn primary" href="${escapeHtml(site)}" target="_blank" rel="noopener" data-action="external">Site</a>`
    : "";
  return `${htmlSite}<a class="mini-btn" href="#" data-action="preview">Preview</a><a class="mini-btn" href="${escapeHtml(gh)}" target="_blank" rel="noopener" data-action="external">GitHub</a><a class="mini-btn" href="${escapeHtml(raw)}" target="_blank" rel="noopener" download data-action="external">Raw</a>`;
}

function render() {
  if (!snapshot) return;
  const main = document.getElementById("main");
  const breadcrumb = document.getElementById("breadcrumb");
  const badge = document.getElementById("fileCountBadge");
  const treeEl = document.getElementById("tree");
  const modeBadge = document.getElementById("currentModeBadge");

  treeEl.innerHTML = buildTreeHTML(snapshot, "", 0);
  treeEl.querySelectorAll(".tree-item").forEach((el) => {
    el.addEventListener("click", (e) => {
      const path = el.dataset.path;
      const type = el.dataset.type;
      if (type === "dir") {
        if (e.target.classList.contains("tree-toggle")) {
          e.stopPropagation();
          expandedDirs.has(path)
            ? expandedDirs.delete(path)
            : expandedDirs.add(path);
          render();
        } else navigateTo(path);
      } else {
        const node = findNode(snapshot, path);
        if (node) handleFileOpen(node, path);
      }
    });
  });

  const parts = currentPath ? currentPath.split("/").filter(Boolean) : [];
  let bcHtml = `<span class="bc-root" data-path="">${escapeHtml(SITE_LABEL)}</span>`;
  let acc = "";
  parts.forEach((part, i) => {
    acc = acc ? acc + "/" + part : part;
    bcHtml += '<span class="bc-sep">/</span>';
    bcHtml +=
      i === parts.length - 1
        ? `<span class="bc-current">${escapeHtml(part)}</span>`
        : `<span class="bc-part" data-path="${escapeHtml(acc)}">${escapeHtml(part)}</span>`;
  });
  breadcrumb.innerHTML = bcHtml;
  breadcrumb
    .querySelectorAll(".bc-root, .bc-part")
    .forEach((el) =>
      el.addEventListener("click", () => navigateTo(el.dataset.path || "")),
    );

  let items;
  let noteText;
  if (searchQuery) {
    const q = searchQuery.toLowerCase();
    items = getAllFiles(snapshot)
      .filter(
        (f) =>
          f.name.toLowerCase().includes(q) ||
          f.fullPath.toLowerCase().includes(q),
      )
      .sort((a, b) => a.fullPath.localeCompare(b.fullPath));
    noteText = `<strong>Search:</strong> ${escapeHtml(searchQuery)} · ${items.length} result${items.length === 1 ? "" : "s"}`;
  } else {
    const node = findNode(snapshot, currentPath) || snapshot;
    items = [...(node.children || [])].sort(sortDirsFirst);
    noteText = `<strong>${escapeHtml(currentPath || "Root")}</strong> · ${items.length} item${items.length === 1 ? "" : "s"}`;
  }

  badge.textContent = countFiles(snapshot) + " files";
  modeBadge.textContent =
    "HTML opens: " +
    ({ pages: "Site path", preview: "Preview", github: "GitHub", raw: "Raw" }[
      htmlOpenMode
    ] || "Site path");

  if (!items.length) {
    main.innerHTML =
      '<div class="empty"><div><strong>No files found.</strong><br>Try a different search term or folder.</div></div>';
    return;
  }

  const note = `<div class="path-note"><span>${noteText}</span><span>HTML opens on site path by default.</span></div>`;
  if (viewMode === "grid") renderGrid(main, items, note);
  else renderList(main, items, note);
}

function renderGrid(main, items, note) {
  main.innerHTML = note + '<div class="file-grid" id="fileGrid"></div>';
  const grid = document.getElementById("fileGrid");
  for (const item of items) {
    const isDir = item.type === "dir";
    const path = searchQuery
      ? item.fullPath
      : currentPath
        ? currentPath + "/" + item.name
        : item.name;
    const icon = getIcon(item);
    const card = document.createElement("div");
    card.className = "card";
    card.dataset.path = path;
    card.dataset.type = item.type;
    card.innerHTML = `
      <div class="icon" style="color:${icon.color}">${icon.char}</div>
      <div class="name" title="${escapeHtml(item.name)}">${escapeHtml(item.name)}</div>
      <div class="path" title="${escapeHtml(path)}">${escapeHtml(path)}</div>
      <div class="meta"><span>${isDir ? (item.children || []).length + " items" : formatSize(item.size)}</span><span>${isDir ? "folder" : extOf(item.name) || "file"}</span></div>
      <div class="actions">${actionButtons(item, path, isDir)}</div>`;
    card.addEventListener("click", (e) => {
      if (e.target.closest("a")) return;
      isDir ? navigateTo(path) : handleFileOpen(item, path);
    });
    card
      .querySelector('[data-action="preview"]')
      ?.addEventListener("click", (e) => {
        e.preventDefault();
        previewFile(item, path);
      });
    card
      .querySelector('[data-action="open-folder"]')
      ?.addEventListener("click", (e) => {
        e.preventDefault();
        navigateTo(path);
      });
    grid.appendChild(card);
  }
}

function renderList(main, items, note) {
  main.innerHTML = note + '<div class="file-list" id="fileList"></div>';
  const list = document.getElementById("fileList");
  for (const item of items) {
    const isDir = item.type === "dir";
    const path = searchQuery
      ? item.fullPath
      : currentPath
        ? currentPath + "/" + item.name
        : item.name;
    const icon = getIcon(item);
    const row = document.createElement("div");
    row.className = "file-row";
    row.dataset.path = path;
    row.dataset.type = item.type;
    row.innerHTML = `
      <span class="icon" style="color:${icon.color}">${icon.char}</span>
      <span><span class="name" title="${escapeHtml(item.name)}">${escapeHtml(item.name)}</span><div class="subpath" title="${escapeHtml(path)}">${escapeHtml(path)}</div></span>
      <span class="size">${isDir ? (item.children || []).length + " items" : formatSize(item.size)}</span>
      <div class="actions">${actionButtons(item, path, isDir)}</div>`;
    row.addEventListener("click", (e) => {
      if (e.target.closest("a")) return;
      isDir ? navigateTo(path) : handleFileOpen(item, path);
    });
    row
      .querySelector('[data-action="preview"]')
      ?.addEventListener("click", (e) => {
        e.preventDefault();
        previewFile(item, path);
      });
    row
      .querySelector('[data-action="open-folder"]')
      ?.addEventListener("click", (e) => {
        e.preventDefault();
        navigateTo(path);
      });
    list.appendChild(row);
  }
}

function navigateTo(path) {
  currentPath = path || "";
  searchQuery = "";
  const search = document.getElementById("search");
  if (search) search.value = "";
  if (path) {
    const parts = path.split("/").filter(Boolean);
    let acc = "";
    for (const part of parts) {
      acc = acc ? acc + "/" + part : part;
      expandedDirs.add(acc);
    }
  }
  render();
}

function handleFileOpen(item, path) {
  if (!isHtmlFile(item)) return previewFile(item, path);
  if (htmlOpenMode === "pages")
    window.open(getPagesUrl(path), "_blank", "noopener");
  else if (htmlOpenMode === "github")
    window.open(
      item.html_url || getGitHubUrl(path, "file"),
      "_blank",
      "noopener",
    );
  else if (htmlOpenMode === "raw")
    window.open(item.download_url || getRawUrl(path), "_blank", "noopener");
  else previewFile(item, path);
}

function openPreview() {
  const overlay = document.getElementById("previewOverlay");
  overlay.classList.add("active");
  overlay.setAttribute("aria-hidden", "false");
}
function closePreview() {
  const overlay = document.getElementById("previewOverlay");
  overlay.classList.remove("active");
  overlay.setAttribute("aria-hidden", "true");
}

function previewFile(item, path) {
  const title = document.getElementById("previewTitle");
  const body = document.getElementById("previewBody");
  const actions = document.getElementById("previewActions");
  const raw = item.download_url || getRawUrl(path);
  const gh = item.html_url || getGitHubUrl(path, "file");
  const site = getPagesUrl(path);
  title.textContent = item.name;
  body.innerHTML = '<div class="loading">Loading preview...</div>';
  actions.innerHTML = `${isHtmlFile(item) ? `<a class="mini-btn primary" href="${escapeHtml(site)}" target="_blank" rel="noopener">Open on site</a>` : ""}<a class="mini-btn" href="${escapeHtml(raw)}" target="_blank" rel="noopener" download>Raw / Download</a><a class="mini-btn" href="${escapeHtml(gh)}" target="_blank" rel="noopener">GitHub</a><button class="mini-btn" id="previewCloseBtn" type="button">Close</button>`;
  openPreview();
  document.getElementById("previewCloseBtn").onclick = closePreview;

  const ext = extOf(item.name);
  const isImage = ["png", "jpg", "jpeg", "gif", "ico", "webp", "svg"].includes(
    ext,
  );
  const isVideo = ["mp4", "webm", "mov"].includes(ext);
  const isAudio = ["mp3", "wav", "ogg", "m4a", "flac"].includes(ext);
  const isText =
    [
      "html",
      "htm",
      "css",
      "js",
      "ts",
      "lua",
      "luau",
      "md",
      "json",
      "yml",
      "yaml",
      "txt",
      "rb",
    ].includes(ext) ||
    String(item.name).toLowerCase() === "gemfile" ||
    (item.size && item.size < 500000);

  if (isImage)
    body.innerHTML = `<img src="${escapeHtml(raw)}" alt="${escapeHtml(item.name)}">`;
  else if (isVideo) {
    const type =
      ext === "mp4"
        ? "video/mp4"
        : ext === "webm"
          ? "video/webm"
          : ext === "mov"
            ? "video/quicktime"
            : "";
    body.innerHTML = `<video controls playsinline preload="metadata"><source src="${escapeHtml(raw)}"${type ? ` type="${type}"` : ""}>Your browser cannot preview this video. Use Raw / Download below.</video>`;
  } else if (isAudio) {
    const type =
      ext === "mp3"
        ? "audio/mpeg"
        : ext === "wav"
          ? "audio/wav"
          : ext === "ogg"
            ? "audio/ogg"
            : ext === "m4a"
              ? "audio/mp4"
              : ext === "flac"
                ? "audio/flac"
                : "";
    body.innerHTML = `<div class="audio-preview"><div class="audio-name">${escapeHtml(item.name)}</div><audio controls preload="metadata"><source src="${escapeHtml(raw)}"${type ? ` type="${type}"` : ""}>Your browser cannot preview this audio. Use Raw / Download below.</audio></div>`;
  } else if (isText) {
    fetch(raw)
      .then((r) => {
        if (!r.ok) throw new Error("HTTP " + r.status);
        return r.text();
      })
      .then((text) => {
        body.innerHTML = `<pre>${escapeHtml(text)}</pre>`;
      })
      .catch(() => {
        body.innerHTML = '<div class="empty">Could not load preview.</div>';
      });
  } else {
    body.innerHTML = `<div class="empty"><div><strong>Preview not available.</strong><br><br><a class="mini-btn primary" href="${escapeHtml(raw)}" target="_blank" rel="noopener" download>Download file</a></div></div>`;
  }
}

function collectDirs(node, prefix = "") {
  if (!node || !node.children) return;
  for (const child of node.children) {
    if (child.type === "dir") {
      const p = prefix ? prefix + "/" + child.name : child.name;
      expandedDirs.add(p);
      collectDirs(child, p);
    }
  }
}

function bindUi() {
  const search = document.getElementById("search");
  const modeSelect = document.getElementById("htmlOpenMode");
  document
    .getElementById("btnGrid")
    .classList.toggle("active", viewMode === "grid");
  document
    .getElementById("btnList")
    .classList.toggle("active", viewMode === "list");
  modeSelect.value = htmlOpenMode;

  search.addEventListener("input", (e) => {
    searchQuery = e.target.value.trim();
    render();
  });
  search.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      search.value = "";
      searchQuery = "";
      render();
    }
  });
  document.getElementById("btnGrid").addEventListener("click", () => {
    viewMode = "grid";
    localStorage.setItem("mxsynry:viewMode", viewMode);
    document.getElementById("btnGrid").classList.add("active");
    document.getElementById("btnList").classList.remove("active");
    render();
  });
  document.getElementById("btnList").addEventListener("click", () => {
    viewMode = "list";
    localStorage.setItem("mxsynry:viewMode", viewMode);
    document.getElementById("btnList").classList.add("active");
    document.getElementById("btnGrid").classList.remove("active");
    render();
  });
  modeSelect.addEventListener("change", (e) => {
    htmlOpenMode = e.target.value;
    localStorage.setItem("mxsynry:htmlOpenMode", htmlOpenMode);
    render();
    showToast(
      "HTML open mode: " + modeSelect.options[modeSelect.selectedIndex].text,
    );
  });
  document.getElementById("btnExpandAll").addEventListener("click", () => {
    collectDirs(snapshot);
    render();
  });
  document.getElementById("btnCollapseAll").addEventListener("click", () => {
    expandedDirs.clear();
    render();
  });
  document
    .getElementById("btnRefresh")
    .addEventListener("click", () => location.reload());
  document
    .getElementById("previewClose")
    .addEventListener("click", closePreview);
  document.getElementById("previewOverlay").addEventListener("click", (e) => {
    if (e.target.id === "previewOverlay") closePreview();
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closePreview();
  });
}

function buildSnapshotFromGitTree(tree) {
  const root = {
    name: CONFIG.repo,
    type: "dir",
    path: "",
    fullPath: "",
    children: [],
  };
  const dirs = new Map([["", root]]);
  const items = [...tree].sort((a, b) => a.path.localeCompare(b.path));
  for (const item of items) {
    const parts = item.path.split("/").filter(Boolean);
    const name = parts.pop();
    const parentPath = parts.join("/");
    let parent = dirs.get(parentPath);
    if (!parent) {
      let acc = "";
      parent = root;
      for (const part of parts) {
        const nextPath = acc ? acc + "/" + part : part;
        let dir = dirs.get(nextPath);
        if (!dir) {
          dir = {
            name: part,
            type: "dir",
            path: nextPath,
            fullPath: nextPath,
            children: [],
            html_url: getGitHubUrl(nextPath, "dir"),
          };
          parent.children.push(dir);
          dirs.set(nextPath, dir);
        }
        parent = dir;
        acc = nextPath;
      }
    }
    const fullPath = item.path;
    if (item.type === "tree") {
      const dir = {
        name,
        type: "dir",
        path: fullPath,
        fullPath,
        children: [],
        html_url: getGitHubUrl(fullPath, "dir"),
      };
      parent.children.push(dir);
      dirs.set(fullPath, dir);
    } else if (item.type === "blob") {
      parent.children.push({
        name,
        type: "file",
        path: fullPath,
        fullPath,
        size: item.size,
        html_url: getGitHubUrl(fullPath, "file"),
        download_url: getRawUrl(fullPath),
      });
    }
  }
  return root;
}

async function fetchSnapshot() {
  try {
    const local = await fetch("./tree.json", { cache: "no-store" });
    if (local.ok) return normalizeNode(await local.json());
  } catch (_) {}

  const branches = [CONFIG.branch, "master"];
  for (const branch of branches) {
    try {
      const url = `https://api.github.com/repos/${CONFIG.owner}/${CONFIG.repo}/git/trees/${branch}?recursive=1`;
      const res = await fetch(url, {
        headers: { Accept: "application/vnd.github+json" },
      });
      if (!res.ok) continue;
      const data = await res.json();
      CONFIG.branch = branch;
      return buildSnapshotFromGitTree(data.tree || []);
    } catch (_) {}
  }
  throw new Error("Failed to load tree.json and GitHub API fallback.");
}

async function init() {
  bindUi();
  document.getElementById("main").innerHTML =
    '<div class="empty"><div><strong>Loading repository index...</strong><br>Reading tree.json, then falling back to GitHub API if needed.</div></div>';
  try {
    snapshot = await fetchSnapshot();
    render();
  } catch (error) {
    console.error(error);
    document.getElementById("main").innerHTML =
      `<div class="empty" style="color:var(--danger)"><div><strong>Failed to load index.</strong><br>${escapeHtml(error.message)}<br><br>Make sure <code>tree.json</code> exists beside this HTML file, or allow GitHub API access.</div></div>`;
  }
}

init();
