import { describe, it, expect, beforeAll, afterAll, beforeEach } from "vitest";
import { createRequire } from "module";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const require = createRequire(import.meta.url);
const supertest = require("supertest");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const solaraTabDir = path.join(__dirname, "SolaraTab");
const testFileName = "test-file";
const testFileNameWithExt = `${testFileName}.lua`;

// Dynamically require the CJS Express app
const app = require("./app.js");

describe("fileaccess Express app", () => {
  beforeAll(async () => {
    await fs.promises.mkdir(solaraTabDir, { recursive: true });
  });

  beforeEach(async () => {
    // Clean up test files before each test
    const files = await fs.promises.readdir(solaraTabDir);
    for (const file of files) {
      if (file.startsWith("test-")) {
        await fs.promises.unlink(path.join(solaraTabDir, file)).catch(() => {});
      }
    }
  });

  afterAll(async () => {
    // Clean up test files
    const files = await fs.promises.readdir(solaraTabDir);
    for (const file of files) {
      if (file.startsWith("test-")) {
        await fs.promises.unlink(path.join(solaraTabDir, file)).catch(() => {});
      }
    }
  });

  describe("GET /files", () => {
    it("returns a JSON array of files", async () => {
      const res = await supertest(app).get("/files");
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
    });

    it("includes file name and createdAt for each file", async () => {
      const res = await supertest(app).get("/files");
      expect(res.status).toBe(200);
      for (const file of res.body) {
        expect(file).toHaveProperty("name");
        expect(file).toHaveProperty("createdAt");
      }
    });

    it("sets CORS headers", async () => {
      const res = await supertest(app).get("/files");
      expect(res.headers["access-control-allow-origin"]).toBe("*");
    });
  });

  describe("POST /addtab/:filename", () => {
    it("creates a new .lua file", async () => {
      const res = await supertest(app).post(`/addtab/${testFileName}`);
      expect(res.status).toBe(201);
      expect(res.text).toContain(`${testFileName}.lua has been created`);

      const exists = fs.existsSync(path.join(solaraTabDir, testFileNameWithExt));
      expect(exists).toBe(true);
    });

    it("returns 409 if file already exists", async () => {
      await fs.promises.writeFile(path.join(solaraTabDir, testFileNameWithExt), "");
      const res = await supertest(app).post(`/addtab/${testFileName}`);
      expect(res.status).toBe(409);
      expect(res.text).toContain("already exists");
    });
  });

  describe("GET /opentab/:filename", () => {
    it("returns file content", async () => {
      const content = "-- hello lua";
      await fs.promises.writeFile(path.join(solaraTabDir, testFileNameWithExt), content);

      const res = await supertest(app).get(`/opentab/${testFileNameWithExt}`);
      expect(res.status).toBe(200);
      expect(res.text).toBe(content);
    });

    it("returns 500 for non-existent file", async () => {
      const res = await supertest(app).get("/opentab/nonexistent.lua");
      expect(res.status).toBe(500);
    });
  });

  describe("POST /savetab/:filename", () => {
    it("saves content to file", async () => {
      await fs.promises.writeFile(path.join(solaraTabDir, testFileNameWithExt), "");

      const newContent = "print('hello world')";
      const res = await supertest(app)
        .post(`/savetab/${testFileNameWithExt}`)
        .set("Content-Type", "text/plain")
        .send(newContent);

      expect(res.status).toBe(200);
      expect(res.text).toBe("File saved successfully");

      const saved = await fs.promises.readFile(path.join(solaraTabDir, testFileNameWithExt), "utf8");
      expect(saved).toBe(newContent);
    });
  });

  describe("DELETE /delete/:filename", () => {
    it("deletes an existing file", async () => {
      await fs.promises.writeFile(path.join(solaraTabDir, testFileNameWithExt), "");

      const res = await supertest(app).delete(`/delete/${testFileNameWithExt}`);
      expect(res.status).toBe(200);
      expect(res.text).toContain("has been deleted");

      const exists = fs.existsSync(path.join(solaraTabDir, testFileNameWithExt));
      expect(exists).toBe(false);
    });

    it("returns 500 for non-existent file", async () => {
      const res = await supertest(app).delete("/delete/nonexistent.lua");
      expect(res.status).toBe(500);
    });
  });
});
