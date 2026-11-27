import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { once } from "node:events";
import service from "../Others/Editor/fileaccess/app.js";

test("file service starts with an empty store and supports the editor's tab lifecycle", async (t) => {
  const root = await mkdtemp(path.join(tmpdir(), "editor-files-"));
  const app = await service.createApp(path.join(root, "tabs"));
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await rm(root, { recursive: true, force: true });
  });
  const request = (route, options) =>
    fetch(`http://127.0.0.1:${server.address().port}${route}`, options);
  const post = (body) => ({
    method: "POST",
    headers: { "content-type": "text/plain" },
    body,
  });

  assert.deepEqual(await (await request("/files")).json(), []);
  assert.equal((await request("/addtab/test", { method: "POST" })).status, 201);
  assert.equal(
    (await request("/addtab/test.lua", { method: "POST" })).status,
    409,
  );
  assert.equal(
    (await request("/savetab/test.lua", post('print("saved")'))).status,
    200,
  );
  assert.equal(
    await (await request("/opentab/test.lua")).text(),
    'print("saved")',
  );
  assert.equal((await request("/savetab/test.lua", post(""))).status, 200);
  assert.equal(await (await request("/opentab/test.lua")).text(), "");
  assert.deepEqual(
    (await (await request("/files")).json()).map((file) => file.name),
    ["test.lua"],
  );
  assert.equal(
    (await request("/delete/test.lua", { method: "DELETE" })).status,
    200,
  );
  assert.equal((await request("/opentab/test.lua")).status, 404);
  assert.equal(
    (await request("/delete/test.lua", { method: "DELETE" })).status,
    404,
  );
  assert.equal((await request("/files", { method: "OPTIONS" })).status, 204);

  for (const name of ["..hidden.lua", "bad%2Fname.lua", "bad%5Cname.lua"]) {
    assert.equal(
      (await request(`/savetab/${name}`, post("blocked"))).status,
      400,
      name,
    );
  }
  await writeFile(path.join(root, "outside.lua"), "outside");
  await symlink(
    path.join(root, "outside.lua"),
    path.join(root, "tabs/link.lua"),
  );
  assert.equal((await request("/opentab/link.lua")).status, 400);
  assert.equal(
    (await request("/savetab/link.lua", post("blocked"))).status,
    400,
  );
  assert.deepEqual(await (await request("/files")).json(), []);
});
