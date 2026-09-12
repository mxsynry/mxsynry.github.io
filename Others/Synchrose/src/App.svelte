<script lang="ts">
  import { onMount } from "svelte";
  import Versions from "./components/Versions.svelte";
  import ComparePanel from "./components/ComparePanel.svelte";
  import CatalogTable from "./components/CatalogTable.svelte";
  import EvidenceDrawer from "./components/EvidenceDrawer.svelte";
  import FilterPanel from "./components/FilterPanel.svelte";
  import SourceStrip from "./components/SourceStrip.svelte";
  import { filterCatalog, initialUpdate, readSnapshot, refreshCatalog } from "./lib/catalog";
  import { resolveApiBase } from "./lib/config";
  import type { CatalogFilters } from "./lib/domain";
  import { formatTime } from "./lib/format";

  function defaultFilters(): CatalogFilters {
    return { search: "", platform: "all", working: "all", detection: "all", price: "all", source: "all", feature: "all", type: "all", key: "all", sunc: "all", sort: "status" };
  }

  const apiBase = resolveApiBase();
  let catalog = $state(initialUpdate(readSnapshot()));
  let filters = $state<CatalogFilters>(defaultFilters());
  let view = $state<"table" | "grid">("table");
  let comparison = $state<string[]>([]);
  let selectedId = $state<string | null>(null);
  let filtered = $derived(filterCatalog(catalog.records, filters));
  let selected = $derived(catalog.records.find((record) => record.id === selectedId) ?? null);
  let latestFetch = $derived(Object.values(catalog.health).map((item) => item.fetchedAt).filter(Boolean).sort().at(-1) ?? null);
  let liveSources = $derived(Object.values(catalog.health).filter((item) => item.state === "live").length);

  async function refresh() {
    catalog = await refreshCatalog(apiBase, catalog, (update) => { catalog = update; });
  }

  function focusSearch() {
    document.querySelector<HTMLInputElement>('.search-control input')?.focus();
  }

  onMount(() => {
    void refresh();
    const onKeydown = (event: KeyboardEvent) => {
      if (event.key === "/" && !event.metaKey && !event.ctrlKey && !event.altKey && !(event.target instanceof HTMLInputElement) && !(event.target instanceof HTMLTextAreaElement)) {
        event.preventDefault();
        focusSearch();
      }
    };
    window.addEventListener("keydown", onKeydown);
    return () => window.removeEventListener("keydown", onKeydown);
  });
</script>

<svelte:head><meta name="color-scheme" content="dark" /></svelte:head>

<header class="site-header">
  <a class="brand" href="./" aria-label="Synchrose home">
    <svg viewBox="0 0 36 36" aria-hidden="true"><path d="M7 9h17l5 5v13H12l-5-5V9Z"></path><path d="M12 15h12M12 21h8"></path></svg>
    <span><strong>SYNCHROSE</strong><small>同期 / STATUS INDEX</small></span>
  </a>
  <div class="header-actions">
    <span class="sync-state"><i class:partial={liveSources < 4}></i>{liveSources}/4 sources live</span>
    <button class="refresh-button" class:spinning={catalog.pending > 0} type="button" onclick={refresh} disabled={catalog.pending > 0}>
      <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M16.2 7.3A6.5 6.5 0 1 0 16 13"></path><path d="M16 3v4.5h-4.5"></path></svg>
      <span>{catalog.pending > 0 ? "Syncing" : "Refresh"}</span>
    </button>
  </div>
</header>

<main>
  <section class="index-intro">
    <div>
      <p class="eyebrow">Public executor intelligence / 04 feeds</p>
      <h1>Executor status index</h1>
    </div>
    <p>Reports remain attached to their source. Conflicts are shown instead of silently resolved.</p>
  </section>

  <SourceStrip health={catalog.health} />
  <Versions />
  <div class="workspace">
    <FilterPanel {filters} resultCount={filtered.length} totalCount={catalog.records.length}
      onfilterschange={(next) => { filters = next; }} onreset={() => { filters = defaultFilters(); }} />
    <section class="catalog-section" aria-labelledby="catalog-title">
      <header class="catalog-header">
        <div><p class="eyebrow">Current catalog</p><h2 id="catalog-title">Status reports</h2></div>
        <p>Last evidence pull <time>{formatTime(latestFetch)}</time></p>
      </header>
      <div class="view-controls" aria-label="Catalog view">
        <button type="button" aria-pressed={view === "table"} onclick={() => { view = "table"; }}>List</button>
        <button type="button" aria-pressed={view === "grid"} onclick={() => { view = "grid"; }}>Grid</button>
      </div>
      <ComparePanel records={catalog.records} selected={comparison} onchange={(ids) => { comparison = ids; }} />
      <CatalogTable {view} records={filtered} loading={catalog.pending > 0 && catalog.records.length === 0} onopen={(id) => { selectedId = id; }} />
    </section>
  </div>
</main>

<footer class="site-footer">
  <p><strong>Synchrose</strong> indexes third-party public claims. A “working” report is not a safety guarantee.</p>
  <p>WEAO · Voxlis · Pulsery · Inject</p>
</footer>

{#if selected}<EvidenceDrawer {apiBase} record={selected} ondismiss={() => { selectedId = null; }} />{/if}
