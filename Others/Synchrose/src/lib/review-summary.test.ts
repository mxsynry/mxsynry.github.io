import { it, expect } from "vitest";
import { summarizeReviews } from "./review-summary";
it("summarizes loaded reviews rather than stale catalog counts", () => {
  expect(summarizeReviews([{rating:4},{rating:5},{rating:null}])).toEqual({count:3,rated:2,average:4.5});
});
it("preserves genuine zero ratings and excludes missing or invalid ratings", () => {
  expect(summarizeReviews([{rating:0},{rating:4},{rating:NaN}])).toEqual({count:3,rated:2,average:2});
  expect(summarizeReviews([])).toEqual({count:0,rated:0,average:null});
});
