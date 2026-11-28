import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../site-worker.js";

test("the site's Worker serves the current bridge routes with CORS", async () => {
  const response = await worker.fetch(
    new Request("https://site.test/api/health"),
    {},
    {},
  );
  const health = await response.json();
  assert.equal(response.headers.get("access-control-allow-origin"), "*");
  assert.ok(health.routes.includes("/api/voxlis/catalog"));
  assert.ok(health.routes.includes("/api/bypass/catalog"));
});

test("site assets reach the asset binding and unknown API routes remain closed", async () => {
  const env = {
    ASSETS: {
      fetch: (request) =>
        new Response(`asset: ${new URL(request.url).pathname}`),
    },
  };
  const response = await worker.fetch(
    new Request("https://site.test/Others/Synchrose/"),
    env,
    {},
  );
  assert.equal(await response.text(), "asset: /Others/Synchrose/");
  const unknown = await worker.fetch(
    new Request("https://site.test/api/proxy?url=https://example.test"),
    env,
    {},
  );
  assert.equal(unknown.status, 404);
});
