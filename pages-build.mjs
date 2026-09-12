import { access, cp, mkdir, readdir, rm } from "node:fs/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import path from "node:path";

const sourceRoot = process.cwd();
const outputRoot = path.join(sourceRoot, "pages-dist");
const excludedFile = "storage/other-stuff/mods.rar";
const synchroseRoot = path.join(sourceRoot, "Others", "Synchrose");
const execFileAsync = promisify(execFile);

async function ensureSynchroseDependencies() {
  try {
    await access(path.join(synchroseRoot, "node_modules", ".package-lock.json"));
  } catch {
    await execFileAsync(process.platform === "win32" ? "npm.cmd" : "npm", ["ci"], {
      cwd: synchroseRoot,
      maxBuffer: 10 * 1024 * 1024
    });
  }
}

function shouldCopy(source) {
  const relative = path.relative(sourceRoot, source).split(path.sep).join("/");
  if (!relative) return true;

  const parts = relative.split("/");
  const name = parts.at(-1);

  if (parts[0] === "pages-dist") return false;
  if (parts.includes(".git")) return false;
  if (parts.includes("node_modules")) return false;
  if (parts.includes(".wrangler")) return false;
  if (parts.includes("dist")) return false;
  if (relative === excludedFile) return false;
  if (name === ".env" || name.startsWith(".env.") || name.startsWith(".dev.vars")) return false;

  return true;
}

await ensureSynchroseDependencies();
await execFileAsync(process.platform === "win32" ? "npm.cmd" : "npm", ["run", "build"], {
  cwd: synchroseRoot,
  maxBuffer: 10 * 1024 * 1024
});

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

const deployedSynchroseRoot = path.join(outputRoot, "Others", "Synchrose");
await rm(deployedSynchroseRoot, { recursive: true, force: true });
await cp(path.join(synchroseRoot, "dist"), deployedSynchroseRoot, { recursive: true });

console.log(`Cloudflare Pages output created at ${outputRoot}`);
