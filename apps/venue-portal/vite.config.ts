import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import type { Plugin } from "vite";

function privilegedBffWorkerPlugin(surface: "venue"): Plugin {
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

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss(), privilegedBffWorkerPlugin("venue")],
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (!id.includes("node_modules")) return undefined;
          if (id.includes("@supabase")) return "vendor-supabase";
          if (id.includes("lucide-react")) return "vendor-icons";
          if (
            id.includes("/react/") ||
            id.includes("/react-dom/") ||
            id.includes("/react-router-dom/")
          ) {
            return "vendor-react";
          }
          return "vendor";
        },
      },
    },
  },
  server: {
    port: 5175,
  },
});
