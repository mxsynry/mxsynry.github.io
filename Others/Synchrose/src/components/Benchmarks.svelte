<script lang="ts">
  import { SOURCE_META, type ExecutorRecord } from "../lib/domain";
  let { record }: { record: ExecutorRecord } = $props();
</script>
<section class="benchmark-section" aria-labelledby="myriad-title">
  <header><p class="eyebrow">Compatibility testing</p><h3 id="myriad-title">Myriad</h3></header>
  <p class="section-copy">Source-reported Myriad results, kept separate from sUNC and UNC.</p>
  <dl class="benchmark-results">
    {#each record.observations.filter(o => o.source === "pulsery" || o.myriad != null) as observation}
      <div><dt>{SOURCE_META[observation.source].label} · {observation.platforms.join(", ")}</dt><dd>{observation.myriad == null ? "Not reported" : observation.myriad}</dd></div>
    {:else}<div><dt>Myriad score</dt><dd>Not reported</dd></div>{/each}
  </dl>
</section>
