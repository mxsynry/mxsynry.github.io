<script lang="ts">
  import { SOURCE_META, type ExecutorRecord } from "../lib/catalog/model";
  import { PLATFORM_LABELS, trimNumber } from "../lib/format";
  let { record }: { record: ExecutorRecord } = $props();
  let reports = $derived(
    record.observations.filter(
      (o) =>
        o.unc != null || o.sunc != null || o.myriad != null || o.myriadDetails,
    ),
  );
  function reportDate(value: string | null): string {
    return value
      ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(
          new Date(value),
        )
      : "Not provided";
  }
</script>

<section class="benchmark-section" aria-labelledby="benchmark-title">
  <header>
    <p class="eyebrow">Catalog claims</p>
    <h3 id="benchmark-title">Reported benchmark results</h3>
  </header>
  <p class="section-copy">
    These are catalog reports, rather than tests run by Synchrose. Dates and
    report links appear where supplied. Each value stays with its source and
    platform. UNC and sUNC values outside 0–100% are excluded.
  </p>
  {#each reports as observation}
    <article class="benchmark-report">
      <h4>
        {SOURCE_META[observation.source].label} · {observation.platforms
          .map((p) => PLATFORM_LABELS[p])
          .join(", ")}
      </h4>
      <dl class="benchmark-results">
        <div>
          <dt>UNC</dt>
          <dd>
            {observation.unc == null
              ? "Not reported"
              : `${trimNumber(observation.unc)}%`}
          </dd>
        </div>
        <div>
          <dt>sUNC</dt>
          <dd>
            {observation.sunc == null
              ? "Not reported"
              : `${trimNumber(observation.sunc)}%`}
          </dd>
        </div>
        <div>
          <dt>
            {observation.myriadDetails ? "Myriad · Vulnerabilities" : "Myriad"}
          </dt>
          <dd>
            {observation.myriad == null
              ? "Not reported"
              : `${trimNumber(observation.myriad)}${observation.myriadDetails ? "%" : ""}`}
          </dd>
          {#if observation.myriad != null && !observation.myriadDetails}<small>
              Category and scale not supplied
            </small>{/if}
        </div>
      </dl>
      {#if observation.suncDetails}<p class="section-copy">
          sUNC suite: {observation.suncDetails.suiteVersion ?? "Not provided"} · Tested:
          {reportDate(observation.suncDetails.testedAt)} · Tested executor: {observation
            .suncDetails.executor ?? "Not provided"}
        </p>{/if}
      {#if observation.myriadDetails}
        {@const details = observation.myriadDetails}
        <p class="section-copy">
          Myriad Vulnerabilities · Report date: {reportDate(details.testedAt)} · Tested
          executor version: {details.executorVersion ?? "Not provided"}
        </p>
        <p class="section-copy">
          Checked: {details.checked ?? "—"} · Secured: {details.secured ?? "—"} ·
          Vulnerable: {details.vulnerable ?? "—"} · Ambiguous: {details.ambiguous ??
            "—"} · Excluded: {details.excluded ?? "—"}
        </p>
        {#if details.url}<a
            class="benchmark-guide"
            href={details.url}
            target="_blank"
            rel="noreferrer"
          >
            Original Myriad report ↗
          </a>{/if}
      {/if}
    </article>
  {:else}<p class="section-copy">
      No benchmark scores were supplied for this entry.
    </p>{/each}
  <p class="section-copy">
    debUNC results are not supplied by the current feeds. Myriad Standards and
    Vulnerabilities results measure different things. Values with no reported
    category remain unclassified.
  </p>
  <a
    class="benchmark-guide"
    href="#terms"
    onclick={(event) => {
      event.preventDefault();
      const activeDialog = event.currentTarget.closest("dialog");
      activeDialog?.close();
      const guide = document.getElementById("terms");
      guide?.focus({ preventScroll: true });
      guide?.scrollIntoView({ block: "start" });
    }}
  >
    Read the test definitions ↓
  </a>
</section>

<style>
  .benchmark-report {
    padding: 16px 0;
    border-bottom: 1px solid var(--line);
  }
  h4 {
    margin: 0;
    font-size: 0.8rem;
    line-height: 1.6;
  }
  .benchmark-results {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
  .benchmark-results dt {
    line-height: 1.5;
  }
  .benchmark-results dd {
    white-space: normal;
    overflow-wrap: anywhere;
    font-size: 0.85rem;
  }
  small {
    display: block;
    margin-top: 8px;
    color: var(--muted);
    font:
      0.7rem/1.5 Inter,
      sans-serif;
  }
  .benchmark-guide {
    display: inline-block;
    margin-top: 8px;
    color: var(--violet-soft);
    font-size: 0.75rem;
    text-underline-offset: 3px;
  }
  @media (max-width: 520px) {
    .benchmark-results {
      grid-template-columns: 1fr;
    }
  }
</style>
