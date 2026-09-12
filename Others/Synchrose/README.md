# Synchrose

An evidence-first Roblox executor status index. Synchrose combines four public catalogs—WEAO, Voxlis, Pulsery, and Inject—while retaining each source's claims and making disagreements visible.

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
- Voxlis provides catalog details and pricing through `/api/voxlis/*`.
- Pulsery provides public status and approved reviews through `/api/pulsery/*`.
- Inject provides status and catalog reports.
- Each report keeps its source, fetch time, source update time, and source-specific values.
- Conflicting status, detection, version, price, and sUNC claims are shown to the user. They are never silently flattened into a false consensus.
- A working report is not a claim that an executor is safe.

## Worker

The existing `worker.js` exposes only fixed GET routes and cannot proxy arbitrary URLs. Set its required secrets, deploy it separately, then place its URL in the `synchrose-api-base` meta tag in `index.html`.

For a temporary local override, use `?api=https://YOUR-WORKER.workers.dev`. Clear the saved override with `?api=clear`.

```sh
npm run worker:dev
npm run worker:deploy
```

Do not put private service-role credentials in the frontend or in version control.
