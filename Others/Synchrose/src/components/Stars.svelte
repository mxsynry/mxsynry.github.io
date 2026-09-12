<script lang="ts">
  let { rating }: { rating: number | null } = $props();
  let value = $derived(rating == null ? null : Math.max(0, Math.min(5, rating)));
</script>
{#if value !== null}<span class="stars" aria-label={`${value.toFixed(1)} out of 5 stars`}><span aria-hidden="true">{"★".repeat(Math.round(value))}{"☆".repeat(5 - Math.round(value))}</span> {value.toFixed(1)}/5</span>{/if}
