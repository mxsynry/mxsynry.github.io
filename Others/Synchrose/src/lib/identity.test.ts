import { describe, expect, it } from "vitest";
import { normalizeIdentity } from "./identity";

describe("normalizeIdentity", () => {
  it("joins punctuation and casing variants", () => {
    expect(normalizeIdentity("Arceus X NEO")).toBe(normalizeIdentity("arceus-x"));
  });
});
