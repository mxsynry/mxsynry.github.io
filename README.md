# mxsynry site

A file browser and a few small web projects, hosted on GitHub Pages and Cloudflare Pages.

## Repository layout

| Folder                 | Contents                                                            |
| ---------------------- | ------------------------------------------------------------------- |
| `assets/`              | File browser styles and JavaScript                                  |
| `Others/Synchrose/`    | Executor catalog, source guides and data bridge                     |
| `Others/OutfitSearch/` | Public avatar lookup and its API Worker                             |
| `Others/Editor/`       | Monaco editor and optional local file service                       |
| `docs/`                | Synchrose documentation; dated source notes are in `docs/research/` |
| `storage/`             | Archived scripts and media                                          |
| `scripts/`             | Site build and repository index generators                          |

## Work locally

Use Node.js 24 or newer. Install the root tools, editor service and Synchrose dependencies:

```sh
npm ci
npm ci --prefix Others/Editor/fileaccess
npm ci --prefix Others/Synchrose
```

Run `npm test` for the file browser, publisher, editor service and OutfitSearch checks. Synchrose has its own `npm test` and `npm run check` commands in `Others/Synchrose/`. Use `npm run format` to format maintained code; bundled libraries, archives and generated files are excluded.

Run `npm run check:text` to catch hidden or garbled source text. The [latest audit](docs/research/repository-audit-2026-11-27.md) records the changes and remaining archived loaders.

## Build and publish

`npm run build` creates `pages-dist/`. Both GitHub Pages and Cloudflare Pages use this output. The existing Cloudflare build command, `node pages-build.mjs`, still works; set its output directory to `pages-dist`.

The publisher uses Git's file list. Stage new files before a local build so they appear in the site and indexes. It excludes dependencies, environment files, editor tab data, duplicate build directories and `storage/other-stuff/mods.rar`.

`npm run index` updates `tree.json` and the page list below. GitHub Actions also updates these indexes after changes reach `main`.

Each app's README covers its own setup. Cloudflare Workers are deployed separately from the static site, so deploy a changed Worker together with its frontend.

<!-- pages-index:start -->

## Site Pages

Generated from the published HTML pages.

| Page                                                                  | File                             |
| --------------------------------------------------------------------- | -------------------------------- |
| [docs](https://mxsynry.github.io/docs/)                               | `docs/index.html`                |
| [Home](https://mxsynry.github.io/)                                    | `index.html`                     |
| [Others/Editor](https://mxsynry.github.io/Others/Editor/)             | `Others/Editor/index.html`       |
| [Others/OutfitSearch](https://mxsynry.github.io/Others/OutfitSearch/) | `Others/OutfitSearch/index.html` |
| [Others/Synchrose](https://mxsynry.github.io/Others/Synchrose/)       | `Others/Synchrose/index.html`    |

<!-- pages-index:end -->
