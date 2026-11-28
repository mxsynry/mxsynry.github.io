# mxsynry.github.io

Repository browser, [Synchrose](Others/Synchrose/), [OutfitSearch](Others/OutfitSearch/)
and [Luau Editor](Others/Editor/).

## Development

Node 24.

```sh
npm ci
npm ci --prefix Others/Synchrose
npm ci --prefix Others/Editor/fileaccess
npm test
npm test --prefix Others/Synchrose
```

`npm run format` formats source. `npm run check:text` checks for garbled text.

## Deployment

`npm run build` writes `pages-dist/` for GitHub Pages or Cloudflare.
`node pages-build.mjs` is the same build command. Stage new files before building.

Cloudflare includes Synchrose's API bridge. Static hosts use dated catalog
snapshots when the bridge is unavailable. OutfitSearch's Worker deploys separately.

`npm run index` updates the file tree and page list.

<!-- pages-index:start -->
## Site Pages

This section is automatically generated from the HTML files in this repository.

| Page | File |
|---|---|
| [docs](https://mxsynry.github.io/docs/) | `docs/index.html` |
| [Home](https://mxsynry.github.io/) | `index.html` |
| [Others/Editor](https://mxsynry.github.io/Others/Editor/) | `Others/Editor/index.html` |
| [Others/OutfitSearch](https://mxsynry.github.io/Others/OutfitSearch/) | `Others/OutfitSearch/index.html` |
| [Others/Synchrose](https://mxsynry.github.io/Others/Synchrose/) | `Others/Synchrose/index.html` |
| [Others/Synchrose/src](https://mxsynry.github.io/Others/Synchrose/src/) | `Others/Synchrose/src/index.html` |
<!-- pages-index:end -->
