import { test } from "node:test";
import assert from "node:assert/strict";
import { findTextIssues, isMaintainedText } from "../scripts/check-text.mjs";

test("text checks catch hidden controls, private glyphs and decorated words", () => {
  assert.equal(
    findTextIssues("name" + String.fromCodePoint(0x202e)).at(0).reason,
    "invisible formatting character",
  );
  assert.equal(
    findTextIssues("\\u" + "202E").at(0).reason,
    "invisible formatting character",
  );
  assert.equal(
    findTextIssues(String.fromCodePoint(0xe000)).at(0).reason,
    "private-use glyph",
  );
  assert.equal(
    findTextIssues("word" + String.fromCodePoint(0x0336, 0x0350)).at(0).reason,
    "stacked combining marks",
  );
  assert.equal(
    findTextIssues(String.fromCodePoint(0x540c, 0x671f)).at(0).reason,
    "unexpected non-Latin text",
  );
});

test("normal punctuation, currencies, accents and functional icons remain valid", () => {
  assert.deepEqual(
    findTextIssues("Résumé: £5 / €6 / ₫100. ★ 4/5 → details"),
    [],
  );
  assert.equal(isMaintainedText(".github/workflows/pages.yml"), true);
  assert.equal(isMaintainedText("storage/other-stuff/example.luau"), true);
  assert.equal(
    isMaintainedText("Others/Editor/vs/editor/editor.main.nls.ja.js"),
    false,
  );
  assert.equal(
    isMaintainedText("Others/Synchrose/assets/index-example.js"),
    false,
  );
  assert.equal(isMaintainedText("tree.json"), false);
});
