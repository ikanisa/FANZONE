# FANZONE Public Website

Production-grade public website for the FANZONE football prediction and fan engagement platform.

**Live URL**: [fanzone.ikanisa.com](https://fanzone.ikanisa.com)

## Tech Stack

- React 19 + TypeScript
- Vite 8
- React Router 7
- Lucide React (icons)
- Vanilla CSS (Night Sandstone design system)

## Local Development

```bash
cd website
npm ci
npm run dev
```

Open [http://localhost:5173](http://localhost:5173)

## Production Build

```bash
npm run build
npm run preview   # preview the production build locally
```

Build output directory: `dist/`

## Pages

| Route | Page | Description |
|-------|------|-------------|
| `/` | Home | Hero, features, leagues, how-it-works, CTA |
| `/overview` | How it Works | 3-step product walkthrough |
| `/coverage` | Competitions | League cards, AI data, Malta-first |
| `/fet` | FET Token | Token economy, earning paths, governance |
| `/guest-auth` | Guest vs Authenticated | Access comparison, upgrade path |
| `/rewards` | Partner Rewards | Marketplace, redemption flow |
| `/faq` | FAQ | 12 questions with accordion |
| `/privacy` | Privacy Policy | Full 11-section GDPR-compliant policy |
| `/terms` | Terms & Conditions | 13-section production terms |
| `/contact` | Support & Contact | WhatsApp, email, privacy contacts |
| `*` | 404 | Not found page |

## Cloudflare Pages Deployment

### Configuration

| Setting | Value |
|---------|-------|
| **Framework preset** | None |
| **Root directory** | `website/` |
| **Build command** | `npm run build` |
| **Build output directory** | `dist` |
| **Node.js version** | 22 |

### Custom Domain

Target: `fanzone.ikanisa.com`

1. In Cloudflare Pages project settings → Custom domains
2. Add `fanzone.ikanisa.com`
3. Cloudflare will auto-configure DNS if the domain is on Cloudflare
4. If the domain is external, add a CNAME record pointing to the Pages project URL

### SPA Routing

The `public/_redirects` file handles SPA routing:
```
/* /index.html 200
```

This ensures all routes (e.g., `/privacy`, `/faq`) are served correctly on page refresh or direct navigation.

### Security Headers

The `public/_headers` file configures:
- `Strict-Transport-Security` (HSTS with preload)
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Content-Security-Policy`
- `Permissions-Policy` (no camera, mic, geo, payment)
- Asset caching (immutable for `/assets/*`)
- `.well-known/*` CORS for deep linking

### Deep Linking

The `public/.well-known/` directory contains:
- `assetlinks.json` — Android App Links for `app.fanzone.football`
- `apple-app-site-association` — iOS Universal Links

> **Note**: The `assetlinks.json` SHA256 fingerprint is a placeholder. Update with the real upload key fingerprint before production.

## Design System

The website uses the **Night Sandstone** palette aligned with the Flutter mobile app:

| Token | Value | Usage |
|-------|-------|-------|
| `--fz-bg` | `#09090B` | Page background |
| `--fz-surface` | `#131418` | Cards, sections |
| `--fz-accent` | `#22D3EE` | Primary interactive (cyan) |
| `--fz-blue` | `#2563EB` | Secondary interactive |
| `--fz-teal` | `#0F7B6C` | Brand / financial |
| `--fz-success` | `#98FF98` | Wins, positive |
| `--fz-coral` | `#FF7F50` | Pending, warnings |
| `--fz-danger` | `#EF4444` | Errors, LIVE |
| `--fz-text` | `#FDFCF0` | Primary text (cream) |

## TODOs

- [x] ~~Replace WhatsApp support number~~ — wired to `+35699711145`
- [ ] Add real App Store / Google Play URLs when available
- [ ] Update `assetlinks.json` SHA256 fingerprint with real upload key
- [ ] Add OG image for social card preview
- [ ] Configure Cloudflare Pages project and custom domain
