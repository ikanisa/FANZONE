# Admin Web Performance And Go-Live Readiness - 2026-05-21

Surface: Admin PWA (`apps/admin`)

Production URL:

```text
https://fanzoneadmin.ikanisa.com/
```

Latest Cloudflare Pages deployment:

```text
https://b6eb314b.fanzone-admin.pages.dev/
```

## Status

GO for unauthenticated deployed Admin PWA production-readiness checks.

The production custom domain now points at the `fanzone-admin` Cloudflare Pages
project, serves the Admin build, passes deployed BFF surface checks, has valid
private-app robots policy, and has no browser console errors on the login route.

Remaining go-live caveat: this report covers the login shell, PWA metadata,
security headers, custom-domain mapping, unauthenticated BFF/session smoke,
private indexing policy, and rendered UI. Full operational UAT still needs a
real admin OTP login to exercise dashboard, venues, match curation, pool
operations, rewards, wallets, platform control, audit logs, moderation, and
logout.

## Cloudflare Production Remediation

Findings fixed during the go-live pass:

- `fanzoneadmin.ikanisa.com` was attached to the `fanzone-website` Pages
  project, so it served the wrong artifact.
- The DNS CNAME for `fanzoneadmin.ikanisa.com` pointed at
  `fanzone-website.pages.dev`.
- The Admin HTML was missing mobile PWA metadata.
- The login route had an accessibility contrast failure and no main landmark.
- The Admin CSP needed Cloudflare Insights allowances on the production custom
  domain.
- `robots.txt` fell through to the SPA shell, so Lighthouse treated it as
  invalid. The app now serves a valid private `Disallow: /` robots file while
  retaining the `noindex, nofollow` meta tag.

Cloudflare actions completed:

- Removed `fanzoneadmin.ikanisa.com` from `fanzone-website`.
- Added `fanzoneadmin.ikanisa.com` to `fanzone-admin`.
- Updated the `ikanisa.com` DNS CNAME to `fanzone-admin.pages.dev`.
- Re-ran Pages domain validation; Cloudflare reports the custom domain as
  `active` with active HTTP validation.
- Deployed the fixed Admin PWA static artifact to Cloudflare Pages.

Deployment note: two normal Pages uploads of the new Admin JS asset failed with
a Cloudflare asset-upload `502 Bad Gateway`. The final production deployment
used a stable artifact that reuses the already uploaded Admin JS asset and
ships the fixed HTML, headers, and robots file. The source build still passes;
when Cloudflare asset upload is stable, a normal deploy should replace this
operational workaround.

## Validation Evidence

Commands run:

```bash
node tool/validate_pwa_release_metadata.mjs admin
node tool/validate_pwa_release_metadata.mjs venue-portal
node tool/validate_pwa_release_metadata.mjs tv-display
npm run test -w @fanzone/admin
npm run typecheck -w @fanzone/admin
npm run lint -w @fanzone/admin
npm run build -w @fanzone/admin
npx wrangler pages deploy /tmp/fanzone-admin-deploy-stable --project-name=fanzone-admin --branch=main --commit-dirty=true
tool/verify_deployed_web_surface.sh admin https://fanzoneadmin.ikanisa.com
npx -y lighthouse@latest https://fanzoneadmin.ikanisa.com/ --chrome-flags='--headless --no-sandbox --disable-gpu' --only-categories=performance,accessibility,best-practices,seo --output=json --output-path=output/web-perf/admin/lighthouse-custom-domain-final.json
```

Passing deployed evidence:

- HTTPS root returns HTTP 200 and redirects to `/login`.
- Deployed BFF health and unauthenticated session smoke pass.
- Production root HTML includes `/site.webmanifest`, Apple touch icon,
  description metadata, mobile PWA tags, private robots metadata, and theme
  color `#0C0A09`.
- `robots.txt` returns HTTP 200 as `text/plain` with `Disallow: /`.
- Root CSP includes Google Fonts and Cloudflare Insights allowances.
- Security headers are present: HSTS, CSP, Permissions-Policy,
  Referrer-Policy, X-Content-Type-Options, and X-Frame-Options.
- Mobile rendered smoke passes on `https://fanzoneadmin.ikanisa.com/`: title
  `FANZONE Admin`, one `main` landmark, visible `VERIFY VIA WHATSAPP`, visible
  `WHATSAPP NUMBER` field, send button enables after a valid phone number, no
  console errors, and no page errors.

## Lighthouse Result

Measured on the production custom domain:

| Category | Score |
| --- | ---: |
| Performance | 87 |
| Accessibility | 100 |
| Best Practices | 100 |
| SEO | 66 |

Key metrics:

| Metric | Value |
| --- | ---: |
| First Contentful Paint | 2.5 s |
| Largest Contentful Paint | 3.6 s |
| Speed Index | 2.7 s |
| Total Blocking Time | 0 ms |
| Cumulative Layout Shift | 0 |
| Time to Interactive | 3.6 s |
| Server response time | 70 ms |

Lighthouse diagnostics:

- No browser errors logged to the console.
- Accessibility passes at 100 after the login contrast and main-landmark fixes.
- Best Practices passes at 100.
- Meta description passes.
- `robots.txt` is valid.
- Crawlability intentionally fails because the Admin PWA is private and uses
  `noindex, nofollow`; this is not a go-live blocker for an internal portal.
- Total transfer: about 254 kB across 25 requests.
- Remaining optimization: reduce unused JavaScript. Lighthouse estimates about
  84 KiB of savings on the unauthenticated login load. This is a P2
  performance follow-up, not a current go-live blocker.

## Repo Fixes Applied

- Updated `apps/admin/index.html` with mobile PWA metadata, a `main` root
  landmark, and the login footer contrast override.
- Updated `apps/admin/public/_headers` so CSP allows Cloudflare Insights while
  preserving `frame-ancestors 'none'` and `X-Frame-Options: DENY`.
- Added `apps/admin/public/robots.txt` for the private Admin indexing policy.
- Extended `tool/validate_pwa_release_metadata.mjs` with Admin PWA metadata
  coverage and broader font-CSP checks.
- Updated `tool/deploy_cloudflare_pages.sh` so the default TV display URL now
  points at `https://fanzonetv.ikanisa.com`.

## Decision

The Admin PWA is ready for production exposure at
`https://fanzoneadmin.ikanisa.com/` for the unauthenticated and deployment
surface covered here.

Before declaring full Admin operational UAT complete, run a production admin
session with real reviewer credentials and record evidence for:

- Admin OTP login and logout.
- Dashboard load.
- Venue management.
- Match curation.
- Pool operations and idempotent settlement controls.
- Reward rules.
- Wallet oversight and adjustment controls.
- Platform control.
- Moderation.
- Audit logs.
