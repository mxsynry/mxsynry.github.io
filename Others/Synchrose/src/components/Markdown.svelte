<script lang="ts">
  import { renderMarkdown } from "../lib/markdown";
  let { text }: { text: string } = $props();
  let html = $derived(renderMarkdown(text));
</script>
<div class="markdown">{@html html}</div>
