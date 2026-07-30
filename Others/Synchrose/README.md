# Synchrose

Static frontend with a small Cloudflare Worker for Pulsery's public exploit status and approved user reviews.

## Data routes

- WEAO and Voxlis load through their existing public endpoints.
- Inject loads directly from `https://inject.today/api/cheats`.
- Pulsery loads through `GET /api/pulsery/status` on the dedicated Worker.
- Approved Pulsery reviews load only when an executor's details dialog opens, through `GET /api/pulsery/reviews?executor=NAME`.
- Pulsery scripts, update histories, and every RDD page are intentionally excluded.

## Deploy the Worker

1. Open a terminal in this directory.
2. Store Pulsery's public Supabase anon key as a Worker secret:

   ```sh
   npx wrangler secret put PULSERY_SUPABASE_KEY
   ```

3. Run `npx wrangler deploy`.
4. Copy the resulting `https://...workers.dev` URL.
5. Put that URL in the `synchrose-api-base` meta tag in `index.html`.

For a temporary test without editing the meta tag, open:

```text
https://YOUR-SITE.example/Others/Synchrose/?api=https://YOUR-WORKER.workers.dev
```

The query value is stored in this browser. Remove it with:

```js
localStorage.removeItem("synchrose:api-base")
```

The Worker is GET-only, caches Pulsery for five minutes, validates both upstream responses, and returns restricted field sets. Review responses exclude Discord IDs and include approved rows only. The Worker cannot proxy arbitrary URLs.
