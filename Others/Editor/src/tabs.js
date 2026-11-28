import { createApiClient, createStorage } from "./storage.js";
import { safeFileName } from "./filenames.js";
import { installDynamicIntellisense } from "./completions.js";

const DEFAULTS = {
  apiBase: "http://localhost:9911",
  storageKey: "mxsynry:luau-editor-tabs:v2",
  firstTabName: "main.lua",
  tabContainerId: "tabcon",
  addButtonId: "open_addtab",
  tabNameInputId: "tabname",
  modalId: "addtab",
  saveDebounceMs: 450,
  apiTimeoutMs: 900,
  useApi: true,
};

function toast(ok, message) {
  if (typeof window.Toastify === "function") {
    window
      .Toastify({
        text: message,
        duration: 2200,
        gravity: "top",
        position: "right",
        close: true,
        stopOnFocus: true,
        style: {
          background: ok
            ? "linear-gradient(135deg,#16a34a,#22c55e)"
            : "linear-gradient(135deg,#dc2626,#ef4444)",
        },
      })
      .showToast();
    return;
  }
  (ok ? console.log : console.warn)(message);
}

export function initEditorTabs(userOptions) {
  const options = { ...DEFAULTS, ...(userOptions || {}) };
  const editor = options.editor || window.editor || window.editorInstance;
  const monaco = options.monaco || window.monaco;
  if (!editor || !monaco)
    throw new Error("LuauEditorTools.init requires Monaco editor and monaco.");

  const api = createApiClient(options);
  const storage = createStorage(options, api);
  const state = {
    tabs: [],
    activeName: "",
    isApplyingEditorValue: false,
    saveTimer: null,
  };

  function getTab(name = state.activeName) {
    return state.tabs.find((tab) => tab.name === name) || null;
  }

  function ensureMainTab() {
    if (!state.tabs.length) {
      state.tabs.push({
        name: options.firstTabName,
        content: "",
        updatedAt: Date.now(),
      });
      state.activeName = options.firstTabName;
    }
    if (!state.activeName || !getTab(state.activeName))
      state.activeName = state.tabs[0].name;
  }

  function persistLocal() {
    storage.localWrite(state);
  }

  async function persistActiveToApi() {
    const tab = getTab();
    if (!tab) return;
    await storage.saveToApi(tab);
  }

  function syncActiveFromEditor() {
    const tab = getTab();
    if (!tab || !editor) return;
    tab.content = editor.getValue();
    tab.updatedAt = Date.now();
  }

  function scheduleSave() {
    if (state.isApplyingEditorValue) return;
    syncActiveFromEditor();
    persistLocal();
    clearTimeout(state.saveTimer);
    state.saveTimer = setTimeout(
      () => persistActiveToApi(),
      options.saveDebounceMs,
    );
  }

  function renderTabs() {
    const tabcon = document.getElementById(options.tabContainerId);
    if (!tabcon) return;
    tabcon.innerHTML = "";

    state.tabs.forEach((tab) => {
      const wrapper = document.createElement("div");
      wrapper.className =
        "grid-tab btn_tab px-1 mx-1" +
        (tab.name === state.activeName ? " active-tab" : "");
      wrapper.dataset.file = tab.name;

      const openBtn = document.createElement("button");
      openBtn.className = "text-start btn_intab tab-title";
      openBtn.textContent = tab.name;
      openBtn.title = tab.name;
      openBtn.addEventListener("click", () => openTab(tab.name));

      const closeBtn = document.createElement("button");
      closeBtn.className = "btn_intab tab-close";
      closeBtn.type = "button";
      closeBtn.textContent = "×";
      closeBtn.title = "Close tab";
      closeBtn.addEventListener("click", (event) => {
        event.stopPropagation();
        deleteTab(tab.name);
      });

      wrapper.append(openBtn, closeBtn);
      tabcon.appendChild(wrapper);
    });
  }

  function applyEditorValue(value) {
    state.isApplyingEditorValue = true;
    editor.setValue(value || "");
    state.isApplyingEditorValue = false;
    editor.focus();
  }

  async function openTab(name) {
    name = safeFileName(name);
    if (!name) return;
    syncActiveFromEditor();
    persistLocal();
    await persistActiveToApi();

    let tab = getTab(name);
    if (!tab) {
      tab = { name, content: "", updatedAt: Date.now() };
      state.tabs.push(tab);
    }

    state.activeName = name;
    applyEditorValue(tab.content);
    renderTabs();
    persistLocal();
  }

  async function addTab(name) {
    name = safeFileName(
      name || document.getElementById(options.tabNameInputId)?.value,
    );
    if (!name) return toast(false, "Please enter a tab name.");
    if (getTab(name)) return toast(false, `${name} already exists.`);

    syncActiveFromEditor();
    await storage.createOnApi(name);
    state.tabs.push({ name, content: "", updatedAt: Date.now() });
    state.activeName = name;
    applyEditorValue("");
    renderTabs();
    persistLocal();

    const input = document.getElementById(options.tabNameInputId);
    if (input) input.value = "";
    const modalEl = document.getElementById(options.modalId);
    if (modalEl && window.bootstrap) {
      const modal =
        window.bootstrap.Modal.getInstance(modalEl) ||
        new window.bootstrap.Modal(modalEl);
      modal.hide();
    }
    toast(true, `Created ${name}`);
  }

  async function deleteTab(name) {
    name = safeFileName(name);
    if (!name) return;
    if (name === options.firstTabName)
      return toast(false, `Cannot delete ${options.firstTabName}.`);

    state.tabs = state.tabs.filter((tab) => tab.name !== name);
    await storage.deleteOnApi(name);
    ensureMainTab();
    if (state.activeName === name || !getTab(state.activeName)) {
      state.activeName = state.tabs[0].name;
      applyEditorValue(getTab().content);
    }
    renderTabs();
    persistLocal();
    toast(true, `Deleted ${name}`);
  }

  async function saveTab(name = state.activeName) {
    const tab = getTab(name);
    if (!tab) return;
    if (name === state.activeName) syncActiveFromEditor();
    persistLocal();
    await storage.saveToApi(tab);
  }

  async function loadTabs(first = true) {
    const apiState = await storage.loadFromApi().catch((error) => {
      console.warn("Tab API unavailable, using localStorage:", error);
      return null;
    });
    const localState = storage.localRead();
    const loaded = apiState || localState || null;

    state.tabs =
      loaded?.tabs
        ?.map((tab) => ({
          name: safeFileName(tab.name),
          content: String(tab.content || ""),
          updatedAt: tab.updatedAt || Date.now(),
        }))
        .filter((tab) => tab.name) || [];
    state.activeName = safeFileName(loaded?.activeName) || options.firstTabName;
    ensureMainTab();
    renderTabs();
    persistLocal();

    if (first) applyEditorValue(getTab(state.activeName)?.content || "");
  }

  editor.onDidChangeModelContent(() => {
    scheduleSave();
    const value = editor.getValue();
    if (window.chrome?.webview?.postMessage) {
      try {
        window.chrome.webview.postMessage(value);
      } catch {}
    }
  });

  window.addEventListener("beforeunload", () => {
    syncActiveFromEditor();
    persistLocal();
  });

  document
    .getElementById(options.addButtonId)
    ?.addEventListener("click", () => {
      const modalEl = document.getElementById(options.modalId);
      if (modalEl && window.bootstrap)
        new window.bootstrap.Modal(modalEl, { keyboard: false }).show();
      else {
        const name = prompt("Tab name");
        if (name) addTab(name);
      }
    });

  // Legacy WebView aliases.
  window.addtab = () => addTab();
  window.opentab = openTab;
  window.deltab = deleteTab;
  window.savetab = saveTab;
  window.loadtab = loadTabs;
  window.LuauTabs = { state, addTab, openTab, deleteTab, saveTab, loadTabs };

  const intellisense = installDynamicIntellisense(monaco, editor);
  window.LuauDynamicIntellisense = intellisense;

  loadTabs(true);
  return { state, addTab, openTab, deleteTab, saveTab, loadTabs, intellisense };
}
