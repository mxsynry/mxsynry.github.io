import { it, expect } from "vitest";
import { normalizeFeatures, FEATURE_OPTIONS } from "./features";
import { markdownText } from "./format";
it("collapses the aliases shown in the user's screenshot", () => {
  expect(normalizeFeatures(["Key system", "KeySystem", "Multi Instance", "Multi-instance", "RakNet", "Raknet"])).toEqual(["Key system", "Multi-instance", "RakNet"]);
  expect(new Set(FEATURE_OPTIONS).size).toBe(FEATURE_OPTIONS.length);
});
it("retains Markdown paragraph and list boundaries during import", () => {
  expect(markdownText("**A**\n\n- B\n- C")).toBe("**A**\n\n- B\n- C");
});
