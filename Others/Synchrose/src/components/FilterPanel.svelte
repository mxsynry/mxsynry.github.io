<script lang="ts">
  import type { CatalogFilters } from "../lib/domain";
  import { FEATURE_OPTIONS } from "../lib/features";
  interface Props {
    filters: CatalogFilters; resultCount: number; totalCount: number;
    onfilterschange: (filters: CatalogFilters) => void; onreset: () => void;
  }
  let { filters, resultCount, totalCount, onfilterschange, onreset }: Props = $props();
  function update<K extends keyof CatalogFilters>(key: K, value: CatalogFilters[K]) {
    onfilterschange({ ...filters, [key]: value });
  }
</script>

<section class="filter-panel" aria-label="Catalog controls">
  <div class="primary-controls">
    <label class="search-control">
      <span class="sr-only">Search exploits</span>
      <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.8" cy="10.8" r="6.7"></circle><path d="m16 16 4.2 4.2"></path></svg>
      <input type="search" value={filters.search} oninput={(event) => update("search", event.currentTarget.value)}
        placeholder="Search exploit, platform, or feature" autocomplete="off" />
      <kbd>/</kbd>
    </label>
    <fieldset class="filter-checks"><legend>Platforms · any selected</legend>
      {#each ["windows", "mac", "android", "ios"] as platform}
        <label><input type="checkbox" checked={filters.platforms?.includes(platform as "windows")} onchange={(event) => update("platforms", (event.currentTarget.checked ? [...(filters.platforms || []), platform] : (filters.platforms || []).filter(p => p !== platform)) as CatalogFilters["platforms"])} />{platform === "mac" ? "macOS" : platform === "ios" ? "iOS" : platform[0].toUpperCase() + platform.slice(1)}</label>
      {/each}
    </fieldset>
    <label><span>Status</span><select value={filters.working} onchange={(event) => update("working", event.currentTarget.value as CatalogFilters["working"])}>
      <option value="all">Every status</option><option value="working">Working</option><option value="mixed">Mixed reports</option>
      <option value="broken">Outdated</option><option value="unknown">Unknown</option>
    </select></label>
    <label><span>Source</span><select value={filters.source} onchange={(event) => update("source", event.currentTarget.value as CatalogFilters["source"])}>
      <option value="all">All sources</option><option value="multi">Cross-checked</option><option value="weao">WEAO</option>
      <option value="voxlis">Voxlis</option><option value="pulsery">Pulsery</option><option value="inject">Inject</option>
    </select></label>
  </div>
  <div class="control-footer">
    <p><strong>{resultCount}</strong> of {totalCount} exploits</p>
    <div class="control-actions">
      <details class="advanced-filters"><summary>More filters</summary><div class="advanced-grid">
        <label><span>Detection</span><select value={filters.detection} onchange={(event) => update("detection", event.currentTarget.value as CatalogFilters["detection"])}>
          <option value="all">Any detection report</option><option value="undetected">Undetected</option>
          <option value="client-mod-only">Client-mod bypass</option><option value="detected">Detected</option>
          <option value="mixed">Mixed reports</option><option value="unknown">Unknown</option>
        </select></label>
        <label><span>Price</span><select value={filters.price} onchange={(event) => update("price", event.currentTarget.value as CatalogFilters["price"])}>
          <option value="all">Free and paid</option><option value="free">Free</option><option value="paid">Paid</option>
        </select></label>
        <fieldset class="filter-checks"><legend>Features · all selected</legend>
          {#each FEATURE_OPTIONS.filter(f => !["Key system", "Keyless"].includes(f)) as feature}<label><input type="checkbox" checked={filters.tags?.includes(feature)} onchange={(event) => update("tags", event.currentTarget.checked ? [...(filters.tags || []), feature] : (filters.tags || []).filter(f => f !== feature))} />{feature}</label>{/each}
        </fieldset>
        <fieldset class="filter-checks"><legend>Show only</legend>
          {#each ["verified", "trending", "warning"] as flag}<label><input type="checkbox" checked={Boolean(filters[flag as "verified"])} onchange={(event) => update(flag as "verified", event.currentTarget.checked)} />{flag[0].toUpperCase() + flag.slice(1)}</label>{/each}
        </fieldset>
        <fieldset class="filter-checks"><legend>Visibility</legend>
          <label><input type="checkbox" checked={filters.showInsecure !== false} onchange={(event) => update("showInsecure", event.currentTarget.checked)} />Include insecure</label>
          <label><input type="checkbox" checked={filters.showInviteOnly !== false} onchange={(event) => update("showInviteOnly", event.currentTarget.checked)} />Include invite-only</label>
        </fieldset>
        <label><span>Price value</span><select value={filters.valueRating || "all"} onchange={(event) => update("valueRating", event.currentTarget.value)}><option value="all">Any value</option><option value="good">Good</option><option value="fair">Fair</option><option value="expensive">Expensive</option><option value="unknown">Unknown</option></select><small>Legacy price heuristic; no currency conversion.</small></label>
        <label><span>Type</span><select value={filters.type} onchange={(event) => update("type", event.currentTarget.value)}>
          <option value="all">All types</option>{#each ["Internal", "External", "Aimbot", "Server-side", "Kernel", "Unknown"] as type}<option value={type}>{type}</option>{/each}
        </select></label>
        <label><span>Key system</span><select value={filters.key} onchange={(event) => update("key", event.currentTarget.value as CatalogFilters["key"])}>
          <option value="all">Any key setup</option><option value="keyless">Keyless</option><option value="keysystem">Key system</option>
        </select></label>
        <label><span>sUNC</span><select value={filters.sunc} onchange={(event) => update("sunc", event.currentTarget.value as CatalogFilters["sunc"])}>
          <option value="all">Any sUNC</option><option value="100">100%</option><option value="80">80%+</option><option value="50">50%+</option><option value="measured">Measured</option><option value="unknown">Unknown</option>
        </select></label>
        <label><span>Sort</span><select value={filters.sort} onchange={(event) => update("sort", event.currentTarget.value as CatalogFilters["sort"])}>
          <option value="status">Status</option><option value="sources">Source coverage</option><option value="sunc">sUNC</option><option value="name">Name</option>
          <option value="popular">Popularity (trending / review count)</option><option value="random">Random</option><option value="price">Price low to high</option><option value="value">Best value</option>
        </select></label>
      </div></details>
      <button class="reset-button" type="button" onclick={onreset}>Reset</button>
    </div>
  </div>
</section>
