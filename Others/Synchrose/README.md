# Synchrose

Static GitHub Pages frontend with a small Cloudflare Worker for Pulsery's public exploit-status feed.

## Data routes

- WEAO and Voxlis load through their existing public endpoints.
- Inject loads directly from `https://inject.today/api/cheats`.
- Pulsery loads through `GET /api/pulsery/status` on the dedicated Worker.
- Pulsery scripts, reviews, update histories, and every RDD page are intentionally excluded.

## Deploy the Worker

1. Open a terminal in this directory.
2. Run `npx wrangler deploy`.
3. Copy the resulting `https://...workers.dev` URL.
4. Put that URL in the `synchrose-api-base` meta tag in `index.html`.

For a temporary test without editing the meta tag, open:

```text
https://mxsynry.github.io/Others/Synchrose/?api=https://YOUR-WORKER.workers.dev
```

The query value is stored in this browser. Remove it with:

```js
localStorage.removeItem("synchrose:api-base")
```

The Worker is GET-only, caches Pulsery for five minutes, validates the upstream response, and returns a restricted field set. It cannot proxy arbitrary URLs.
