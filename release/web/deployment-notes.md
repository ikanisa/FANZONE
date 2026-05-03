# Web And PWA Deployment Notes

## Surfaces

- Public PWA / website: `apps/website`
- Admin PWA: `apps/admin`
- Venue dashboard PWA: `apps/venue-portal`
- TV display PWA: `apps/tv-display`

## Hosting

Existing deployment pattern is Cloudflare Pages.

Current deployments from this release pass:
- Public PWA / website: `https://fanzone.ikanisa.com` and `https://fanzone-website.pages.dev`
- Admin PWA: `https://fanzone-admin.pages.dev`
- Venue dashboard PWA: `https://fanzone-venue-portal.pages.dev`
- TV display PWA: `https://fanzone-tv-display.pages.dev`

Configured workflows:
- `.github/workflows/deploy-website.yml`
- `.github/workflows/deploy-admin.yml`
- `.github/workflows/deploy-venue-portal.yml`
- `.github/workflows/deploy-tv-display.yml`

## Required GitHub Secrets

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_WEBSITE_PROJECT_NAME`
- `CLOUDFLARE_VENUE_PORTAL_PROJECT_NAME`
- `CLOUDFLARE_TV_DISPLAY_PROJECT_NAME`
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
```

## Production Smoke

- Completed: HTTP 200 smoke for website root, website `/privacy`, admin root, venue dashboard root, and TV display root.
- Still required: authenticated route smoke using real reviewer/staff accounts.
- Refresh deep routes on each PWA.
- Confirm manifest and icons load.
- Confirm Supabase config guard appears if env vars are missing.
- Confirm no client bundle contains service-role keys.
- Confirm dashboard login resolves venue membership.
- Confirm TV `/venue/:venueId` renders the selected venue state.
