# Luau Editor

Monaco editor with saved tabs and Luau completions. Serve this folder over HTTP.
Tabs use browser storage when the local file service is offline.

## File service

```sh
cd fileaccess
npm ci
npm start
```

Listens on `127.0.0.1:9911`. Files go in `fileaccess/SolaraTab/` (gitignored).
Configure `PORT` or `EDITOR_FILES_DIR` on the server, and `apiBase` in `src/tabs.js`.

```text
GET    /files
GET    /opentab/:filename
POST   /savetab/:filename     text/plain
POST   /addtab/:filename
DELETE /delete/:filename
```

Page code is in `src/`; bundled Monaco is in `vs/`.
The WebView API exposes `GetText`, `SetText`, `LuauTabs` and the existing editor controls.
