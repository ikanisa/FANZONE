# FANZONE Admin

This directory contains the React/Vite admin console for FANZONE.

The canonical repo documentation lives in the root [README](../README.md). Use that file for architecture, release flow, repository rules, and environment setup across the full stack.

## Local commands

```bash
npm ci
npm run dev
npm run lint
npm run test
npm run build
```

## Required environment

Create `admin/.env` from `admin/.env.example` and set:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Optional local-only toggle:

- `VITE_ALLOW_DEMO_MODE=true`

Important rule: never expose a Supabase service-role key through a `VITE_` variable.
