# Luau Editor

A Monaco editor with saved tabs and Luau completion suggestions. It works from browser storage when the optional local file service is unavailable.

Serve this folder over HTTP and open `index.html`. The bundled Monaco files are in `vs/`; page code lives in `src/` and styles in `styles.css`. Keep vendored Monaco files out of manual formatting and cleanup passes.

## Local files

```sh
cd Others/Editor/fileaccess
npm ci
npm start
```

The service listens on `http://127.0.0.1:9911` and creates `fileaccess/SolaraTab/` if needed. Tab files are local data and are excluded from Git and the published site. Set `PORT` or `EDITOR_FILES_DIR` to change the server settings; the frontend API URL is configured in `src/tabs.js`.

| Route                      | Action                   |
| -------------------------- | ------------------------ |
| `GET /files`               | List saved files         |
| `GET /opentab/:filename`   | Read a file              |
| `POST /savetab/:filename`  | Save a `text/plain` body |
| `POST /addtab/:filename`   | Create a Lua tab         |
| `DELETE /delete/:filename` | Delete a file            |

Names must start with a letter or number and contain only letters, numbers, dots, underscores or hyphens. Parent-directory references are rejected. The service binds to loopback; it is intended to run on the editor user's computer.

## Embedded hosts

`src/main.js` keeps the existing `GetText`, `SetText`, minimap, completion and refresh functions on `window` for WebView integrations. Tab helpers remain available through `window.LuauTabs` and their existing aliases.

Run the repository's `npm test` command for file-service checks.
