<script lang="ts">
  import { SOURCE_IDS, SOURCE_META, type SourceHealth, type SourceId } from "../lib/domain";
  import { formatTime } from "../lib/format";
  interface Props { health: Record<SourceId, SourceHealth>; }
  let { health }: Props = $props();
  function stateLabel(source: SourceId): string {
    const item = health[source];
    if (item.state === "live") return `${item.count} live`;
    if (item.state === "cached") return `${item.count} cached`;
    if (item.state === "error") return "unavailable";
    return "connecting";
  }
</script>

<section class="source-strip" aria-label="Data source health">
  {#each SOURCE_IDS as source}
    <a class="source-cell" href={SOURCE_META[source].url} target="_blank" rel="noreferrer"
      title={health[source].message || `${SOURCE_META[source].role}. Last response: ${formatTime(health[source].fetchedAt)}`}>
      <span class="source-indicator" data-state={health[source].state}></span>
      <span class="source-name">{SOURCE_META[source].label}</span>
      <span class="source-state">{stateLabel(source)}</span>
      <span class="source-arrow" aria-hidden="true">↗</span>
    </a>
  {/each}
</section>
