import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { format } from "prettier";
import { repositoryRoot, repositoryFiles, encodePath } from "./repository.mjs";

export function buildTree(files, { owner, repo, branch }) {
  const root = { name: repo, path: "", type: "dir", children: [] };
  const directories = new Map([["", root]]);
  for (const file of files) {
    if (file.path === "tree.json") continue;
    const parts = file.path.split("/");
    const name = parts.pop();
    let parent = root;
    let directoryPath = "";
    for (const part of parts) {
      directoryPath = directoryPath ? `${directoryPath}/${part}` : part;
      if (!directories.has(directoryPath)) {
        const directory = {
          name: part,
          path: directoryPath,
          type: "dir",
          children: [],
        };
        parent.children.push(directory);
        directories.set(directoryPath, directory);
      }
      parent = directories.get(directoryPath);
    }
    const encoded = encodePath(file.path);
    parent.children.push({
      name,
      path: file.path,
      type: "file",
      size: file.size,
      download_url: `https://raw.githubusercontent.com/${owner}/${repo}/${branch}/${encoded}`,
      html_url: `https://github.com/${owner}/${repo}/blob/${branch}/${encoded}`,
    });
  }
  return root;
}

export function pageIndex(files, { owner, repo }) {
  const base = `https://${owner}.github.io${repo.toLowerCase() === `${owner.toLowerCase()}.github.io` ? "" : `/${repo}`}`;
  const rows = files
    .filter(
      (file) =>
        file.path.endsWith(".html") &&
        !file.path
          .split("/")
          .some((part) => ["src", "vs", "min"].includes(part)),
    )
    .map((file) => {
      const directory = path.posix.dirname(file.path);
      const isIndex = path.posix.basename(file.path) === "index.html";
      const label = isIndex
        ? directory === "."
          ? "Home"
          : directory
        : file.path;
      const urlPath = isIndex
        ? directory === "."
          ? ""
          : `${encodePath(directory)}/`
        : encodePath(file.path);
      return `| [${label}](${base}/${urlPath}) | \`${file.path}\` |`;
    });
  return [
    "<!-- pages-index:start -->",
    "## Pages",
    "",
    "| Page | File |",
    "|---|---|",
    ...rows,
    "<!-- pages-index:end -->",
  ].join("\n");
}

export async function generateIndexes(root = repositoryRoot) {
  const [owner, repo] = (
    process.env.GITHUB_REPOSITORY || "mxsynry/mxsynry.github.io"
  ).split("/");
  const config = { owner, repo, branch: process.env.GITHUB_REF_NAME || "main" };
  const files = await repositoryFiles(root);
  const readmePath = path.join(root, "README.md");
  const readme = await readFile(readmePath, "utf8");
  const section = pageIndex(files, config);
  const marker = /<!-- pages-index:start -->[\s\S]*?<!-- pages-index:end -->/g;
  const nextReadme = marker.test(readme)
    ? readme.replace(marker, section)
    : `${readme.trimEnd()}\n\n${section}\n`;
  const formattedReadme = await format(nextReadme, { filepath: readmePath });
  await writeFile(readmePath, formattedReadme);
  const readmeEntry = files.find((file) => file.path === "README.md");
  if (readmeEntry) readmeEntry.size = Buffer.byteLength(formattedReadme);
  await writeFile(
    path.join(root, "tree.json"),
    `${JSON.stringify(buildTree(files, config), null, 2)}\n`,
  );
}

if (path.resolve(process.argv[1] || "") === fileURLToPath(import.meta.url)) {
  await generateIndexes();
}
