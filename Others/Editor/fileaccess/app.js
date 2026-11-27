const express = require("express");
const { constants } = require("node:fs");
const { mkdir, open, readdir, lstat, unlink } = require("node:fs/promises");
const path = require("node:path");

const fileNamePattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$/;

async function createApp(directory) {
  const filesDirectory = path.resolve(directory);
  await mkdir(filesDirectory, { recursive: true });
  const app = express();
  app.disable("x-powered-by");
  app.use((request, response, next) => {
    response.set({
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    if (request.method === "OPTIONS") return response.sendStatus(204);
    next();
  });
  app.use(express.text({ limit: "1mb" }));

  function filePath(name) {
    if (!fileNamePattern.test(name) || name.includes("..")) {
      const error = new Error("Invalid file name");
      error.status = 400;
      throw error;
    }
    return path.join(filesDirectory, name);
  }

  const route = (handler) => (request, response, next) => {
    Promise.resolve()
      .then(() => handler(request, response))
      .catch(next);
  };

  app.get(
    "/files",
    route(async (_request, response) => {
      const entries = await readdir(filesDirectory, { withFileTypes: true });
      const files = await Promise.all(
        entries
          .filter(
            (entry) =>
              entry.isFile() &&
              entry.name !== "undefined" &&
              fileNamePattern.test(entry.name) &&
              !entry.name.includes(".."),
          )
          .map(async (entry) => ({
            name: entry.name,
            createdAt: (await lstat(filePath(entry.name))).birthtime,
          })),
      );
      files.sort(
        (a, b) => a.createdAt - b.createdAt || a.name.localeCompare(b.name),
      );
      response.json(files);
    }),
  );

  app.post(
    "/addtab/:filename",
    route(async (request, response) => {
      const rawName = request.params.filename;
      const name = /\.(lua|luau)$/i.test(rawName) ? rawName : `${rawName}.lua`;
      const file = await open(filePath(name), "wx");
      await file.close();
      response.status(201).send(`${name} has been created.`);
    }),
  );

  app.get(
    "/opentab/:filename",
    route(async (request, response) => {
      const file = await open(
        filePath(request.params.filename),
        constants.O_RDONLY | constants.O_NOFOLLOW,
      );
      try {
        if (!(await file.stat()).isFile())
          return response.status(400).send("Not a file");
        response.type("text/plain").send(await file.readFile("utf8"));
      } finally {
        await file.close();
      }
    }),
  );

  app.post(
    "/savetab/:filename",
    route(async (request, response) => {
      if (!request.is("text/plain"))
        return response.status(400).send("Expected text/plain content");
      const flags =
        constants.O_WRONLY |
        constants.O_CREAT |
        constants.O_TRUNC |
        constants.O_NOFOLLOW;
      const file = await open(filePath(request.params.filename), flags, 0o600);
      try {
        await file.writeFile(request.body || "", "utf8");
        response.send("File saved successfully");
      } finally {
        await file.close();
      }
    }),
  );

  app.delete(
    "/delete/:filename",
    route(async (request, response) => {
      await unlink(filePath(request.params.filename));
      response.send(`${request.params.filename} has been deleted.`);
    }),
  );

  app.use((error, _request, response, _next) => {
    const status =
      error.status ||
      { ENOENT: 404, EEXIST: 409, ELOOP: 400, EISDIR: 400 }[error.code] ||
      500;
    if (status === 500) console.error("File service:", error);
    const message = {
      404: "File not found",
      409: "File already exists",
      400: "Invalid file or request",
    }[status];
    response
      .status(status)
      .type("text/plain")
      .send(message || "Unable to complete file operation");
  });
  return app;
}

module.exports = { createApp };
