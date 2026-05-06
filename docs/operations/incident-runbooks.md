# Incident Runbooks

Use these runbooks for production incidents. Record the incident owner, start
time, affected environment, customer impact, actions taken, and follow-up issue.

## Auth Outage

Signals:
- WhatsApp OTP send/verify errors increase.
- Supabase Auth errors increase.
- Admin or venue portal login fails for valid users.

Immediate actions:
1. Check Supabase Auth status and Edge Function logs for `whatsapp-otp`.
2. Confirm `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `FANZONE_JWT_SECRET`, WhatsApp API secrets, and `FANZONE_EDGE_ALLOWED_ORIGINS` are present in the target environment.
3. Run `tool/supabase_whatsapp_auth_smoke.sh` against staging or production as appropriate.
4. If OTP send fails but existing sessions still work, pause new user onboarding and communicate degraded auth.
5. If token verification is broken, roll back the last `whatsapp-otp` deploy from the release tag.

Recovery checks:
- OTP send succeeds.
- OTP verify returns a session.
- Admin and venue users can sign in.
- Error rate returns to baseline for 30 minutes.

## Database Migration Failure

Signals:
- `supabase db push` fails.
- SQL verification scripts fail.
- App errors start after a migration.

Immediate actions:
1. Stop deploy promotion and pause related cron jobs.
2. Confirm the exact migration version that failed.
3. Take or verify a fresh backup before any corrective action.
4. Prefer a forward-fix migration over rollback for already-applied production changes.
5. Run `tool/supabase_rls_audit.sh` and `tool/supabase_fet_supply_smoke.sh` after the fix.

Recovery checks:
- Migrations are fully applied.
- RLS audit passes.
- Wallet/order/pool smoke checks pass.
- No unresolved destructive changes exist.

## High Edge Function Error Rate

Signals:
- Edge Function 5xx logs spike.
- Order creation, payment confirmation, pool settlement, or notification jobs fail.

Immediate actions:
1. Identify affected function and latest deploy.
2. Check secret availability, CORS allowlist, and Supabase service-role configuration.
3. Run the targeted smoke script or a controlled curl probe.
4. Roll back the function from the release tag if the issue is code-related.
5. Disable affected feature flag or cron if errors can mutate wallet/order/pool state.

Recovery checks:
- Function smoke test passes.
- Error rate returns to baseline.
- Audit logs and wallet ledger rows are reconciled.

## Slow Database Or Resource Exhaustion

Signals:
- Supabase CPU/connections spike.
- Slow queries affect ordering, wallet, pools, or admin.
- API latency increases.

Immediate actions:
1. Review Supabase Performance Advisor and slow query logs.
2. Pause heavy cron/import jobs if customer flows are degraded.
3. Check recent migrations for missing indexes or broad RLS policy scans.
4. Scale compute temporarily if needed.
5. Open a follow-up issue for query/index remediation.

Recovery checks:
- CPU/connections return to normal.
- Hot flows meet latency expectations.
- No failed settlement/order mutations remain unreconciled.

## Failed Web Or Mobile Deployment

Signals:
- Cloudflare Pages route returns errors.
- PWA assets fail to load.
- Mobile release crashes or cannot authenticate.

Immediate actions:
1. Revert Cloudflare Pages to the previous successful artifact for affected web apps.
2. Stop mobile staged rollout if applicable.
3. Confirm environment variables point to the intended Supabase project.
4. Run route smoke checks for public PWA, admin, venue portal, and TV display.
5. Use feature flags to disable affected mobile flows if binary rollback is unavailable.

Recovery checks:
- Routes return `200`.
- Auth and core read paths work.
- Crash/error rate returns to baseline.

## Data Incident

Signals:
- Suspected secret exposure, overbroad RLS, unauthorized admin access, or wallet/order data anomaly.

Immediate actions:
1. Preserve logs and identify affected tables, functions, users, and time range.
2. Rotate exposed credentials immediately.
3. Disable affected admin actions, RPCs, or Edge Functions.
4. Run RLS and grant audits.
5. Reconcile wallet ledger, orders, settlements, and audit logs.
6. Escalate to product/legal/security owners for notification decisions.

Recovery checks:
- Credentials are rotated.
- Unauthorized access path is closed.
- Audit trail and customer impact are documented.
