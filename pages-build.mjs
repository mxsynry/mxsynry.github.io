import { cp, mkdir, readdir, rm } from "node:fs/promises";
import path from "node:path";

const sourceRoot = process.cwd();
const outputRoot = path.join(sourceRoot, "pages-dist");
const excludedFile = "storage/other-stuff/mods.rar";

function shouldCopy(source) {
  const relative = path.relative(sourceRoot, source).split(path.sep).join("/");
  if (!relative) return true;

  const parts = relative.split("/");
  const name = parts.at(-1);

  if (parts[0] === "pages-dist") return false;
  if (parts.includes(".git")) return false;
  if (parts.includes("node_modules")) return false;
  if (parts.includes(".wrangler")) return false;
  if (relative === excludedFile) return false;
  if (name === ".env" || name.startsWith(".env.") || name.startsWith(".dev.vars")) return false;

  return true;
}

await rm(outputRoot, { recursive: true, force: true });
await mkdir(outputRoot, { recursive: true });

for (const entry of await readdir(sourceRoot)) {
  const source = path.join(sourceRoot, entry);
  if (!shouldCopy(source)) continue;

  await cp(source, path.join(outputRoot, entry), {
    recursive: true,
    filter: shouldCopy
  });
}

console.log(`Cloudflare Pages output created at ${outputRoot}`);
