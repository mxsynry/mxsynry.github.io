# Roblox Outfit Viewer

Static GitHub Pages frontend plus Cloudflare Worker API for public Roblox avatar lookups.

## Direct URL lookups

These run automatically when the Worker URL has already been saved in the browser:

- `?username=zxwnvc`
- `?id=8625608859`
- `?search=builderman`
- `?q=Roblox,id:1`

You can also set the API from the URL once:

- `?api=https://your-worker.yourname.workers.dev&username=zxwnvc`

## Deploy

Put these files in:

```txt
Others/OutfitSearch/
```

Deploy `worker.js` to Cloudflare Workers, then paste the public `.workers.dev` URL into the page.

Do not paste API tokens, Roblox cookies, or GitHub tokens into the app.
