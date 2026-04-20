# FANZONE Website

This package is the repo-hosted web build of the canonical FANZONE product UI.

The non-negotiable source of truth is:
- `/Users/jeanbosco/Downloads/FANZONE`

`website/src` is not authored independently. It is synced from that canonical source and guarded against drift.

## Canonical workflow

```bash
cd website
npm ci
npm run sync:canonical
npm run lint
npm run build
```

Available checks:
- `npm run sync:canonical` copies the canonical `src/` tree into `website/src`.
- `npm run check:canonical` fails if `website/src` has drifted from the canonical source.
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

The current route map is derived from the canonical source app and includes:

| Route | Surface |
| --- | --- |
| `/onboarding` | Onboarding |
| `/` | Home feed |
| `/match/:id` | Match detail |
| `/league/:id` | League hub |
| `/leaderboard` | Leaderboard |
| `/wallet` | Wallet |
| `/profile` | Profile |
| `/pools` | Pools hub |
| `/pools/create` | Pool creation |
| `/pool/:id` | Pool detail |
| `/social` | Social hub |
| `/settings` | Settings |
| `/memberships` | Membership hub |
| `/team/:id` | Team profile |
| `/fan-id` | Fan ID |
| `/privacy` | Privacy settings |
| `/fixtures` | Fixtures |
| `/notifications` | Notifications |
| `/rewards` | Rewards store |
| `/jackpot` | Jackpot pool |
| `/error` | Empty / error states |

## Build and preview

```bash
cd website
npm run build
npm run preview
```

The production build runs the canonical drift check before bundling.

## Release metadata

Deep-link files live under `website/public/.well-known/`.

Before any production deploy, run:

```bash
cd website
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
