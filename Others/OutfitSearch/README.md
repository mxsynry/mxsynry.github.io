# Roblox Outfit Viewer

Static GitHub Pages frontend plus a Cloudflare Worker backend for public Roblox avatar lookups.

## Where to put these files

For `mxsynry.github.io`, place the folder here:

```txt
Others/OutfitSearch/
```

Then open:

```txt
https://mxsynry.github.io/Others/OutfitSearch/
```

## Simple Cloudflare Worker setup

1. Open Cloudflare → Workers & Pages → Create application → Worker.
2. Name it `roblox-outfit-api` and deploy the starter Worker.
3. Click Edit code.
4. Replace the starter code with `worker.js` from this folder.
5. Save and deploy.
6. Copy the public URL ending in `.workers.dev`.
7. Open the Outfit Viewer, click Change API, paste that Worker URL, and save.

Only paste the public Worker URL. Do not paste Cloudflare API tokens, Roblox cookies, GitHub tokens, or your GitHub Pages URL.

## New in this build

- View console button with request/debug logs.
- Instructions popup for setup.
- Better handling for nonexistent users and non-JSON error pages.
- Deduplicated currently-wearing item IDs.
- Uses richer avatar asset data before falling back to catalog/economy details.


## 2026-06-23 update

- Item details now try catalog batch first, then economy asset details for missing/old assets, so fewer cards fall back to `Asset <id>`.
- Saved outfits now stay as outfit cards only. Clicking an outfit fills a separate Selected outfit items section below.
- Redeploy `worker.js` after replacing the GitHub Pages files.
