# OutfitSearch

Look up public Roblox avatars, saved outfits, packs and emotes. Roblox supplies avatar and sale data; Rolimons adds market values for supported limiteds.

The frontend is static. Serve this folder over HTTP, including `src/`. The Cloudflare Worker is deployed separately.

## Files

- `src/app.js` handles the page and searches.
- `src/cards.js` renders item and outfit cards.
- `src/commerce.js` decides which price and market labels to show.
- `src/outfits.js` groups bundle components and saved outfits.
- `worker.js` defines the public routes.
- `server/roblox.js` and `server/rolimons.js` fetch and normalize provider data.
- `server/http.js` handles responses, caching and request metadata.

`app.js` is the frontend entry point. Keep `server/` alongside `worker.js` when deploying; copying only the entry file into the Cloudflare dashboard is no longer enough.

## Deploy and connect

From this folder, run `npx wrangler deploy`. Wrangler bundles the Worker and its imports using `wrangler.json`.

Set the deployed URL in the `outfit-api-base` meta tag in `index.html`, or use the page's API button to save a URL in your browser. A `?api=https://your-worker.workers.dev` override takes priority; `?api=clear` removes the saved override. No Roblox login or cookie is required.

## Searches

- `Roblox` looks up an exact username.
- `id:1` looks up an exact user ID.
- `search:builder` searches for possible accounts.
- `Roblox, id:1` accepts several inputs, up to 20.

Share links accept `?username=Roblox`, `?id=1`, `?search=builder` and `?q=Roblox,id:1`.

Requests have timeouts. Roblox rate limits are returned without immediate retries. Outfit details are cached and shared by simultaneous requests. Run the repository's `npm test` command for data and route checks.
