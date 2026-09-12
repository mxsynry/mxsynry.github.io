<script lang="ts">
  import type { CatalogFilters } from "../lib/domain";
  interface Props {
    filters: CatalogFilters; features: string[]; resultCount: number; totalCount: number;
    onfilterschange: (filters: CatalogFilters) => void; onreset: () => void;
  }
  let { filters, features, resultCount, totalCount, onfilterschange, onreset }: Props = $props();
  function update<K extends keyof CatalogFilters>(key: K, value: CatalogFilters[K]) {
    onfilterschange({ ...filters, [key]: value });
  }
</script>

<section class="filter-panel" aria-label="Catalog controls">
  <div class="primary-controls">
    <label class="search-control">
      <span class="sr-only">Search executors</span>
      <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.8" cy="10.8" r="6.7"></circle><path d="m16 16 4.2 4.2"></path></svg>
      <input type="search" value={filters.search} oninput={(event) => update("search", event.currentTarget.value)}
        placeholder="Search executor, platform, or feature" autocomplete="off" />
      <kbd>/</kbd>
    </label>
    <label><span>Platform</span><select value={filters.platform} onchange={(event) => update("platform", event.currentTarget.value as CatalogFilters["platform"])}>
      <option value="all">All platforms</option><option value="windows">Windows</option><option value="mac">macOS</option>
      <option value="mobile">Mobile</option><option value="android">Android</option><option value="ios">iOS</option>
    </select></label>
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
    <p><strong>{resultCount}</strong> of {totalCount} executors</p>
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
        <label><span>Feature</span><select value={filters.feature} onchange={(event) => update("feature", event.currentTarget.value)}>
          <option value="all">Any feature</option>{#each features as feature}<option value={feature}>{feature}</option>{/each}
        </select></label>
        <label><span>Sort</span><select value={filters.sort} onchange={(event) => update("sort", event.currentTarget.value as CatalogFilters["sort"])}>
          <option value="status">Status</option><option value="sources">Source coverage</option><option value="sunc">sUNC</option><option value="name">Name</option>
        </select></label>
      </div></details>
      <button class="reset-button" type="button" onclick={onreset}>Reset</button>
    </div>
  </div>
</section>
