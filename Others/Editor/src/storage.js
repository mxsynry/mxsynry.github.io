import { safeFileName } from "./filenames.js";

function joinUrl(base, path) {
  return (
    String(base || "").replace(/\/$/, "") +
    "/" +
    String(path || "").replace(/^\//, "")
  );
}

export function createApiClient(options) {
  let apiOnline = null;

  async function request(path, init = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), options.apiTimeoutMs);
    try {
      const response = await fetch(joinUrl(options.apiBase, path), {
        ...init,
        signal: controller.signal,
      });
      if (!response.ok) {
        const msg = await response.text().catch(() => response.statusText);
        throw new Error(msg || `HTTP ${response.status}`);
      }
      return response;
    } finally {
      clearTimeout(timer);
    }
  }

  async function isOnline() {
    if (!options.useApi) return false;
    if (apiOnline !== null) return apiOnline;
    try {
      await request("/files");
      apiOnline = true;
    } catch {
      apiOnline = false;
    }
    return apiOnline;
  }

  function markOffline() {
    apiOnline = false;
  }

  return { request, isOnline, markOffline };
}

export function createStorage(options, api) {
  function localRead() {
    try {
      const raw = localStorage.getItem(options.storageKey);
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      if (!Array.isArray(parsed.tabs)) return null;
      return parsed;
    } catch {
      return null;
    }
  }

  function localWrite(state) {
    const serializable = {
      activeName: state.activeName,
      tabs: state.tabs.map((tab) => ({
        name: tab.name,
        content: tab.content || "",
        updatedAt: tab.updatedAt || Date.now(),
      })),
    };
    localStorage.setItem(options.storageKey, JSON.stringify(serializable));
  }

  async function loadFromApi() {
    if (!(await api.isOnline())) return null;
    const filesResponse = await api.request("/files");
    const files = await filesResponse.json();
    if (!Array.isArray(files)) return null;

    const tabs = [];
    for (const file of files) {
      const name = safeFileName(file && file.name);
      if (!name || name === "undefined") continue;
      try {
        const response = await api.request(
          "/opentab/" + encodeURIComponent(name),
        );
        tabs.push({
          name,
          content: await response.text(),
          updatedAt: Date.now(),
        });
      } catch {
        tabs.push({ name, content: "", updatedAt: Date.now() });
      }
    }
    return tabs.length ? { activeName: tabs[0].name, tabs } : null;
  }

  async function saveToApi(tab) {
    if (!(await api.isOnline())) return false;
    try {
      await api.request("/savetab/" + encodeURIComponent(tab.name), {
        method: "POST",
        headers: { "Content-Type": "text/plain" },
        body: tab.content || "",
      });
      return true;
    } catch (error) {
      api.markOffline();
      console.warn("API save failed; using localStorage fallback:", error);
      return false;
    }
  }

  async function createOnApi(name) {
    if (!(await api.isOnline())) return false;
    try {
      await api.request("/addtab/" + encodeURIComponent(name), {
        method: "POST",
      });
      return true;
    } catch (error) {
      api.markOffline();
      console.warn("API add failed; using localStorage fallback:", error);
      return false;
    }
  }

  async function deleteOnApi(name) {
    if (!(await api.isOnline())) return false;
    try {
      await api.request("/delete/" + encodeURIComponent(name), {
        method: "DELETE",
      });
      return true;
    } catch (error) {
      api.markOffline();
      console.warn("API delete failed; using localStorage fallback:", error);
      return false;
    }
  }

  return {
    localRead,
    localWrite,
    loadFromApi,
    saveToApi,
    createOnApi,
    deleteOnApi,
  };
}
