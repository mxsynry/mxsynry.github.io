export async function mapLimit(items, limit, mapper) {
  const input = Array.from(items || []);
  let next = 0;

  async function run() {
    while (next < input.length) {
      const index = next++;
      await mapper(input[index], index);
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, input.length) }, run));
}

export function isHttpUrl(value) {
  try {
    const url = new URL(String(value || ""));
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}

export function normalizeApiBase(value) {
  return isHttpUrl(value) ? String(value).trim().replace(/\/$/, "") : "";
}

export function uniqueBy(array, keyFn) {
  const seen = new Set();
  return array.filter((item) => {
    const key = keyFn(item);
    if (key === undefined || key === null || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

export function normalizeName(value) {
  return String(value || "")
    .replace(/\s+/g, " ")
    .trim();
}

export function formatDate(value) {
  if (!value) return "unknown";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "unknown";
  return date.toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export function formatInteger(value) {
  const number = Number(value);
  return Number.isFinite(number)
    ? new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 }).format(
        number,
      )
    : "?";
}

export function finiteOrNull(value) {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 ? number : null;
}

export function integerOrNull(value) {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  return Number.isInteger(number) ? number : null;
}

export function escapeHtml(value) {
  return String(value ?? "").replace(
    /[&<>'"]/g,
    (char) =>
      ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        "'": "&#39;",
        '"': "&quot;",
      })[char],
  );
}

export function escapeAttr(value) {
  return escapeHtml(value).replace(/`/g, "&#96;");
}
