# PWA Checklist

## Public Website

- Manifest present: `apps/website/public/site.webmanifest`.
- Icons present.
- `_headers` present.
- `_redirects` present.
- Canonical URL points to `https://fanzone.ikanisa.com`.
- Privacy and terms routes must be reachable before app-store submission.

## Venue Dashboard

- Manifest present: `apps/venue-portal/public/site.webmanifest`.
- Icons present.
- `_headers` present.
- `_redirects` present.
- Requires `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_GUEST_APP_URL`, and `VITE_TV_DISPLAY_URL`.
- Login must use WhatsApp OTP session.
- No service-role keys in browser env.

## TV Display

- Manifest present: `apps/tv-display/public/site.webmanifest`.
- Icons present.
- `_headers` present.
- `_redirects` present.
- Requires `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_PUBLIC_APP_URL`.
- TV screen must expose display modes only, never venue admin mutation actions.

