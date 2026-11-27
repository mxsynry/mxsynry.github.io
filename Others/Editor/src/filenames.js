export function safeFileName(name) {
  const cleaned = String(name || "")
    .trim()
    .replace(/[\\/:*?"<>|]/g, "_");
  if (!cleaned) return "";
  return /\.(lua|luau|txt)$/i.test(cleaned) ? cleaned : cleaned + ".lua";
}
