import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import {
  isPublicFile,
  repositoryFiles,
  readRepositoryFile,
} from "../scripts/repository.mjs";
import {
  buildTree,
  pageIndex,
  generateIndexes,
} from "../scripts/generate-indexes.mjs";
import {
  normalizeNode,
  findNode,
  getAllFiles,
  countFiles,
} from "../assets/js/browser/tree.js";

test("publication excludes local data and generated copies at any depth", () => {
  for (const file of [
    ".env",
    "Others/App/.env.production",
    ".dev.vars",
    "node_modules/a.js",
    "Others/App/node_modules/a.js",
    ".wrangler/state",
    "pages-dist/index.html",
    "Others/Synchrose/dist/index.html",
    "assets/.DS_Store",
    "Others/Editor/fileaccess/SolaraTab/main.lua",
    "storage/other-stuff/mods.rar",
  ]) {
    assert.equal(isPublicFile(file), false, file);
  }
  assert.equal(isPublicFile("Others/Editor/vs/editor/editor.main.js"), true);
  assert.equal(isPublicFile("storage/other-stuff/Showcase.mp4"), true);
});

test("file browser can navigate, search and count an indexed nested repository", () => {
  const tree = normalizeNode(
    buildTree(
      [
        { path: "index.html", size: 200 },
        { path: "Others/A folder/hello world.lua", size: 20 },
        { path: "Others/A folder/index.html", size: 300 },
      ],
      { owner: "owner", repo: "site", branch: "main" },
    ),
  );
  assert.equal(countFiles(tree), 3);
  assert.equal(findNode(tree, "Others/A folder").children.length, 2);
  assert.equal(findNode(tree, "missing"), null);
  const match = getAllFiles(tree).find(
    (file) => file.name === "hello world.lua",
  );
  assert.equal(match.fullPath, "Others/A folder/hello world.lua");
  assert.match(match.download_url, /Others\/A%20folder\/hello%20world.lua$/);
});

test("page links distinguish user sites, project sites and source-only entries", () => {
  const files = [
    { path: "index.html" },
    { path: "Others/A folder/index.html" },
    { path: "Others/Synchrose/src/index.html" },
  ];
  assert.match(
    pageIndex(files, { owner: "mxsynry", repo: "mxsynry.github.io" }),
    /https:\/\/mxsynry.github.io\/Others\/A%20folder\//,
  );
  assert.match(
    pageIndex(files, { owner: "someone", repo: "project" }),
    /https:\/\/someone.github.io\/project\//,
  );
  assert.doesNotMatch(
    pageIndex(files, { owner: "someone", repo: "project" }),
    /src\/index/,
  );
});

test("repository inventory reads sparse blobs without publishing untracked files", async (t) => {
  const root = await mkdtemp(path.join(tmpdir(), "site-inventory-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const git = (...args) =>
    execFileSync("git", args, { cwd: root, stdio: "pipe" });
  git("init", "-q");
  await writeFile(path.join(root, "visible.txt"), "visible");
  await writeFile(path.join(root, "sparse.txt"), "stored in Git");
  git("add", "visible.txt", "sparse.txt");
  git("update-index", "--skip-worktree", "sparse.txt");
  await rm(path.join(root, "sparse.txt"));
  await writeFile(path.join(root, "untracked.txt"), "local only");
  const files = await repositoryFiles(root);
  assert.deepEqual(
    files.map((file) => file.path),
    ["sparse.txt", "visible.txt"],
  );
  assert.equal(
    (await readRepositoryFile(files[0], root)).toString(),
    "stored in Git",
  );
  await rm(path.join(root, "visible.txt"));
  assert.deepEqual(
    (await repositoryFiles(root)).map((file) => file.path),
    ["sparse.txt"],
  );
});

test("index generation keeps README sizes current and produces stable output", async (t) => {
  const root = await mkdtemp(path.join(tmpdir(), "site-index-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  execFileSync("git", ["init", "-q"], { cwd: root });
  await writeFile(
    path.join(root, "README.md"),
    "# Résumé\n\nA personal site.\n",
  );
  await writeFile(
    path.join(root, "index.html"),
    "<!doctype html><title>Home</title>",
  );
  execFileSync("git", ["add", "README.md", "index.html"], { cwd: root });
  await generateIndexes(root);
  const first = await readFile(path.join(root, "tree.json"), "utf8");
  const readme = await readFile(path.join(root, "README.md"));
  assert.equal(
    JSON.parse(first).children.find((file) => file.name === "README.md").size,
    readme.length,
  );
  await generateIndexes(root);
  assert.equal(await readFile(path.join(root, "tree.json"), "utf8"), first);
  assert.equal(
    (await readFile(path.join(root, "README.md"))).toString(),
    readme.toString(),
  );
});
