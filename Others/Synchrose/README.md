# Synchrose

Roblox executor reports from WEAO, Voxlis, Pulsery and bypass.tools.
Built with Svelte, TypeScript and Vite.

## Development

Node 24.

```sh
npm ci
npm run dev
```

Checks: `npm test`, `npm run check`.

`npm run build` writes `dist/` and syncs `index.html`, `assets/` and `catalog/`
for static hosting. Edit `src/`; the root HTML and bundles are generated.

## Data

| Source       | Route                                  |
| ------------ | -------------------------------------- |
| WEAO         | `https://weao.xyz/api/status/exploits` |
| Voxlis       | `/api/voxlis/catalog`                  |
| Pulsery      | `/api/pulsery/status`                  |
| bypass.tools | `/api/bypass/catalog`                  |

The root site build includes the Cloudflare bridge. Static hosts fall back to
catalog snapshots, marked cached. Builds refresh them; `npm run catalog:refresh`
refreshes them manually. Failed requests keep the previous snapshot.

For a standalone bridge: `npm run worker:deploy`. Pulsery reviews need
`PULSERY_SUPABASE_KEY` on that Worker. The default URL is in `src/index.html`;
`?api=https://your-worker.workers.dev` overrides it, and `?api=clear` resets it.

[Definitions and source references](../../docs/research/synchrose.md).
