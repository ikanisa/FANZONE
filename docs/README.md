# FANZONE Production Documentation

This directory is the release-readiness entry point for FANZONE, the sports-bar entertainment platform for venues, lounges, fan zones, and hospitality operators.

FANZONE uses the standalone `FANZONEUI` export as the primary UI and product reference for the Flutter client. Production implementation must wire those concepts to real app data, Supabase gateways, loading states, and empty states rather than static mock export data. The current production surface includes guest venue discovery, bar ordering, off-platform payment guidance, manual payment confirmation, FET rewards, FET wallets, Arena pools, admin curation, settlement, audit, and operations tooling.

## One-Hour Senior Developer Onboarding

Read these documents in order:

1. [Architecture Overview](architecture/overview.md)
2. [Apps](architecture/apps.md)
3. [Backend](architecture/backend.md)
4. [Permissions And RLS](security/permissions-rls.md)
5. [Audit Logs](security/audit-logs.md)
6. [Admin Guide](operations/admin-guide.md)
7. [Channels](integrations/channels.md)
8. [Payments](integrations/payments.md)
9. [Go-Live Checklist](release/go-live-checklist.md)
10. [Rollback](release/rollback.md)
11. [QA/UAT](testing/qa-uat.md)
12. [Incident Runbooks](operations/incident-runbooks.md)
13. [Flutter Review PWA](REVIEW_PWA_GUIDE.md)
14. [UI Review Protocol](UI_REVIEW_PROTOCOL.md)

## Repository Map

| Path | Purpose |
| --- | --- |
| `lib/` | Flutter mobile app. |
| `apps/website/` | React/Vite guest PWA and public web surface. |
| `apps/venue-portal/` | React/Vite venue operations console. |
| `apps/admin/` | React/Vite admin control center. |
| `packages/core/` | Shared TypeScript contracts. |
| `supabase/migrations/` | Schema, RLS, views, triggers, and RPC migrations. |
| `supabase/functions/` | Supabase Edge Functions. |
| `supabase/tests/` | SQL verification scripts. |
| `env/*.example.json` | Example Flutter runtime config. Real `env/*.json` files are ignored. |
| `.github/workflows/` | CI, deploy, cron, and secret scan workflows. |

## Required Environment Variables

No live secrets belong in git.

| Variable | Used by | Notes |
| --- | --- | --- |
| `SUPABASE_URL` | Flutter, Edge Functions, smoke scripts | Public project URL. |
| `SUPABASE_ANON_KEY` | Flutter, web apps, smoke scripts | Public anon key. Never use service role in clients. |
| `VITE_SUPABASE_URL` | Admin, website, venue portal, TV display | Browser-safe Supabase URL. |
| `VITE_SUPABASE_ANON_KEY` | Admin, website, venue portal, TV display | Browser-safe anon key. |
| `VITE_PRIVILEGED_SESSION_MODE` | Admin, venue portal | Use `bff` in production. `browser` is only for local development without Cloudflare Pages Functions. |
| `VITE_GUEST_APP_URL` | Venue portal | Base URL for table QR deep links. |
| `VITE_PUBLIC_APP_URL` | TV display | Base URL used in TV QR joins. |
| `VITE_TV_DISPLAY_URL` | Venue portal | Base URL for venue screen links. |
| `SUPABASE_SERVICE_ROLE_KEY` or `EDGE_SERVICE_ROLE_KEY` | Edge Functions | Server only. Never expose through `VITE_` or Flutter config. |
| `CRON_SECRET` | Cron Edge Functions | Required for scheduled jobs. |
| `PUSH_NOTIFY_SECRET` | Push notification dispatch | Internal shared secret. |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | `push-notify` | Firebase service account JSON. |
| `GEMINI_API_KEY` | menu OCR/import | AI OCR provider key. |
| `FANZONE_JWT_SECRET` | `whatsapp-otp` | JWT signing secret for custom WhatsApp sessions. |
| `FANZONE_EDGE_ALLOWED_ORIGINS` | Edge Functions | Comma-separated browser origins allowed to call Edge Functions. |
| `FANZONE_EDGE_ALLOW_WILDCARD_CORS` | Edge Functions | Keep `false` in production; wildcard CORS requires explicit opt-in. |
| `WHATSAPP_AUTH_TEST_PHONE`, `WHATSAPP_AUTH_TEST_OTP`, `WHATSAPP_AUTH_TEST_EXPIRY` | reviewer/test OTP path | Optional controlled test account only. |
| `FANZONE_EDGE_EXPOSE_ERROR_DETAILS` | Edge shared errors | Keep false in production. |
| `SUPABASE_DB_URL`, `SUPABASE_DB_PASSWORD` | SQL smoke scripts | Operator-only local shell or CI secret. If absent locally, linked Supabase CLI validation can run through `supabase db query --linked`. |

## Known Issues Classified

| Item | Classification | Required action |
| --- | --- | --- |
| Website release metadata can fail if `assetlinks.json` still has the all-zero fingerprint. | Release blocker | Replace with production Android SHA-256 before public web deploy. |
| `supabase db lint --local` needs local Supabase Postgres on `127.0.0.1:54322`. | Local environment blocker | Run `supabase start`, use `SUPABASE_DB_URL`, or run `tool/supabase_live_validation.sh` with an authenticated linked Supabase CLI profile. |
| Production `env/*.json`, signing files, and Firebase files are ignored. | Expected security posture | Supply through secure local store or CI secrets. |
| Supabase credentials were shared in an assistant conversation during release work. | Release blocker | Rotate the access token, database password, anon key, and service-role key before production launch. |
| No in-repo production agent workspaces were found. | Intentional | Use [Agents](architecture/agents.md) and [Agent Ops](operations/agent-ops.md) before adding one. |
| Payment APIs are absent. | Product rule | Payments remain cash, MoMo/USSD, or Revolut link handoff with audited manual confirmation. |

## Roadmap

1. Launch hardening: rotate exposed Supabase credentials, finish release metadata, supply store signing/Firebase files, and complete venue/admin/guest UAT.
2. Operational scale: add settlement latency, wallet ledger drift, QR scan conversion, and failed Edge Function alerts.
3. Market expansion: add country-specific copy, currency display rules, venue onboarding templates, and curated match playbooks.
4. Agent readiness: add explicit agent workspaces only after permissions, tool scopes, memory boundaries, and audit outputs are reviewed.
