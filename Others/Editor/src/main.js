import { initEditorTabs } from "./tabs.js";
import { analyzeLuau } from "./completions.js";
import { addBuiltins } from "./builtins.js";

const proposals = [];
const host = window;
host.require.config({ paths: { vs: "vs" } });
host.LuauEditorTools = { init: initEditorTabs, analyzeLuau };

host.require(["vs/editor/editor.main"], () => {
  const monaco = host.monaco;
  monaco.editor.defineTheme("net-theme-dark", {
    base: "vs-dark",
    inherit: true,
    colors: { "editor.background": "#040007" },
    rules: [
      { token: "global", foreground: "aa80ff", fontStyle: "bold" },
      { token: "keyword", foreground: "cc99cc", fontStyle: "bold" },
      { token: "comment", foreground: "999999" },
      { token: "number", foreground: "f99157" },
      { token: "string", foreground: "ddccff" },
      { token: "Method", foreground: "ffa1dc" },
    ],
  });

  const editor = monaco.editor.create(document.getElementById("container"), {
    language: "lua",
    theme: "net-theme-dark",
    acceptSuggestionOnEnter: "smart",
    suggestOnTriggerCharacters: true,
    suggestSelection: "recentlyUsed",
    folding: true,
    wordBasedSuggestions: true,
    scrollbar: { verticalHasArrows: true },
    dragAndDrop: true,
    links: true,
    minimap: { enabled: false },
    showFoldingControls: "always",
    smoothScrolling: true,
  });

  monaco.languages.registerCompletionItemProvider("lua", {
    provideCompletionItems(model, position) {
      const word = model.getWordUntilPosition(position);
      const range = new monaco.Range(
        position.lineNumber,
        word.startColumn,
        position.lineNumber,
        word.endColumn,
      );
      return {
        suggestions: proposals.map((proposal) => ({ ...proposal, range })),
      };
    },
  });

  function addCompletion(label, kind, detail, insertText) {
    proposals.push({
      label,
      kind:
        monaco.languages.CompletionItemKind[kind] ??
        monaco.languages.CompletionItemKind.Text,
      detail,
      insertText,
    });
  }

  // Preserve the API used by applications that embed this page in a WebView.
  Object.assign(host, {
    editor,
    editorInstance: editor,
    SetText: (text) => editor.setValue(text),
    GetText: () => {
      const value = editor.getValue();
      return value.startsWith('"') && value.endsWith('"')
        ? value.slice(1, -1)
        : value;
    },
    ShowMinimap: () => editor.updateOptions({ minimap: { enabled: true } }),
    HideMinimap: () => editor.updateOptions({ minimap: { enabled: false } }),
    EnableAutoComplete: () =>
      editor.updateOptions({
        suggestOnTriggerCharacters: true,
        acceptSuggestionOnEnter: "smart",
        wordBasedSuggestions: true,
      }),
    DisableAutoComplete: () =>
      editor.updateOptions({
        suggestOnTriggerCharacters: false,
        acceptSuggestionOnEnter: "off",
        wordBasedSuggestions: false,
      }),
    AddIntellisense: addCompletion,
    Refresh: () => {
      const text = host.GetText();
      editor.setValue("");
      editor.trigger("keyboard", "type", { text });
    },
  });
  editor.getEditorValue = () => JSON.stringify({ value: editor.getValue() });
  host.addEventListener("resize", () => editor.layout());

  const tabs = initEditorTabs({ editor, monaco });
  document
    .getElementById("confirmAddTab")
    .addEventListener("click", () => tabs.addTab());
  addBuiltins(addCompletion);
  loadRemoteCompletions(addCompletion);
});

async function loadRemoteCompletions(addCompletion) {
  try {
    const response = await fetch(
      "https://raw.githubusercontent.com/iDevastate/Oxygen-v2/main/docs.txt",
    );
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const groups = await response.json();
    for (const group of Object.values(groups)) {
      for (const entry of Object.values(group)) {
        if (
          typeof entry.label === "string" &&
          typeof entry.insert === "string"
        ) {
          addCompletion(
            entry.label,
            entry.type,
            entry.description,
            entry.insert,
          );
        }
      }
    }
  } catch (error) {
    console.warn("Extra completion documentation could not be loaded:", error);
  }
}
