# Synchrose

A Roblox executor reference. Synchrose combines four public catalogs—WEAO, Voxlis, Pulsery, and bypass.tools—while retaining each source's claims and making differences visible. Its terms and source guides explain UNC, sUNC, debUNC, Myriad, executor identification, and thread identity using original documentation.

## Definitions and source review

The guide was reviewed on **22 November 2026**. The [research notes](../../docs/research/synchrose.md) cite the original test projects and record the limits of the requested community sources: Voxlis, bypass.tools, RobloxScripts, ScriptDumper, and r/robloxhackers.

- UNC includes behavioral checks; the original project was archived in May 2024.
- sUNC, debUNC, and Myriad use their own checks and versions. Their scores are not interchangeable.
- Myriad Standards and Vulnerabilities results are separate. Voxlis Vulnerabilities audit ratings retain their category, report link, counts and test date. Unclassified Myriad values from other feeds are shown without inventing a category or percentage scale.
- `identifyexecutor` reports a name/version. Thread identity describes a permission context.
- Listings, “Verified” badges, detection claims, and clean scans do not certify software safety.

No executor or remote test script was run. bypass.tools replaces the retired Inject integration as the fourth live catalog source. Structured debUNC results are not supplied. Test metadata is displayed when available; Synchrose does not independently verify test reports.

## Stack

- Svelte 5 and TypeScript
- Vite
- Zod validation at every network boundary
- A fixed-route, read-only Cloudflare Worker for sources that require a server-side adapter

## Local development

```sh
npm install
npm run dev
```

Other checks:

```sh
npm run check
npm test
npm run build
```

The production site is emitted to `dist/`. The build then copies the compiled `index.html` and hashed bundles into the project root so this directory also works when served directly by GitHub Pages or Cloudflare Pages without a framework build step. Vite uses relative asset paths so it can remain hosted under `/Others/Synchrose/`.

Do not replace the root `index.html` with `src/index.html`. The root file is the compiled static entry; `src/index.html` is the editable Vite entry.

## Data policy

- WEAO provides status, version, and detection reports.
- Voxlis provides its current directory through `/api/voxlis/catalog`, backed by `https://voxlis.net/api/directory/roblox`. Each platform variant remains a separate observation. Roblox target versions are kept separate from executor releases and historical benchmark builds. Review notes come inline from the directory.
- Pulsery provides public status and approved reviews through `/api/pulsery/*`.
- bypass.tools provides its public `https://bypass.tools/api/executors` listing through `/api/bypass/catalog`. WEAO-synced rows retain that attribution. A bare `UNC` feature marker is not converted into a score or copied from sUNC.
- Each report keeps its source, fetch time, source update time, and source-specific values.
- A missing source update time stays unknown; the retrieval time is not substituted for it.
- Generic “safe” or “unsafe” labels do not become detection reports. Detection and malware safety are separate claims.
- UNC and sUNC percentages outside 0–100 are excluded rather than used in ranges, sorting, or score filters. Cached reports from before these normalization changes are invalidated.
- Conflicting status, detection, version, price, and sUNC claims are shown to the user. They are never silently flattened into a false consensus.
- A working report is not a claim that an executor is safe.

## Worker

`worker.js` exposes only fixed GET routes and cannot proxy arbitrary URLs. Voxlis and bypass.tools do not send browser CORS permission, so both use the Worker bridge. **Deploy the updated Worker along with the frontend:** an older Worker does not serve the new catalog routes. Its configured name remains `mxsynry`; the frontend Worker URL is set in the `synchrose-api-base` meta tag in `src/index.html`.

The Voxlis and bypass.tools routes need no API secrets. The existing Pulsery reviews route uses `PULSERY_SUPABASE_KEY`; deploying the Worker preserves secrets already configured on that Worker.

For a temporary local override, use `?api=https://YOUR-WORKER.workers.dev`. Clear the saved override with `?api=clear`.

```sh
npm run worker:dev
npm run worker:deploy
```

Do not put private service-role credentials in the frontend or in version control.
