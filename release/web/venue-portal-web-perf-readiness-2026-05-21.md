# Venue Portal Web Performance And Go-Live Readiness - 2026-05-21

Surface: Bar/Venue PWA (`apps/venue-portal`)

Production URL:

```text
https://fanzone.venue.ikanisa.com/
```

Latest Cloudflare Pages deployment:

```text
https://0855d05c.fanzone-venue-portal.pages.dev/
```

## Status

GO for unauthenticated deployed Bar PWA production-readiness checks.

The production custom domain now points at the `fanzone-venue-portal`
Cloudflare Pages project, serves the current PWA build, passes deployed BFF
surface checks, and has no browser console errors on the login screen.

Remaining go-live caveat: this report covers the public/login shell, PWA
metadata, security headers, BFF health/session smoke, custom-domain mapping,
and unauthenticated rendered UI. A staffed authenticated venue UAT still needs
real reviewer OTP access to exercise live orders, manual mark-paid, menu,
rewards, pools, wallet, and TV-screen control flows.

## Cloudflare Production Remediation

Findings fixed during the go-live pass:

- `fanzone.venue.ikanisa.com` was attached to the `fanzone-website` Pages
  project, so it served the wrong artifact.
- The DNS CNAME for `fanzone.venue.ikanisa.com` pointed at
  `fanzone-website.pages.dev`.
- The Venue Portal CSP allowed Google Fonts after the repo fix, but the
  custom domain also needed to allow Cloudflare Insights on
  `static.cloudflareinsights.com`.

Cloudflare actions completed:

- Removed `fanzone.venue.ikanisa.com` from `fanzone-website`.
- Added `fanzone.venue.ikanisa.com` to `fanzone-venue-portal`.
- Updated the `ikanisa.com` DNS CNAME to
  `fanzone-venue-portal.pages.dev`.
- Re-ran Pages domain validation; Cloudflare reports the custom domain as
  `active` with active HTTP validation.
- Deployed the fixed Bar PWA build to Cloudflare Pages.

## Validation Evidence

Commands run:

```bash
npm run test -w @fanzone/venue-portal
npm run typecheck -w @fanzone/venue-portal
npm run lint -w @fanzone/venue-portal
npm run build -w @fanzone/venue-portal
tool/deploy_cloudflare_pages.sh venue-portal --allow-dirty
tool/verify_deployed_web_surface.sh venue-portal https://fanzone.venue.ikanisa.com
npx -y lighthouse@latest https://fanzone.venue.ikanisa.com/ --chrome-flags='--headless --no-sandbox --disable-gpu' --only-categories=performance,accessibility,best-practices,seo --output=json --output-path=output/web-perf/venue-portal/lighthouse-custom-domain-final.json
```

Passing deployed evidence:

- HTTPS root returns HTTP 200.
- BFF health and unauthenticated session smoke pass.
- Production root HTML includes `/site.webmanifest`, Apple touch icon,
  description metadata, mobile PWA tags, and theme color `#050507`.
- Root CSP includes Google Fonts and Cloudflare Insights allowances.
- Security headers are present: HSTS, CSP, Permissions-Policy,
  Referrer-Policy, X-Content-Type-Options, and X-Frame-Options.
- Mobile rendered smoke passes on `https://fanzone.venue.ikanisa.com/`:
  title `Venue Portal | FANZONE`, visible `Sign in with WhatsApp`, visible
  `WhatsApp phone` field, manifest link present, no console errors, and no
  page errors.

## Lighthouse Result

Measured on the production custom domain:

| Category | Score |
| --- | ---: |
| Performance | 90 |
| Accessibility | 100 |
| Best Practices | 100 |
| SEO | 91 |

Key metrics:

| Metric | Value |
| --- | ---: |
| First Contentful Paint | 2.7 s |
| Largest Contentful Paint | 2.9 s |
| Speed Index | 2.8 s |
| Total Blocking Time | 70 ms |
| Cumulative Layout Shift | 0 |
| Time to Interactive | 2.9 s |
| Server response time | 50 ms |

Lighthouse diagnostics:

- No browser errors logged to the console.
- Meta description passes.
- Crawlability passes on the custom domain.
- Total transfer: about 256 kB across 15 requests.
- Remaining optimization: reduce unused JavaScript. Lighthouse estimates about
  149 KiB of savings on the unauthenticated login load. This is a P2
  performance follow-up, not a current go-live blocker.

## Repo Fixes Applied

- Updated `apps/venue-portal/public/_headers` so CSP allows:
  - Google Fonts stylesheet and font files used by `src/index.css`.
  - Cloudflare Insights script and beacon endpoint used on the production
    custom domain.
- Extended `tool/validate_pwa_release_metadata.mjs` to fail when a PWA imports
  Google Fonts but its CSP does not allow `fonts.googleapis.com` and
  `fonts.gstatic.com`.
- Added `apps/venue-portal/DESIGN.md` as the Bar PWA semantic design-system
  source of truth.

## Decision

The Bar/Venue PWA is ready for production exposure at
`https://fanzone.venue.ikanisa.com/` for the unauthenticated and deployment
surface covered here.

Before declaring full operational UAT complete, run an authenticated venue
staff session against the same production URL and record evidence for:

- Staff OTP login and logout.
- Venue context load.
- Live order queue.
- Order detail and manual mark-paid.
- Menu management.
- Rewards settings.
- Pools and game sessions.
- Wallet display behavior.
- TV screen control handoff.
