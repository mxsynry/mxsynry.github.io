# OutfitSearch

Public Roblox avatars, outfits and emotes, with Rolimons market data.
Serve this folder over HTTP, including `src/`.

## Worker

```sh
npx wrangler deploy
```

Deploy from this folder with `server/` present. Set the Worker URL in the
`outfit-api-base` meta tag or the page's API settings.
`?api=https://your-worker.workers.dev` overrides it; `?api=clear` resets it.

## Search

- `Roblox`: exact username
- `id:1`: user ID
- `search:builder`: account search
- `Roblox, id:1`: multiple inputs, up to 20

Share links accept `?username=`, `?id=`, `?search=` or `?q=`.
Run the repository's `npm test` for data and route checks.
