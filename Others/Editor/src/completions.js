function stripCommentsAndStrings(code) {
  return String(code || "")
    .replace(/--\[\[[\s\S]*?\]\]/g, " ")
    .replace(/--[^\n]*/g, " ")
    .replace(/\[\[[\s\S]*?\]\]/g, " ")
    .replace(/"(?:\\.|[^"\\])*"/g, '""')
    .replace(/'(?:\\.|[^'\\])*'/g, "''");
}

function addName(map, name, kind, detail) {
  if (
    !name ||
    /^(and|break|do|else|elseif|end|false|for|function|if|in|local|nil|not|or|repeat|return|then|true|until|while)$/i.test(
      name,
    )
  )
    return;
  if (!/^[A-Za-z_]\w*$/.test(name)) return;
  if (!map.has(name)) map.set(name, { name, kind, detail });
}

function splitIdentifiers(list) {
  return String(list || "")
    .split(",")
    .map((part) => part.trim())
    .filter((part) => /^[A-Za-z_]\w*$/.test(part));
}

function collectTableFields(text, objectName, body, fields) {
  if (!fields.has(objectName)) fields.set(objectName, new Map());
  const fieldMap = fields.get(objectName);
  const addField = (field, kind = "Field") => {
    if (!field || !/^[A-Za-z_]\w*$/.test(field)) return;
    if (!fieldMap.has(field))
      fieldMap.set(field, {
        name: field,
        kind,
        detail: `${objectName}.${field}`,
      });
  };

  let match;
  const namedField = /(?:^|[,\n;])\s*([A-Za-z_]\w*)\s*=/g;
  while ((match = namedField.exec(body))) addField(match[1]);

  const quotedField = /\[\s*["']([A-Za-z_]\w*)["']\s*\]\s*=/g;
  while ((match = quotedField.exec(body))) addField(match[1]);

  const methodField = /(?:^|[,\n;])\s*([A-Za-z_]\w*)\s*=\s*function\b/g;
  while ((match = methodField.exec(body))) addField(match[1], "Method");
}

export function analyzeLuau(code) {
  const cleaned = stripCommentsAndStrings(code);
  const variables = new Map();
  const fields = new Map();
  let match;

  const localVars =
    /\blocal\s+(?!function\b)([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*(?==|\n|$)/g;
  while ((match = localVars.exec(cleaned))) {
    for (const name of splitIdentifiers(match[1]))
      addName(variables, name, "Variable", "local variable");
  }

  const localFunctions = /\blocal\s+function\s+([A-Za-z_]\w*)\s*\(([^)]*)\)/g;
  while ((match = localFunctions.exec(cleaned))) {
    addName(variables, match[1], "Function", "local function");
    for (const param of splitIdentifiers(match[2]))
      addName(variables, param, "Variable", "function parameter");
  }

  const functions =
    /\bfunction\s+([A-Za-z_]\w*)(?:([.:])([A-Za-z_]\w*))?\s*\(([^)]*)\)/g;
  while ((match = functions.exec(cleaned))) {
    if (match[3]) {
      const obj = match[1];
      addName(variables, obj, "Variable", "table/object");
      if (!fields.has(obj)) fields.set(obj, new Map());
      fields.get(obj).set(match[3], {
        name: match[3],
        kind: match[2] === ":" ? "Method" : "Function",
        detail: `${obj}${match[2]}${match[3]}`,
      });
    } else {
      addName(variables, match[1], "Function", "function");
    }
    for (const param of splitIdentifiers(match[4]))
      addName(variables, param, "Variable", "function parameter");
  }

  const genericFor = /\bfor\s+([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s+in\b/g;
  while ((match = genericFor.exec(cleaned))) {
    for (const name of splitIdentifiers(match[1]))
      addName(variables, name, "Variable", "for-loop variable");
  }

  const numericFor = /\bfor\s+([A-Za-z_]\w*)\s*=/g;
  while ((match = numericFor.exec(cleaned)))
    addName(variables, match[1], "Variable", "numeric for-loop variable");

  const globals = /^\s*([A-Za-z_]\w*)\s*=/gm;
  while ((match = globals.exec(cleaned)))
    addName(variables, match[1], "Variable", "script variable");

  const tableDecl = /\b(?:local\s+)?([A-Za-z_]\w*)\s*=\s*\{([\s\S]*?)\}/g;
  while ((match = tableDecl.exec(cleaned))) {
    addName(variables, match[1], "Variable", "table");
    collectTableFields(cleaned, match[1], match[2], fields);
  }

  const dottedAssignment = /\b([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*=/g;
  while ((match = dottedAssignment.exec(cleaned))) {
    addName(variables, match[1], "Variable", "table/object");
    if (!fields.has(match[1])) fields.set(match[1], new Map());
    fields.get(match[1]).set(match[2], {
      name: match[2],
      kind: "Field",
      detail: `${match[1]}.${match[2]}`,
    });
  }

  return { variables, fields };
}

function completionKind(monaco, kind) {
  const K = monaco.languages.CompletionItemKind;
  return K[kind] || K.Variable;
}

function getReplaceRange(monaco, model, position) {
  const word = model.getWordUntilPosition(position);
  return new monaco.Range(
    position.lineNumber,
    word.startColumn,
    position.lineNumber,
    word.endColumn,
  );
}

export function installDynamicIntellisense(monaco, editor) {
  let analysis = analyzeLuau(editor.getValue());
  let timer = null;

  const refresh = () => {
    clearTimeout(timer);
    timer = setTimeout(() => {
      analysis = analyzeLuau(editor.getValue());
    }, 120);
  };

  const changeListener = editor.onDidChangeModelContent(refresh);
  refresh();

  const provider = {
    triggerCharacters: [".", ":"],
    provideCompletionItems(model, position) {
      analysis = analyzeLuau(model.getValue());
      const range = getReplaceRange(monaco, model, position);
      const line = model.getValueInRange({
        startLineNumber: position.lineNumber,
        startColumn: 1,
        endLineNumber: position.lineNumber,
        endColumn: position.column,
      });

      const memberMatch = line.match(/([A-Za-z_]\w*)\s*([.:])\s*[A-Za-z_]*$/);
      if (memberMatch) {
        const objectName = memberMatch[1];
        const objectFields = analysis.fields.get(objectName);
        if (!objectFields) return { suggestions: [] };
        return {
          suggestions: [...objectFields.values()].map((field) => ({
            label: field.name,
            kind: completionKind(monaco, field.kind),
            detail: field.detail || "detected table field",
            insertText: field.name,
            range,
          })),
        };
      }

      return {
        suggestions: [...analysis.variables.values()].map((variable) => ({
          label: variable.name,
          kind: completionKind(monaco, variable.kind),
          detail: variable.detail || "detected variable",
          insertText: variable.name,
          range,
        })),
      };
    },
  };

  const disposables = [
    changeListener,
    monaco.languages.registerCompletionItemProvider("lua", provider),
  ];

  try {
    monaco.languages.register({ id: "luau" });
    disposables.push(
      monaco.languages.registerCompletionItemProvider("luau", provider),
    );
  } catch {}

  return {
    refresh: () => {
      analysis = analyzeLuau(editor.getValue());
    },
    dispose: () => {
      clearTimeout(timer);
      disposables.forEach((item) => item.dispose());
    },
  };
}
