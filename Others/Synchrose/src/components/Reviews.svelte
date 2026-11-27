<script lang="ts">
  import { onMount } from "svelte";
  import { z } from "zod";
  import type { ExecutorRecord } from "../lib/catalog/model";
  import { fetchJson } from "../lib/http";
  import { safeUrl, formatTime, PLATFORM_LABELS } from "../lib/format";
  import Stars from "./Stars.svelte";
  import Markdown from "./Markdown.svelte";
  import { summarizeReviews } from "../lib/review-summary";
  let { apiBase, record }: { apiBase: string; record: ExecutorRecord } =
    $props();
  const reviewSchema = z.object({
    id: z.string().optional(),
    author: z.string().default("Pulsery user"),
    rating: z.number().nullable().default(null),
    text: z.string().default(""),
    created_at: z.string().nullable().optional(),
    avatar_url: z.string().nullable().optional(),
    screenshots: z.array(z.string()).default([]),
    reply_text: z.string().nullable().optional(),
    reply_author: z.string().nullable().optional(),
    reply_at: z.string().nullable().optional(),
  });
  type Review = z.infer<typeof reviewSchema>;
  let pulsery = $derived(
    record.observations.find((o) => o.source === "pulsery"),
  );
  let voxlis = $derived(
    record.observations.filter((o) => o.source === "voxlis"),
  );
  let voxlisNotes = $derived(voxlis.filter((o) => Boolean(o.reviewNotes)));
  let reviews = $state<Review[]>([]);
  let loading = $state(true);
  let error = $state("");
  let sort = $state("recent");
  let limit = $state(10);
  let summary = $derived(summarizeReviews(reviews));
  let sorted = $derived(
    [...reviews].sort((a, b) =>
      sort === "critical"
        ? (a.rating ?? 6) - (b.rating ?? 6)
        : (Date.parse(b.created_at || "") || 0) -
          (Date.parse(a.created_at || "") || 0),
    ),
  );
  function metrics(text: string) {
    return text
      .split(/\r?\n/)
      .map((line) =>
        line.match(/^\[\s*([^:\]]+):\s*(\d+(?:\.\d+)?)\s*\/\s*5\s*\]$/),
      )
      .filter(Boolean)
      .map((match) => ({
        label: match![1],
        score: Math.min(5, Number(match![2])),
      }));
  }
  async function loadReviews() {
    loading = true;
    error = "";
    try {
      if (!apiBase) throw new Error("The review bridge is not configured.");
      const url = new URL(`${apiBase}/api/pulsery/reviews`);
      url.searchParams.set(
        "executor",
        pulsery?.sourceId || pulsery?.name || record.name,
      );
      reviews = z
        .object({ reviews: z.array(reviewSchema) })
        .parse(await fetchJson(url.toString())).reviews;
    } catch (e) {
      error = e instanceof Error ? e.message : "Reviews unavailable";
    } finally {
      loading = false;
    }
  }
  onMount(() => {
    if (pulsery) void loadReviews();
  });
</script>

{#if pulsery}
  <section class="reviews-section">
    <h3>Pulsery user reviews</h3>
    {#if !loading && !error && reviews.length}
      <div class="review-summary">
        <Stars rating={summary.average} /><span>
          {summary.count} loaded reviews · {summary.rated} rated
        </span>
      </div>
    {/if}
    {#if loading}<p role="status">Loading approved reviews…</p>
    {:else if error}<p role="alert">{error}</p>
      <button type="button" onclick={loadReviews}>Retry reviews</button>
    {:else if !reviews.length}<p>No approved reviews yet.</p>
    {:else}
      <label class="review-sort">
        Sort reviews <select bind:value={sort}>
          <option value="recent">Most recent</option><option value="critical">
            Most critical
          </option>
        </select>
      </label>
      {#each sorted.slice(0, limit) as review}
        <article class="user-review">
          <header>
            {#if safeUrl(review.avatar_url)}<img
                class="review-avatar"
                src={safeUrl(review.avatar_url)}
                alt=""
                loading="lazy"
                referrerpolicy="no-referrer"
              />{/if}
            <strong>{review.author}</strong><Stars rating={review.rating} />
          </header>
          <small>{formatTime(review.created_at ?? null)}</small>
          {#if metrics(review.text).length}<dl class="review-breakdown">
              {#each metrics(review.text) as metric}<div>
                  <dt>{metric.label}</dt>
                  <dd>{metric.score}/5</dd>
                </div>{/each}
            </dl>{/if}
          <Markdown
            text={review.text
              .replace(
                /^\[\s*([^:\]]+):\s*\d+(?:\.\d+)?\s*\/\s*5\s*\]\s*$/gm,
                "",
              )
              .trim()}
          />
          <div class="review-screenshots">
            {#each review.screenshots.filter((url) => safeUrl(url)) as url, i}<a
                href={safeUrl(url)}
                target="_blank"
                rel="noreferrer"
              >
                <img
                  src={safeUrl(url)}
                  alt={`Review screenshot ${i + 1} by ${review.author}`}
                  loading="lazy"
                  referrerpolicy="no-referrer"
                />
              </a>{/each}
          </div>
          {#if review.reply_text}<blockquote>
              <strong>
                {review.reply_author || "Developer reply"}
              </strong><Markdown text={review.reply_text} /><small>
                {formatTime(review.reply_at ?? null)}
              </small>
            </blockquote>{/if}
        </article>
      {/each}
      {#if limit < reviews.length}<button
          type="button"
          onclick={() => {
            limit += 10;
          }}
        >
          Show more reviews ({reviews.length - limit})
        </button>{/if}
    {/if}
  </section>
{/if}
{#if voxlis.length}<section class="reviews-section">
    <h3>Voxlis review notes</h3>
    {#each voxlisNotes as observation}<article>
        <p class="eyebrow">
          {observation.platforms.map((p) => PLATFORM_LABELS[p]).join(", ")}
        </p>
        <Markdown text={observation.reviewNotes ?? ""} />
      </article>
    {:else}<p>No published review notes.</p>{/each}
  </section>{/if}
