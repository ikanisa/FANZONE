import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          const normalized = id.replaceAll("\\", "/");

          if (normalized.includes("/node_modules/")) {
            if (
              normalized.includes("/react/") ||
              normalized.includes("/react-dom/") ||
              normalized.includes("/react-router-dom/")
            ) {
              return "react-vendor";
            }

            if (normalized.includes("/motion/")) {
              return "motion-vendor";
            }

            if (normalized.includes("/lucide-react/")) {
              return "icons-vendor";
            }

            if (
              normalized.includes("/zustand/") ||
              normalized.includes("/canvas-confetti/")
            ) {
              return "app-vendor";
            }

            return "vendor";
          }

          if (normalized.includes("/website/src/store/")) {
            return "app-store";
          }

          if (
            normalized.includes("/website/src/lib/") ||
            normalized.includes("/website/src/services/")
          ) {
            return "app-core";
          }

          if (normalized.includes("/website/src/components/ui/")) {
            return "ui-components";
          }

          if (
            normalized.includes("/website/src/components/Layout") ||
            normalized.includes("/website/src/components/Splash") ||
            normalized.includes("/website/src/components/Onboarding")
          ) {
            return "app-shell";
          }

          if (
            normalized.includes("/website/src/components/HomeFeed") ||
            normalized.includes("/website/src/components/MatchDetail") ||
            normalized.includes("/website/src/components/MatchPools") ||
            normalized.includes("/website/src/components/Pools") ||
            normalized.includes("/website/src/components/Ordering") ||
            normalized.includes("/website/src/components/Notifications")
          ) {
            return "match-experience";
          }

          if (
            normalized.includes("/website/src/components/WalletHub") ||
            normalized.includes("/website/src/components/Profile") ||
            normalized.includes("/website/src/components/Settings") ||
            normalized.includes("/website/src/components/PrivacySettings")
          ) {
            return "account-experience";
          }

          return undefined;
        },
      },
    },
  },
});
