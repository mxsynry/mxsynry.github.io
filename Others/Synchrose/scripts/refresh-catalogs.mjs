import { mkdir, readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { fetchVoxlisCatalog, fetchBypassCatalog } from "../worker.js";

const directory = fileURLToPath(
  new URL("../src/public/catalog/", import.meta.url),
);
await mkdir(directory, { recursive: true });

for (const [source, fetchCatalog] of Object.entries({
  voxlis: fetchVoxlisCatalog,
  bypass: fetchBypassCatalog,
})) {
  const destination = path.join(directory, `${source}.json`);
  try {
    const payload = await fetchCatalog();
    const snapshot = { source, fetchedAt: new Date().toISOString() };
    await writeFile(
      destination,
      `${JSON.stringify({ ...payload, snapshot }, null, 2)}\n`,
    );
    console.log(`Saved current ${source} catalog for static hosting.`);
  } catch (error) {
    // Keep the last successful snapshot.
    const previous = JSON.parse(await readFile(destination, "utf8"));
    if (previous.snapshot?.source !== source) throw error;
    console.warn(
      `Kept the ${source} snapshot from ${previous.snapshot.fetchedAt}: ${error.message}`,
    );
  }
}
