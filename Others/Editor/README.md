# Luau Editor

A browser-based Monaco editor with optional local file persistence.

## Run the file API

The editor can work from browser storage, or connect to the local API in `fileaccess/`:

```sh
cd Others/Editor/fileaccess
npm install
node index.js
```

The API listens on `http://localhost:9911` and stores files only in `fileaccess/SolaraTab/`.

## Routes

- `GET /files` lists saved files.
- `GET /opentab/:filename` reads a file.
- `POST /savetab/:filename` writes text content.
- `POST /addtab/:filename` creates a Lua tab.
- `DELETE /delete/:filename` removes a file.

Filenames are restricted to simple Lua-style names and every route rejects path traversal. Do not expose this development server to the public internet without adding authentication and a restricted CORS policy.

## Frontend

Open `index.html` from a static server. The editor falls back to local browser storage when the API is unavailable. Monaco assets are bundled under `vs/` and should not be edited manually.
