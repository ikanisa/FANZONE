# Permissions And RLS

Security boundary: Supabase RLS, database constraints, SECURITY DEFINER RPCs, and Edge Function authorization. UI role guards are not a security boundary.

## Roles

| Role | Scope | Can do |
| --- | --- | --- |
| Guest/authenticated user | Own profile, wallet, orders, pool entries | Place orders, join pools, view own wallet, manage own profile. |
| Venue staff | Assigned venue | View/manage orders, mark service status, mark manual payment status where policy allows. |
| Venue manager | Assigned venue | Staff permissions plus menu, pools, and rewards config. |
| Venue owner | Assigned venue | Manager permissions plus venue member and ownership operations. |
| Admin/operator | Platform | Curation, settlement operations, wallet oversight, reward rules, feature controls, audit review. |
| Service role | Backend only | Internal Edge Function/RPC execution. Never exposed to clients. |

## Tenant Isolation

- Venue data is scoped through `venue_id` and `venue_user_has_role`.
- User data is scoped through `auth.uid()`.
- Pool visibility is public only for open/live/settled pools or tenant-authorized operators.
- Admin-only operations must call admin helper checks such as `sports_bar_is_admin` or `is_admin_manager`.
- Client write paths must not directly update sensitive order, payment, wallet, settlement, or admin tables.

## Sensitive Writes

Use approved RPCs or Edge Functions for:

- order service updates;
- manual payment status changes;
- FET reward configuration;
- wallet credits/debits;
- pool creation, entry, settlement, endorsement, and rejection;
- admin role changes;
- venue claim approvals;
- match curation;
- feature flags and platform controls.

## RLS Review Checklist

- Every client-exposed table has RLS enabled.
- Select policies do not leak another venue's orders, tables, members, or private admin data.
- Insert/update policies use both `USING` and `WITH CHECK` when applicable.
- SECURITY DEFINER functions validate caller identity before mutating data.
- Functions set `search_path` to trusted schemas.
- Service-role functions are not callable from client code unless they perform their own role checks.
- Storage buckets have explicit public/private intent and MIME/size restrictions.

## Verification

```bash
supabase db lint --db-url "$SUPABASE_DB_URL" --schema public --fail-on error
psql "$SUPABASE_DB_URL" -f supabase/tests/rls_hardening_audit.sql
psql "$SUPABASE_DB_URL" -f supabase/tests/admin_data_plane_verification.sql
psql "$SUPABASE_DB_URL" -f supabase/tests/app_sports_contract_verification.sql
```
