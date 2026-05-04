# TV Screen Deployment Notes

## App

- Source: `apps/tv-display`
- Build: `npm run build -w @fanzone/tv-display`
- Suggested production domain: `https://screen.fanzone.ikanisa.com`
- Current deployed URL: `https://3078ac01.fanzone-tv-display.pages.dev`
- Pages custom-domain binding: created for `screen.fanzone.ikanisa.com` on 2026-05-04.
- Current blocker: DNS CNAME is not set yet, so `screen.fanzone.ikanisa.com` does not resolve.

## DNS Record Required

Create this record in the Cloudflare `ikanisa.com` zone:

- Type: `CNAME`
- Name: `screen`
- Target: `fanzone-tv-display.pages.dev`
- Proxy status: proxied
- TTL: auto

Cloudflare Pages currently reports the custom domain as `pending` with
`CNAME record not set`. The local Wrangler OAuth token can create/read the
Pages custom domain, but DNS record API calls return `403`, so a Cloudflare
token/session with DNS record edit access is required to finish this step.

## Required Env

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `VITE_PUBLIC_APP_URL=https://fanzone.ikanisa.com`

## Supported Routes

- Pairing/default screen.
- Venue-specific screen route.
- QR join display.
- Pool display.
- Game question display.
- Leaderboard and winner displays.

## Production Smoke

1. Completed: root route returns HTTP 200 on Cloudflare Pages.
2. Open TV display on a laptop browser.
3. Open venue dashboard in another browser session.
4. Select a seeded venue.
5. Push welcome, QR, pool, game question, leaderboard, and winner states.
6. Confirm realtime update without refresh.
7. Scan QR from a phone and verify it opens the public app route.
8. Confirm no admin or staff action is available from TV.
