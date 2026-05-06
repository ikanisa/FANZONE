# Go-Live Checklist

Use this checklist for production launch or major release promotion.

## Code And Builds

- Root Node workspaces install from lockfile.
- `npm run typecheck --workspaces --if-present` passes.
- `npm run lint --workspaces --if-present` passes or all failures are approved release blockers.
- `npm run test --workspaces --if-present` passes.
- `npm run build --workspaces --if-present` passes.
- `flutter analyze` passes.
- `flutter test` passes.
- Android and iOS release builds use ignored production config and signing files.

## Supabase

- Confirm target project ref and environment.
- Backup production database before destructive or high-risk migration work.
- Run `supabase db push` from a clean branch.
- Run `supabase db push --dry-run` and confirm the target database is up to date.
- Run `supabase db lint --db-url "$SUPABASE_DB_URL" --schema public --fail-on error` against the release target.
- Run SQL verification scripts in `supabase/tests/`.
- Confirm new RPC grants are least privilege.
- Confirm RLS remains enabled on client-exposed tables.
- Confirm Edge Function secrets are configured.
- Confirm `FANZONE_EDGE_ALLOWED_ORIGINS` contains the production website, admin, venue portal, and TV display origins.
- Confirm `FANZONE_EDGE_ALLOW_WILDCARD_CORS=false`.
- Deploy required Edge Functions.
- Rotate any Supabase access tokens, database passwords, anon keys, and service-role keys that were copied into chats, tickets, logs, or terminals outside approved secret storage.

## Web And PWA

- Admin app build passes.
- Website app build passes and canonical check passes.
- Venue portal build passes.
- TV display build passes.
- Website release metadata validation passes.
- Cloudflare Pages projects exist and `tool/deploy_cloudflare_pages.sh all` succeeds from a local/free release machine.
- Browser smoke tests confirm Edge Function CORS from website, admin, venue portal, and TV display production origins.
- Android `assetlinks.json` has production SHA-256 fingerprints.
- Apple app site association is valid.
- PWA manifest names, icons, start URL, and theme color are final.

## Mobile

- `env/production.json` is supplied locally/CI and not committed.
- Android keystore and Play service account are supplied securely.
- iOS `GoogleService-Info.plist` and signing config are supplied securely.
- Deep links open QR order flow from cold and warm app states.
- Anonymous session, WhatsApp OTP upgrade, wallet, ordering, and pool flows pass UAT.

## Operations

- Admin users and emergency owners are configured.
- Venue owner/manager/staff test accounts are configured.
- Guest UAT accounts and QR/table fixtures are configured.
- Supabase/platform cron or local scheduled jobs call `tool/run_supabase_cron_job.sh settle-match-pools` and `tool/run_supabase_cron_job.sh dispatch-match-alerts`.
- Push notification credentials are present.
- WhatsApp OTP reviewer/test values are configured only when required.
- Incident response owner and escalation channel are named.
- Incident runbooks in `docs/operations/incident-runbooks.md` are reviewed by the release owner.
- Rollback point is tagged.

## Monitoring

- Edge Function errors watched after deploy.
- Auth error rate watched after deploy.
- Order creation and payment status updates watched after deploy.
- Pool settlement success/failure watched after deploy.
- Wallet ledger anomalies watched after deploy.
- Push notification failures watched after deploy.
- Database CPU, connections, slow queries, and Realtime load watched after deploy.

## Launch Decision

Do not launch with:

- failing migrations;
- failing wallet or settlement verification;
- missing RLS verification;
- missing production release metadata;
- enabled demo mode in admin;
- service-role keys in client config;
- untested rollback path;
- wildcard Edge Function CORS in production.
