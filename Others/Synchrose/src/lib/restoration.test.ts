import { describe, expect, it, vi, afterEach } from "vitest";
import { fetchPulsery } from "./sources/pulsery";
import { filterCatalog } from "./catalog";
import { mergeSourceResults } from "./consensus";
import { normalizeDetection } from "./format";
import type { CatalogFilters } from "./domain";
const filters: CatalogFilters = { search:"",platform:"all",working:"all",detection:"all",price:"all",source:"all",feature:"all",sort:"status",type:"all",key:"all",sunc:"all" };
afterEach(() => vi.unstubAllGlobals());
describe("restored catalog data", () => {
  it("keeps the Pulsery ID, rating and score fields through the adapter and merge", async () => {
    vi.stubGlobal("window", { setTimeout, clearTimeout });
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(JSON.stringify({executors:[{id:"executor-42",name:"Example",is_working:true,rating:4.25,review_count:12,stability_score:95,myriad_score:87,sunc_percent:"82",platforms:["Windows"],type:"External"}]}))));
    const result = await fetchPulsery("https://example.test");
    const record = mergeSourceResults({pulsery:result})[0];
    expect(record.observations[0]).toMatchObject({sourceId:"executor-42",rating:4.25,reviewCount:12,stability:95,myriad:87});
    expect(filterCatalog([record], {...filters,sunc:"80"})).toHaveLength(1);
    expect(filterCatalog([record], {...filters,sunc:"100"})).toHaveLength(0);
    expect(filterCatalog([record], {...filters,key:"keyless"})).toHaveLength(0);
    expect(filterCatalog([record], {...filters,type:"Internal"})).toHaveLength(0);
  });
  it("does not turn an unsafe detection report into an undetected report", () => {
    expect(normalizeDetection("unsafe")).toBe("detected");
    expect(normalizeDetection("undetected")).toBe("undetected");
  });
});
