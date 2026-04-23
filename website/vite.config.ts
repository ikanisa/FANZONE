import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          const normalized = id.replaceAll('\\', '/')

          if (normalized.includes('/node_modules/')) {
            if (
              normalized.includes('/react/') ||
              normalized.includes('/react-dom/') ||
              normalized.includes('/react-router-dom/')
            ) {
              return 'react-vendor'
            }

            if (normalized.includes('/motion/')) {
              return 'motion-vendor'
            }

            if (normalized.includes('/lucide-react/')) {
              return 'icons-vendor'
            }

            if (
              normalized.includes('/react-markdown/') ||
              normalized.includes('/remark-') ||
              normalized.includes('/mdast-') ||
              normalized.includes('/micromark/') ||
              normalized.includes('/unified/') ||
              normalized.includes('/hast-') ||
              normalized.includes('/vfile/')
            ) {
              return 'markdown-vendor'
            }

            if (
              normalized.includes('/zustand/') ||
              normalized.includes('/canvas-confetti/')
            ) {
              return 'app-vendor'
            }

            return 'vendor'
          }

          if (normalized.includes('/website/src/store/')) {
            return 'app-store'
          }

          if (
            normalized.includes('/website/src/lib/') ||
            normalized.includes('/website/src/services/')
          ) {
            return 'app-core'
          }

          if (normalized.includes('/website/src/components/ui/')) {
            return 'ui-components'
          }

          if (
            normalized.includes('/website/src/components/Layout') ||
            normalized.includes('/website/src/components/Splash') ||
            normalized.includes('/website/src/components/Onboarding')
          ) {
            return 'app-shell'
          }

          if (
            normalized.includes('/website/src/components/HomeFeed') ||
            normalized.includes('/website/src/components/MatchDetail') ||
            normalized.includes('/website/src/components/LeagueHub') ||
            normalized.includes('/website/src/components/Fixtures') ||
            normalized.includes('/website/src/components/Notifications')
          ) {
            return 'match-experience'
          }

          if (
            normalized.includes('/website/src/components/WalletHub') ||
            normalized.includes('/website/src/components/Profile') ||
            normalized.includes('/website/src/components/Settings') ||
            normalized.includes('/website/src/components/PrivacySettings')
          ) {
            return 'account-experience'
          }

          if (
            normalized.includes('/website/src/components/Leaderboard') ||
            normalized.includes('/website/src/components/TeamProfile') ||
            normalized.includes('/website/src/components/EmptyErrorStates')
          ) {
            return 'community-experience'
          }

          return undefined
        },
      },
    },
  },
})
