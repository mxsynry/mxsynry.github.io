# Roblox Outfit Viewer

A GitHub Pages friendly Roblox avatar/outfit viewer. It accepts usernames, user IDs, and multiple comma/newline-separated values.

It shows:

- public profile data
- current full-body avatar thumbnail
- currently wearing assets with icons and catalog links
- saved outfit thumbnails
- outfit detail expansion with asset icons
- JSON export per account

## Important

This project is read-only and uses public Roblox endpoints only. Do not add `.ROBLOSECURITY` cookies or private endpoints.

GitHub Pages is static, so the browser may be blocked by CORS if it calls Roblox directly. Deploy the included Cloudflare Worker as a tiny proxy/aggregator, then paste the Worker URL into the page.

## Where to put this in your repo

This ZIP is already structured for your GitHub Pages repo:

```text
Others/OutfitSearch/index.html
Others/OutfitSearch/styles.css
Others/OutfitSearch/app.js
Others/OutfitSearch/worker.js
Others/OutfitSearch/README.md
```

After pushing it, your page should be here:

```text
https://mxsynry.github.io/Others/OutfitSearch/
```

## Cloudflare Worker setup

Create a Cloudflare Worker and paste the contents of:

```text
Others/OutfitSearch/worker.js
```

Deploy it. Visit:

```text
https://your-worker.workers.dev/api/health
```

It should return JSON like:

```json
{"ok":true,"name":"roblox-outfit-viewer-api"}
```

## Connect the page to the Worker

Open your GitHub Pages site and paste the Worker URL into the API setup box.

You can also set it through the URL:

```text
https://mxsynry.github.io/Others/OutfitSearch/?api=https://your-worker.workers.dev
```

## Fixing a bad saved API URL

This version includes a **Change API** button.

If you accidentally saved your GitHub Pages URL instead of your Worker URL, click **Change API** and paste the real Cloudflare Worker URL.

You can also clear it manually in the browser console:

```js
localStorage.removeItem("robloxOutfitApiBase");
location.reload();
```

## Input examples

```text
Roblox
id:1
Roblox, builderman, id:156
search:builderman
```

`search:keyword` is useful when you want to display multiple possible accounts instead of only exact username resolution.

## Files

- `index.html` — page structure
- `styles.css` — responsive UI
- `app.js` — frontend logic
- `worker.js` — Cloudflare Worker API
