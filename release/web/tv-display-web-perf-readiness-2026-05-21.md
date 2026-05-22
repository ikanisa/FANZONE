# TV Display Web Performance And Go-Live Readiness - 2026-05-21

Surface: TV PWA (`apps/tv-display`)

Production URL:

```text
https://fanzonetv.ikanisa.com/
```

Latest Cloudflare Pages deployment:

```text
https://fff48299.fanzone-tv-display.pages.dev/
```

## Status

GO for unauthenticated deployed TV PWA production-readiness checks.

The production custom domain now points at the `fanzone-tv-display`
Cloudflare Pages project, serves the current TV build, passes deployed surface
checks, and has no browser console errors on the pairing route.

Remaining go-live caveat: this report covers the pairing shell, PWA metadata,
security headers, custom-domain mapping, route transition behavior, and
unauthenticated rendered UI. Full operational UAT still needs a production
venue slug with active screen state to exercise welcome, QR, pool, game,
leaderboard, winners, menu, and promo modes.

## Cloudflare Production Remediation

Findings fixed during the go-live pass:

- `fanzonetv.ikanisa.com` was attached to the `fanzone-website` Pages project,
  so it served the wrong artifact.
- The DNS CNAME for `fanzonetv.ikanisa.com` pointed at
  `fanzone-website.pages.dev`.
- The TV Display CSP blocked Google Fonts used by `src/index.css`.
- The production custom domain needed Cloudflare Insights allowances in CSP.

Cloudflare actions completed:

- Removed `fanzonetv.ikanisa.com` from `fanzone-website`.
- Added `fanzonetv.ikanisa.com` to `fanzone-tv-display`.
- Updated the `ikanisa.com` DNS CNAME to `fanzone-tv-display.pages.dev`.
- Re-ran Pages domain validation; Cloudflare reports the custom domain as
  `active` with active HTTP validation.
- Deployed the fixed TV PWA build to Cloudflare Pages.

## Validation Evidence

Commands run:

```bash
npm run test -w @fanzone/tv-display
npm run typecheck -w @fanzone/tv-display
npm run lint -w @fanzone/tv-display
npm run build -w @fanzone/tv-display
tool/deploy_cloudflare_pages.sh tv-display --allow-dirty
tool/verify_deployed_web_surface.sh tv-display https://fanzonetv.ikanisa.com
npx -y lighthouse@latest https://fanzonetv.ikanisa.com/ --chrome-flags='--headless --no-sandbox --disable-gpu' --only-categories=performance,accessibility,best-practices,seo --output=json --output-path=output/web-perf/tv-display/lighthouse-custom-domain-final.json
```

Passing deployed evidence:

- HTTPS root returns HTTP 200.
- Production root HTML includes `/site.webmanifest`, Apple touch icon,
  description metadata, mobile PWA tags, and theme color `#050507`.
- Root CSP includes Google Fonts and Cloudflare Insights allowances.
- Security headers are present: HSTS, CSP, Permissions-Policy,
  Referrer-Policy, X-Content-Type-Options, and X-Frame-Options.
- `X-Frame-Options: SAMEORIGIN` is retained for controlled same-origin TV
  embedding behavior.
- TV-sized rendered smoke passes on `https://fanzonetv.ikanisa.com/`: title
  `TV Display | FANZONE`, visible `Venue live screen`, visible
  `Venue ID or slug` field, visible `Pair Display` button, manifest link
  present, no console errors, and no page errors.
- Pairing interaction transitions from `/` to `/venue/uat-live-sports-bar`
  without a blank screen or runtime errors. The production dataset did not
  resolve that UAT slug, so authenticated/seeded venue-state UAT remains open.

## Lighthouse Result

Measured on the production custom domain:

| Category | Score |
| --- | ---: |
| Performance | 94 |
| Accessibility | 100 |
| Best Practices | 100 |
| SEO | 92 |

Key metrics:

| Metric | Value |
| --- | ---: |
| First Contentful Paint | 2.3 s |
| Largest Contentful Paint | 2.4 s |
| Speed Index | 2.4 s |
| Total Blocking Time | 120 ms |
| Cumulative Layout Shift | 0.001 |
| Time to Interactive | 3.3 s |
| Server response time | 60 ms |

Lighthouse diagnostics:

- No browser errors logged to the console.
- Meta description passes.
- Crawlability passes on the custom domain.
- Total transfer: about 236 kB across 17 requests.
- Remaining optimization: reduce unused JavaScript. Lighthouse estimates about
  72 KiB of savings on the pairing load. This is a P2 performance follow-up,
  not a current go-live blocker.

## Repo Fixes Applied

- Updated `apps/tv-display/public/_headers` so CSP allows:
  - Google Fonts stylesheet and font files used by `src/index.css`.
  - Cloudflare Insights script and beacon endpoint used on the production
    custom domain.

## Decision

The TV PWA is ready for production exposure at `https://fanzonetv.ikanisa.com/`
for the unauthenticated and deployment surface covered here.

Before declaring full operational TV UAT complete, run a production venue-screen
session with a real venue slug and record evidence for:

- Pairing a real production venue.
- Welcome mode.
- QR join mode.
- Pool mode.
- Game lobby and question modes.
- Leaderboard and winners modes.
- Menu and promo modes.
- Realtime refresh after the Bar PWA changes screen state.
