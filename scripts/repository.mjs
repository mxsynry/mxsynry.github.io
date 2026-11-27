import { execFile } from "node:child_process";
import { lstat, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

export const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const exec = promisify(execFile);
const ignoredDirectories = new Set([
  ".git",
  ".github",
  "node_modules",
  ".wrangler",
  "pages-dist",
  "dist",
]);

export function isPublicFile(relativePath) {
  const parts = relativePath.split("/");
  const name = parts.at(-1);
  return (
    !parts.some((part) => ignoredDirectories.has(part)) &&
    name !== ".DS_Store" &&
    name !== "Thumbs.db" &&
    !/^\.env(\.|$)/.test(name) &&
    !name.startsWith(".dev.vars") &&
    !relativePath.startsWith("Others/Editor/fileaccess/SolaraTab/") &&
    relativePath !== "storage/other-stuff/mods.rar"
  );
}

// Read Git's index so local dependencies, ignored files and untracked secrets
// cannot enter the published site. Sparse checkouts can read missing blobs.
export async function repositoryFiles(root = repositoryRoot) {
  const [{ stdout: staged }, { stdout: flags }] = await Promise.all([
    exec("git", ["ls-files", "--stage", "-z"], {
      cwd: root,
      maxBuffer: 8 * 1024 * 1024,
    }),
    exec("git", ["ls-files", "-v", "-z"], {
      cwd: root,
      maxBuffer: 8 * 1024 * 1024,
    }),
  ]);
  const sparsePaths = new Set(
    flags
      .split("\0")
      .filter((line) => line.startsWith("S "))
      .map((line) => line.slice(2)),
  );
  const files = [];
  for (const line of staged.split("\0").filter(Boolean)) {
    const [metadata, relativePath] = line.split("\t");
    const [mode, objectId, stage] = metadata.split(" ");
    if (stage !== "0" || !mode.startsWith("100") || !isPublicFile(relativePath))
      continue;
    const absolutePath = path.join(root, relativePath);
    try {
      const stat = await lstat(absolutePath);
      if (stat.isFile())
        files.push({
          path: relativePath,
          size: stat.size,
          absolutePath,
          objectId,
        });
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      if (sparsePaths.has(relativePath)) {
        const { stdout } = await exec("git", ["cat-file", "-s", objectId], {
          cwd: root,
        });
        files.push({
          path: relativePath,
          size: Number(stdout),
          absolutePath: null,
          objectId,
        });
      }
    }
  }
  return files.sort((a, b) => a.path.localeCompare(b.path, "en"));
}

export async function readRepositoryFile(file, root = repositoryRoot) {
  if (file.absolutePath) return readFile(file.absolutePath);
  const { stdout } = await exec("git", ["cat-file", "blob", file.objectId], {
    cwd: root,
    encoding: "buffer",
    maxBuffer: Math.max(file.size * 2, 1024 * 1024),
  });
  return stdout;
}

export function encodePath(value) {
  return value.split("/").map(encodeURIComponent).join("/");
}
