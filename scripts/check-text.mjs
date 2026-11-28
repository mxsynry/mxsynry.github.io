import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { repositoryRoot } from "./repository.mjs";

const exec = promisify(execFile);
const sourceExtensions = new Set([
  ".js",
  ".mjs",
  ".cjs",
  ".ts",
  ".svelte",
  ".html",
  ".css",
  ".scss",
  ".json",
  ".jsonc",
  ".yml",
  ".yaml",
  ".md",
  ".lua",
  ".luau",
  ".txt",
]);

export function isMaintainedText(file) {
  return (
    sourceExtensions.has(path.posix.extname(file)) &&
    !file.startsWith("Others/Editor/vs/") &&
    !file.startsWith("Others/Editor/min/") &&
    !file.startsWith("Others/Synchrose/assets/") &&
    !file.startsWith("Others/Synchrose/src/public/catalog/") &&
    !file.startsWith("Others/Synchrose/catalog/") &&
    !file.endsWith("/sources/__fixtures__/har-catalogs.json") &&
    file !== "tree.json"
  );
}

export function findTextIssues(text) {
  const issues = [];
  for (const [index, rawLine] of text.split("\n").entries()) {
    // Decode Unicode escapes without changing source line numbers.
    const line = rawLine.replace(
      /\\u(?:\{([\da-f]{1,6})\}|([\da-f]{4}))/gi,
      (escape, braced, fixed) => {
        const point = Number.parseInt(braced || fixed, 16);
        return point > 127 && point <= 0x10ffff
          ? String.fromCodePoint(point)
          : escape;
      },
    );
    const seen = new Set();
    for (const character of line) {
      let reason;
      if (/\p{Cf}/u.test(character)) reason = "invisible formatting character";
      else if (/\p{Co}/u.test(character)) reason = "private-use glyph";
      else if (
        /\p{Letter}/u.test(character) &&
        !/\p{Script=Latin}/u.test(character)
      )
        reason = "unexpected non-Latin text";
      if (!reason) continue;
      const point = `U+${character.codePointAt(0).toString(16).toUpperCase().padStart(4, "0")}`;
      if (seen.has(reason + point)) continue;
      seen.add(reason + point);
      issues.push({ line: index + 1, reason, point });
    }
    if (/\p{Mark}{2,}/u.test(line))
      issues.push({ line: index + 1, reason: "stacked combining marks" });
  }
  return issues;
}

async function checkRepositoryText() {
  const { stdout } = await exec("git", ["ls-files", "--stage", "-z"], {
    cwd: repositoryRoot,
  });
  let checked = 0;
  let failures = 0;
  for (const entry of stdout.split("\0").filter(Boolean)) {
    const tab = entry.indexOf("\t");
    const [mode, objectId, stage] = entry.slice(0, tab).split(" ");
    const file = entry.slice(tab + 1);
    if (!mode.startsWith("100") || stage !== "0" || !isMaintainedText(file))
      continue;
    let text;
    try {
      text = await readFile(path.join(repositoryRoot, file), "utf8");
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      text = (
        await exec("git", ["cat-file", "blob", objectId], {
          cwd: repositoryRoot,
          maxBuffer: 8 * 1024 * 1024,
        })
      ).stdout;
    }
    checked += 1;
    for (const issue of findTextIssues(text)) {
      console.error(
        `${file}:${issue.line}: ${issue.reason}${issue.point ? ` (${issue.point})` : ""}`,
      );
      failures += 1;
    }
  }
  console.log(`Checked ${checked} maintained text files; ${failures} issues.`);
  process.exitCode = Number(failures > 0);
}

if (path.resolve(process.argv[1] || "") === fileURLToPath(import.meta.url)) {
  await checkRepositoryText();
}
