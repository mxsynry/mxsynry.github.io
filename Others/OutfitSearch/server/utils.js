export async function mapSettledLimit(items, limit, mapper) {
  const input = Array.from(items || []);
  const results = new Array(input.length);
  let next = 0;

  async function worker() {
    while (next < input.length) {
      const index = next++;
      try {
        results[index] = {
          status: "fulfilled",
          value: await mapper(input[index], index),
        };
      } catch (reason) {
        results[index] = { status: "rejected", reason };
      }
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(limit, input.length) }, worker),
  );
  return results;
}

export function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function thumbnailKind(imageUrl) {
  const m = String(imageUrl || "").match(/\/\d+\/\d+\/([^/]+)\/Png/i);
  return m ? m[1] : null;
}

export function assertId(id, label = "ID") {
  if (!Number.isSafeInteger(id) || id <= 0) {
    const err = new Error(`Invalid ${label}.`);
    err.status = 400;
    throw err;
  }
}

export function unique(arr) {
  return [...new Set(arr.filter(Number.isFinite))];
}

export function uniqueBy(arr, fn) {
  const seen = new Set();
  return arr.filter((x) => {
    const k = fn(x);
    if (k === undefined || k === null || seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

export function mapBy(arr, fn) {
  const out = {};
  for (const item of arr) {
    const key = fn(item);
    if (key !== undefined && key !== null) out[key] = item;
  }
  return out;
}

export function chunks(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

export function duplicateCounts(arr) {
  const counts = new Map();
  for (const id of arr) counts.set(id, (counts.get(id) || 0) + 1);
  return [...counts.entries()]
    .filter(([, count]) => count > 1)
    .map(([id, count]) => ({ id, count }));
}
