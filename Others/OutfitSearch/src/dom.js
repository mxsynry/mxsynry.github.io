export const $ = (selector, root = document) => root.querySelector(selector);

export function chip(text, kind = "") {
  const el = document.createElement("span");
  el.className = `chip ${kind}`.trim();
  el.textContent = text;
  return el;
}

export function downloadJson(name, data) {
  const blob = new Blob([JSON.stringify(data, null, 2)], {
    type: "application/json",
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = name;
  link.click();
  URL.revokeObjectURL(url);
}

export function openDialog(dialog) {
  if (!dialog) return;
  if (typeof dialog.showModal === "function") dialog.showModal();
  else dialog.setAttribute("open", "");
}
