# OutfitSearch

A static frontend for public Roblox avatar data, plus a small Cloudflare Worker that makes the Roblox API requests.

## Put it in the repository

Copy this entire folder to:

```text
site-root/
└── Others/
    └── OutfitSearch/
        ├── index.html
        ├── styles.css
        ├── app.js
        ├── worker.js
        ├── wrangler.json
        └── README.md
```

Your static host serves `index.html`, `styles.css`, and `app.js`. `worker.js` must be deployed separately to Cloudflare Workers.

## Deploy the Worker

### Cloudflare dashboard

1. Open **Workers & Pages** and create a Worker.
2. Open **Edit code**.
3. Replace the starter code with `worker.js`.
4. Deploy and copy the public `https://…workers.dev` URL.

### Wrangler

From this folder:

```bash
npx wrangler deploy
```

No Roblox cookie, Cloudflare token in the browser, or other secret is required by the app.

## Connect the frontend

Use either method:

1. Open OutfitSearch, choose **Connect API**, and paste the Worker URL. The browser saves it locally.
2. For a site-wide default, edit this line in `index.html`:

```html
<meta name="outfit-api-base" content="https://your-worker.workers.dev" />
```

A `?api=https://your-worker.workers.dev` URL still works and takes priority.

## Search syntax

- `Roblox` — exact username
- `id:1` — exact user ID
- `search:builder` — broad Roblox user search
- `Roblox, id:1` — several inputs at once, up to 20

Direct links still work: `?username=Roblox`, `?id=1`, `?search=builder`, and `?q=Roblox,id:1`.

## What changed in this rebuild

- Cancellable searches with three account reports loaded in parallel.
- Per-account tabs for wearing items, saved outfits, packs, and emotes.
- Outfit contents open in a focused dialog instead of extending the page.
- API setup is tucked away until it is needed.
- The debug console stays available but never opens by itself.
- Worker requests time out safely, avoid retrying Roblox `429` responses, and expose request IDs.
- Saved outfits use Roblox’s current v2 endpoint, with the old v1 endpoint kept only as a fallback.

Worker version: `2026-07-23.1-outfitsearch-rebuild`
