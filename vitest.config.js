import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["**/*.test.{js,mjs}"],
    exclude: ["**/node_modules/**", "**/Editor/min/**", "**/Editor/vs/**"],
  },
});
