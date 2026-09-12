<script lang="ts">
  import { SOURCE_META, type ExecutorRecord } from "../lib/domain";
  import { DETECTION_LABELS, formatSunc, PLATFORM_LABELS } from "../lib/format";
  import Stars from "./Stars.svelte";
  import StatusBadge from "./StatusBadge.svelte";
  interface Props { view: "table" | "grid"; records: ExecutorRecord[]; loading: boolean; onopen: (id: string) => void; }
  let { view, records, loading, onopen }: Props = $props();
</script>

{#if !records.length && loading}
  <div class="catalog-skeleton" aria-label="Loading executor reports">{#each Array(6) as _}<span></span>{/each}</div>
{:else if !records.length}
  <section class="catalog-empty"><strong>No matching executors</strong><p>Clear one or more filters and try again.</p></section>
{:else}
  <div class="desktop-catalog" class:hide-table={view === "grid"}><table><thead><tr>
    <th>Executor</th><th>Platform</th><th>Status</th><th>Detection</th><th>sUNC</th><th>Price</th><th>Evidence</th><th><span class="sr-only">Open details</span></th>
  </tr></thead><tbody>
    {#each records as record (record.id)}
      <tr class:has-conflict={record.conflicts.length > 0}>
        <td><button class="executor-name" type="button" onclick={() => onopen(record.id)}><strong>{record.name}</strong><span>{record.type || "Unclassified"}</span><Stars rating={record.observations.find((o) => o.source === "pulsery")?.rating ?? null} /></button></td>
        <td>{record.platforms.map((platform) => PLATFORM_LABELS[platform]).join(", ")}</td>
        <td><StatusBadge status={record.working} /></td>
        <td class:mixed-value={record.detection === "mixed"}>{DETECTION_LABELS[record.detection]}</td>
        <td class="numeric">{formatSunc(record.sunc)}</td><td>{record.price || "—"}</td>
        <td><div class="source-tokens" aria-label={`Sources: ${record.sources.join(", ")}`}>
          {#each record.sources as source}<span title={SOURCE_META[source].label}>{SOURCE_META[source].label.slice(0, 1)}</span>{/each}
          {#if record.conflicts.length}<b title={`${record.conflicts.length} conflicting field reports`}>!</b>{/if}
        </div></td>
        <td><button class="open-record" type="button" onclick={() => onopen(record.id)} aria-label={`Open ${record.name}`}>
          <svg viewBox="0 0 20 20" aria-hidden="true"><path d="m7 4 6 6-6 6"></path></svg>
        </button></td>
      </tr>
    {/each}
  </tbody></table></div>
  <div class="mobile-catalog" class:show-grid={view === "grid"}>
    {#each records as record (record.id)}
      <button class="mobile-record" type="button" onclick={() => onopen(record.id)}>
        <span class="mobile-record-head"><span><strong>{record.name}</strong><small>{record.platforms.map((platform) => PLATFORM_LABELS[platform]).join(" · ")}</small></span><StatusBadge status={record.working} /></span>
        <Stars rating={record.observations.find((o) => o.source === "pulsery")?.rating ?? null} />
        <span class="mobile-metrics"><span><small>Detection</small><b>{DETECTION_LABELS[record.detection]}</b></span><span><small>sUNC</small><b>{formatSunc(record.sunc)}</b></span><span><small>Sources</small><b>{record.sources.length}</b></span></span>
        {#if record.conflicts.length}<span class="mobile-conflict">Mixed evidence in {record.conflicts.length} field{record.conflicts.length === 1 ? "" : "s"}</span>{/if}
      </button>
    {/each}
  </div>
{/if}
