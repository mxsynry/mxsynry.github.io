import { access, cp, mkdir, rm, writeFile } from "node:fs/promises";
import { execFile } from "node:child_process";
import path from "node:path";
import { promisify } from "node:util";
import {
  repositoryRoot,
  repositoryFiles,
  readRepositoryFile,
} from "./repository.mjs";
import { generateIndexes } from "./generate-indexes.mjs";

const exec = promisify(execFile);
const appRoot = path.join(repositoryRoot, "Others/Synchrose");
const outputRoot = path.join(repositoryRoot, "pages-dist");
const npm = process.platform === "win32" ? "npm.cmd" : "npm";

try {
  await access(path.join(appRoot, "node_modules/.package-lock.json"));
} catch {
  await exec(npm, ["ci"], { cwd: appRoot, maxBuffer: 10 * 1024 * 1024 });
}
await exec(npm, ["run", "build"], {
  cwd: appRoot,
  maxBuffer: 10 * 1024 * 1024,
});
await generateIndexes();
await rm(outputRoot, { recursive: true, force: true });
await mkdir(outputRoot, { recursive: true });

for (const file of await repositoryFiles()) {
  if (file.path.startsWith("Others/Synchrose/")) continue;
  const destination = path.join(outputRoot, file.path);
  await mkdir(path.dirname(destination), { recursive: true });
  await writeFile(destination, await readRepositoryFile(file));
}
await cp(
  path.join(appRoot, "dist"),
  path.join(outputRoot, "Others/Synchrose"),
  { recursive: true },
);
await writeFile(path.join(outputRoot, ".nojekyll"), "");
console.log(`Site built in ${outputRoot}`);
