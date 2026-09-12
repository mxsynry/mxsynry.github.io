const DEFAULT_TIMEOUT = 14_000;

export async function fetchJson(url: string, timeout = DEFAULT_TIMEOUT): Promise<unknown> {
  if (!url) throw new Error("This source requires the Synchrose data bridge.");
  const controller = new AbortController();
  const timer = globalThis.setTimeout(() => controller.abort(), timeout);
  try {
    const response = await fetch(url, {
      headers: { accept: "application/json" },
      cache: "no-store",
      signal: controller.signal
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") throw new Error("Request timed out.");
    throw error;
  } finally {
    globalThis.clearTimeout(timer);
  }
}

export async function fetchWithFallback(primary: string, fallback: string): Promise<unknown> {
  try {
    return await fetchJson(primary);
  } catch (primaryError) {
    try {
      return await fetchJson(fallback);
    } catch {
      throw primaryError;
    }
  }
}

export async function mapConcurrent<T, R>(values: T[], limit: number, task: (value: T) => Promise<R>): Promise<R[]> {
  const results = new Array<R>(values.length);
  let cursor = 0;
  async function worker() {
    while (cursor < values.length) {
      const index = cursor++;
      results[index] = await task(values[index]);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, values.length) }, worker));
  return results;
}
