import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";

export default defineConfig({
  root: "src",
  cacheDir: "../node_modules/.vite",
  base: "./",
  plugins: [svelte({ configFile: "../svelte.config.js" })],
  build: {
    outDir: "../dist",
    emptyOutDir: true,
    target: "es2022",
    sourcemap: true
  }
});
