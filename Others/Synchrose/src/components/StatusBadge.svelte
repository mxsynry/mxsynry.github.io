<script lang="ts">
  import type { WorkingConsensus } from "../lib/domain";
  import { STATUS_LABELS } from "../lib/format";
  interface Props { status: WorkingConsensus; }
  let { status }: Props = $props();
</script>
<span class="status-badge" data-status={status}><i aria-hidden="true"></i>{STATUS_LABELS[status]}</span>
