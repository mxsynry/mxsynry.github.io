<script lang="ts">
  import type { ExecutorRecord } from "../lib/domain";
  import { STATUS_LABELS, DETECTION_LABELS, formatSunc, PLATFORM_LABELS } from "../lib/format";
  let { records, selected, onchange }: { records: ExecutorRecord[]; selected: string[]; onchange: (ids: string[]) => void } = $props();
  let compared = $derived(selected.map((id) => records.find((r) => r.id === id)).filter((r): r is ExecutorRecord => Boolean(r)));
  const fields: { label: string; value: (r: ExecutorRecord) => string }[] = [
    {label: "Status", value: r => STATUS_LABELS[r.working]}, {label: "Detection", value: r => DETECTION_LABELS[r.detection]},
    {label: "Platforms", value: r => r.platforms.map(p => PLATFORM_LABELS[p]).join(", ")},
    {label: "sUNC", value: r => formatSunc(r.sunc)}, {label: "Price", value: r => r.price || "Unknown"},
    {label: "Version", value: r => r.version || "Unknown"}, {label: "Sources", value: r => r.sources.join(", ")},
    {label: "Features", value: r => r.features.join(", ") || "Unknown"}
  ];
</script>
<details class="compare-panel"><summary>Compare exploits ({selected.length}/4)</summary>
  <label>Add exploit<select disabled={selected.length >= 4} value="" onchange={(event) => { if (event.currentTarget.value) onchange([...selected, event.currentTarget.value]); event.currentTarget.value = ""; }}><option value="">Choose an exploit</option>{#each records.filter(r => !selected.includes(r.id)) as r}<option value={r.id}>{r.name}</option>{/each}</select></label>
  {#if compared.length}<div class="comparison-scroll"><table><thead><tr><th>Field</th>{#each compared as r}<th>{r.name} <button type="button" aria-label={`Remove ${r.name}`} onclick={() => onchange(selected.filter(id => id !== r.id))}>×</button></th>{/each}</tr></thead><tbody>{#each fields as field}<tr><th>{field.label}</th>{#each compared as r}<td>{field.value(r)}</td>{/each}</tr>{/each}</tbody></table></div>{/if}
</details>
