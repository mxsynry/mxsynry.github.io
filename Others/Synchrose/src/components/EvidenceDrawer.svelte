<script lang="ts">
  import { onMount } from "svelte";
  import { SOURCE_META, type EvidenceConflict, type ExecutorRecord, type SourceRecord } from "../lib/domain";
  import { DETECTION_LABELS, formatSunc, formatTime, PLATFORM_LABELS, trimNumber } from "../lib/format";
  import StatusBadge from "./StatusBadge.svelte";

  interface Props { record: ExecutorRecord; ondismiss: () => void; }
  let { record, ondismiss }: Props = $props();
  let dialog: HTMLDialogElement;

  onMount(() => dialog.showModal());

  function fieldLabel(field: EvidenceConflict["field"]): string {
    return { working: "Status", detection: "Detection", version: "Version", price: "Price", sunc: "sUNC" }[field];
  }

  function sourceStatus(observation: SourceRecord): string {
    if (observation.working === null) return "Unknown";
    return observation.working ? "Working" : "Outdated";
  }
</script>

<dialog bind:this={dialog} class="evidence-dialog" onclose={ondismiss} oncancel={(event) => { event.preventDefault(); dialog.close(); }}>
  <button class="drawer-scrim" type="button" aria-label="Close evidence panel" onclick={() => dialog.close()}></button>
  <article class="evidence-drawer">
    <header class="drawer-header">
      <div>
        <p class="eyebrow">Evidence record / {record.sources.length} source{record.sources.length === 1 ? "" : "s"}</p>
        <h2>{record.name}</h2>
        {#if record.aliases.length > 1}<p class="aliases">Also reported as {record.aliases.filter((name) => name !== record.name).join(", ")}</p>{/if}
      </div>
      <button class="drawer-close" type="button" onclick={() => dialog.close()} aria-label="Close evidence panel">
        <svg viewBox="0 0 20 20" aria-hidden="true"><path d="m4 4 12 12M16 4 4 16"></path></svg>
      </button>
    </header>

    <section class="record-summary" aria-label="Merged summary">
      <div><span>Status</span><StatusBadge status={record.working} /></div>
      <div><span>Platform</span><strong>{record.platforms.map((platform) => PLATFORM_LABELS[platform]).join(", ")}</strong></div>
      <div><span>Detection</span><strong>{DETECTION_LABELS[record.detection]}</strong></div>
      <div><span>sUNC range</span><strong>{formatSunc(record.sunc)}</strong></div>
      <div><span>Price</span><strong>{record.price || "Not reported"}</strong></div>
      <div><span>Version</span><strong>{record.version || "Not reported"}</strong></div>
    </section>

    {#if record.conflicts.length}
      <section class="conflict-panel">
        <div class="section-heading"><p class="eyebrow">Source disagreement</p><span>{record.conflicts.length} field{record.conflicts.length === 1 ? "" : "s"}</span></div>
        <p>Synchrose does not choose a winner when sources disagree. The reported values stay visible below.</p>
        {#each record.conflicts as conflict}
          <div class="conflict-row">
            <strong>{fieldLabel(conflict.field)}</strong>
            <div>{#each conflict.values as item}<span><b>{SOURCE_META[item.source].label}</b>{item.value}</span>{/each}</div>
          </div>
        {/each}
      </section>
    {/if}

    <section class="source-evidence">
      <div class="section-heading"><p class="eyebrow">Source reports</p><span>Raw claims, normalized labels</span></div>
      {#each record.observations as observation}
        <article class="observation-card">
          <header>
            <div><span class="source-indicator" data-state="live"></span><strong>{SOURCE_META[observation.source].label}</strong></div>
            <a href={SOURCE_META[observation.source].url} target="_blank" rel="noreferrer">Open source ↗</a>
          </header>
          <dl>
            <div><dt>Status</dt><dd>{sourceStatus(observation)}</dd></div>
            <div><dt>Detection</dt><dd>{DETECTION_LABELS[observation.detection]}</dd></div>
            <div><dt>Version</dt><dd>{observation.version || "—"}</dd></div>
            <div><dt>Roblox build</dt><dd>{observation.robloxVersion || "—"}</dd></div>
            <div><dt>sUNC</dt><dd>{observation.sunc === null ? "—" : `${trimNumber(observation.sunc)}%`}</dd></div>
            <div><dt>Price</dt><dd>{observation.price || "—"}</dd></div>
          </dl>
          {#if observation.description}<p class="observation-note">{observation.description}</p>{/if}
          <footer>Source update: {formatTime(observation.sourceUpdatedAt)} · Retrieved: {formatTime(observation.fetchedAt)}</footer>
        </article>
      {/each}
    </section>

    {#if record.features.length || record.description}
      <section class="record-notes">
        <div class="section-heading"><p class="eyebrow">Catalog notes</p></div>
        {#if record.description}<p>{record.description}</p>{/if}
        {#if record.features.length}<div class="feature-list">{#each record.features as feature}<span>{feature}</span>{/each}</div>{/if}
      </section>
    {/if}

    {#if Object.values(record.links).some(Boolean)}
      <nav class="record-links" aria-label={`${record.name} links`}>
        {#if record.links.website}<a href={record.links.website} target="_blank" rel="noreferrer">Website ↗</a>{/if}
        {#if record.links.discord}<a href={record.links.discord} target="_blank" rel="noreferrer">Discord ↗</a>{/if}
        {#if record.links.purchase}<a href={record.links.purchase} target="_blank" rel="noreferrer">Purchase ↗</a>{/if}
        {#if record.links.review}<a href={record.links.review} target="_blank" rel="noreferrer">Review ↗</a>{/if}
      </nav>
    {/if}
  </article>
</dialog>
