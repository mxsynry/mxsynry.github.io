<script lang="ts">
  import { onMount } from "svelte";
  import { fetchWithFallback } from "../lib/http";
  import { asObject } from "../lib/sources/common";
  import { formatTime } from "../lib/format";
  let { onmobile }: { onmobile: () => void } = $props();
  const platforms = [{key:"Windows",label:"Windows",binary:"WindowsPlayer"},{key:"Mac",label:"macOS",binary:"MacPlayer"},{key:"Android",label:"Android",binary:""},{key:"iOS",label:"iOS",binary:""}];
  let current = $state<Record<string, unknown>>({});
  let past = $state<Record<string, unknown>>({});
  let loading = $state(false);
  let errors = $state<string[]>([]);
  let pulledAt = $state<string | null>(null);
  let copied = $state("");
  let binary = $state("WindowsPlayer");
  let customVersion = $state("");
  let expanded = $state(false);
  function version(data: Record<string, unknown>, key: string): string {
    const value = data[key] ?? data[key.toLowerCase()];
    const nested = asObject(value);
    const result = nested.version ?? nested.Version ?? nested.clientVersionUpload ?? value;
    return typeof result === "string" ? result : "";
  }
  function rdd(binaryType: string, value: string) {
    const url = new URL("https://rdd.weao.gg/");
    url.searchParams.set("binaryType", binaryType); url.searchParams.set("channel", "LIVE");
    if (value) url.searchParams.set("version", value);
    return url.toString();
  }
  async function copy(value: string) { try { await navigator.clipboard.writeText(value); copied = "Version copied"; } catch { copied = "Could not copy; select the version text manually."; } }
  async function refresh() {
    loading = true; errors = [];
    await Promise.all(["current", "past"].map(async kind => {
      try {
        const response = asObject(await fetchWithFallback(`https://weao.xyz/api/versions/${kind}`, `https://whatexpsare.online/api/versions/${kind}`));
        const data = Object.keys(asObject(response.data)).length ? asObject(response.data) : response;
        if (kind === "current") current = data; else past = data;
      } catch { errors = [...errors, `${kind === "current" ? "Current" : "Previous"} versions unavailable; retry to reconnect.`]; }
    }));
    pulledAt = new Date().toISOString(); loading = false;
  }
  onMount(() => { expanded = window.matchMedia("(min-width: 761px)").matches; void refresh(); });
</script>
<details class="versions-panel" bind:open={expanded}>
  <summary>Roblox versions &amp; RDD</summary>
  <div class="versions-toolbar"><span>WEAO · Last check {formatTime(pulledAt)}</span><button type="button" onclick={refresh} disabled={loading}>{loading ? "Checking…" : "Refresh versions"}</button></div>
  {#each errors as error}<p role="status">{error}</p>{/each}
  <div class="version-grid">{#each platforms as platform}
    {@const latest = version(current, platform.key)}{@const previous = version(past, platform.key)}
    <article class="version-card"><h3>{platform.label}</h3><small>Current</small><code>{latest || (loading ? "Loading…" : "Unavailable")}</code>
      <small>Previous</small><code>{previous || (loading ? "Loading…" : "Unavailable")}</code>
      {#if typeof current[`${platform.key}Date`] === "string"}<small>Updated {formatTime(String(current[`${platform.key}Date`]))}</small>{/if}
      <div class="version-actions">{#if latest}<button type="button" onclick={() => copy(latest)}>Copy current</button>{/if}{#if previous}<button type="button" onclick={() => copy(previous)}>Copy previous</button>{/if}</div>
      {#if !platform.binary}<button class="mobile-shortcut" type="button" onclick={onmobile}>Show mobile executors</button>{/if}
      {#if platform.binary}<div class="version-actions">{#if latest}<a href={rdd(platform.binary, latest)} target="_blank" rel="noreferrer">Current in RDD ↗</a>{/if}{#if previous}<a href={rdd(platform.binary, previous)} target="_blank" rel="noreferrer">Previous in RDD ↗</a>{/if}</div>{/if}
    </article>
  {/each}</div>
  <p role="status">{copied}</p>
  <div class="rdd-controls"><label>RDD platform<select bind:value={binary}><option value="WindowsPlayer">Windows Player</option><option value="MacPlayer">macOS Player</option></select></label><label>Build version<input bind:value={customVersion} placeholder="version-… (optional)" /></label><a href={rdd(binary, customVersion.trim())} target="_blank" rel="noreferrer">Open Roblox download archive ↗</a></div>
  <nav class="record-links" aria-label="RDD providers"><a href="https://rdd.weao.gg/" target="_blank" rel="noreferrer">WEAO RDD ↗</a><a href="https://pulsery.gg/rdd" target="_blank" rel="noreferrer">Pulsery RDD ↗</a><a href="https://inject.today/rdd" target="_blank" rel="noreferrer">Inject RDD ↗</a></nav>
</details>
