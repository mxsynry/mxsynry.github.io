import { copyFile, cp, mkdir, readdir, unlink } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const distRoot = join(projectRoot, "dist");
const rootAssets = join(projectRoot, "assets");

await mkdir(rootAssets, { recursive: true });

for (const filename of await readdir(rootAssets)) {
  if (/^index-[A-Za-z0-9_-]+\.(?:css|js)(?:\.map)?$/.test(filename)) {
    await unlink(join(rootAssets, filename));
  }
}

await cp(join(distRoot, "assets"), rootAssets, { recursive: true, force: true });
await copyFile(join(distRoot, "index.html"), join(projectRoot, "index.html"));

console.log("Synced the production build to index.html and assets/ for static hosting.");
