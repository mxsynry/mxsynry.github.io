# Roblox Outfit Viewer

A GitHub Pages friendly Roblox avatar/outfit viewer. It accepts usernames, user IDs, and multiple comma/newline-separated values. It shows:

- public profile data
- current full-body avatar thumbnail
- currently wearing assets with icons and catalog links
- saved outfit thumbnails
- outfit detail expansion with asset icons
- JSON export per account

## Important

This project is read-only and uses public Roblox endpoints only. Do not add `.ROBLOSECURITY` cookies or private endpoints.

GitHub Pages is static, so the browser may be blocked by CORS if it calls Roblox directly. Deploy the included Cloudflare Worker as a tiny proxy/aggregator, then paste the Worker URL into the page.

## Deploy

### 1) GitHub Pages

Upload these files to your repo:

```text
index.html
styles.css
app.js
README.md
```

Enable Pages in GitHub: Settings → Pages → Deploy from branch → main → root.

### 2) Cloudflare Worker

Create a Worker and paste `worker.js` into it. Deploy it. Visit:

```text
https://your-worker.workers.dev/api/health
```

It should return JSON with `ok: true`.

### 3) Connect the site to the Worker

Open your GitHub Pages site and paste the Worker URL into the API setup box, or open:

```text
https://yourname.github.io/yourrepo/?api=https://your-worker.workers.dev
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
