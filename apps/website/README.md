# FANZONE Website

This package is the repo-hosted web build of the canonical FANZONE product UI.

The optional external source of truth can be supplied with `FANZONE_CANONICAL_SOURCE`.
When it is not set, release checks compare `apps/website/src` with the committed canonical snapshot.

`apps/website/src` is not authored independently when an external canonical source is configured. It is synced from that source and guarded against drift.

## Canonical workflow

```bash
cd apps/website
npm ci
npm run sync:canonical
npm run lint
npm run build
```

Available checks:
- `npm run sync:canonical` copies the canonical `src/` tree into `apps/website/src`.
- `npm run check:canonical` fails if `apps/website/src` has drifted from the canonical source or committed snapshot.
- `npm run validate:release-metadata` checks deep-link and manifest metadata before deployment.

## Tech stack

- React 19
- TypeScript
- Vite 8
- React Router
- Zustand
- Motion
- Tailwind via `@tailwindcss/vite`

## Current route map

The current route map is derived from the canonical source app.

| Route | Surface |
| --- | --- |
| `/onboarding` | Onboarding |
| `/` | Home feed |
| `/match/:id` | Match detail |
| `/pools` | Pool discovery |
| `/pools/:slug` | Pool detail |
| `/wallet` | Wallet |
| `/profile` | Profile |
| `/settings` | Settings |
| `/privacy` | Privacy settings |
| `/ordering` | Venue ordering |
| `/v/:slug` | Venue QR ordering |
| `/notifications` | Notifications |
| `*` | Pool discovery fallback |

## Build and preview

```bash
cd apps/website
npm run build
npm run preview
```

The production build runs the canonical drift check before bundling.

## Release metadata

Deep-link files live under `apps/website/public/.well-known/`.

Before any production deploy, run:

```bash
cd apps/website
npm run validate:release-metadata
```

This currently fails if:
- `assetlinks.json` still contains the all-zero Android SHA-256 placeholder.
- `apple-app-site-association` is malformed.
- `site.webmanifest` is missing required FANZONE metadata.

## Deployment notes

The repo currently contains deployment-related assets such as:
- `public/_headers`
- `public/_redirects`
- `.well-known/apple-app-site-association`
- `.well-known/assetlinks.json`

Do not treat these as optional. They are part of release readiness.
