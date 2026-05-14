import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import type { Plugin } from "vite";

function privilegedBffWorkerPlugin(surface: "admin"): Plugin {
  return {
    name: "fanzone-privileged-bff-worker",
    apply: "build",
    generateBundle() {
      const workerCore = readFileSync(
        fileURLToPath(
          new URL(
            "../../packages/core/cloudflare/privileged-bff-worker.js",
            import.meta.url,
          ),
        ),
        "utf8",
      );

      this.emitFile({
        type: "asset",
        fileName: "privileged-bff-worker.js",
        source: workerCore,
      });
      this.emitFile({
        type: "asset",
        fileName: "_worker.js",
        source: [
          "import { createPrivilegedBffWorker } from './privileged-bff-worker.js';",
          `export default createPrivilegedBffWorker({ surface: '${surface}' });`,
        ].join("\n"),
      });
    },
  };
}

// https://vite.dev/config/
export default defineConfig(({ mode }) => ({
  plugins: [react(), privilegedBffWorkerPlugin("admin")],
  base: "/",
  test: {
    environment: "jsdom",
    setupFiles: "./src/test/setup.ts",
  },
  build: {
    outDir: "dist",
    sourcemap: mode !== "production",
  },
}));
