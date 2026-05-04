# Web And PWA Deployment Notes

## Surfaces

- Public PWA / website: `apps/website`
- Admin PWA: `apps/admin`
- Venue dashboard PWA: `apps/venue-portal`
- TV display PWA: `apps/tv-display`

## Hosting

Existing deployment pattern is Cloudflare Pages.

Current deployments from this release pass:
- Public PWA / website: `https://2fdf640b.fanzone-website.pages.dev`
- Admin PWA: `https://d68abe9b.fanzone-admin.pages.dev`
- Venue dashboard PWA: `https://945a5815.fanzone-venue-portal.pages.dev`
- TV display PWA: `https://3078ac01.fanzone-tv-display.pages.dev`
- Production public domain smoke: `https://fanzone.ikanisa.com` returns HTTP 200.
- TV custom domain `https://screen.fanzone.ikanisa.com` has a Cloudflare Pages custom-domain binding, but still needs the `screen` CNAME in the `ikanisa.com` DNS zone.

Primary deploy path:
- `tool/deploy_cloudflare_pages.sh all`
- `tool/deploy_cloudflare_pages.sh website`
- `tool/deploy_cloudflare_pages.sh admin`
- `tool/deploy_cloudflare_pages.sh venue-portal`
- `tool/deploy_cloudflare_pages.sh tv-display`

The GitHub Actions deploy workflows are manual-only fallbacks. They do not run on push because the project uses the free-account release model and does not depend on GitHub-hosted runners.

## Required Local Env

- Cloudflare Wrangler login, or `CLOUDFLARE_API_TOKEN` plus `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_WEBSITE_PROJECT_NAME` if not using the default `fanzone-website`
- `CLOUDFLARE_ADMIN_PROJECT_NAME` if not using the default `fanzone-admin`
- `CLOUDFLARE_VENUE_PORTAL_PROJECT_NAME` if not using the default `fanzone-venue-portal`
- `CLOUDFLARE_TV_DISPLAY_PROJECT_NAME` if not using the default `fanzone-tv-display`
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `VITE_GUEST_APP_URL`
- `VITE_PUBLIC_APP_URL`
- `VITE_TV_DISPLAY_URL`

Never put Supabase service-role keys, database URLs, WhatsApp access tokens, or cron secrets in any `VITE_` variable.

## Local Build Commands

```bash
npm ci
npm run build -w @fanzone/website
npm run build -w @fanzone/admin
npm run build -w @fanzone/venue-portal
npm run build -w @fanzone/tv-display
tool/deploy_cloudflare_pages.sh all
```

## Production Smoke

- Completed: HTTP 200 smoke for all four Cloudflare Pages deployment roots and production public root.
- Still required: authenticated route smoke using real reviewer/staff accounts.
- Refresh deep routes on each PWA.
- Confirm manifest and icons load.
- Confirm Supabase config guard appears if env vars are missing.
- Confirm no client bundle contains service-role keys.
- Confirm dashboard login resolves venue membership.
- Confirm TV `/venue/:venueId` renders the selected venue state.
