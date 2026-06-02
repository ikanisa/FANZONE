# FANZONE Go-Live Current State - 2026-06-02

## Scope

This note records the current repo-owned go-live evidence captured on
2026-06-02 after the comprehensive handover report and Codex go-live goal pack
were committed to `main`.

This is not a launch approval. FANZONE remains `NO-GO` until every P0 and P1
control in `docs/release/world-class-evidence-matrix.md` is `PASS`, the
fail-closed evidence validators pass, and production/provider signoffs are
complete.

## Repository State

| Item | Evidence |
| --- | --- |
| Working tree | Clean before the local go-live gate run |
| Branch | `main` |
| Local HEAD | `7cc4e3e` |
| Remote HEAD | `origin/main` at `7cc4e3e` |
| Divergence | `git rev-list --left-right --count main...origin/main` returned `0 0` |
| Most recent pushed commit | `7cc4e3e chore: record go-live evidence progress` |

## Repo-Owned Local Gate

Command:

```bash
./tool/go_live_readiness.sh --local
```

Result: `PASS`

The local go-live gate completed successfully at `7cc4e3e` and reported:

- clean working tree;
- tracked-file secret regex scan passed;
- `tool/full_history_secret_scan.sh` passed;
- `tool/audit_repo_hygiene.sh` passed;
- `tool/product_boundary_scan.sh` passed, including scoped realtime,
  order Edge boundary, order lifecycle parity, venue portal hospitality,
  entertainment/reward boundary, and Flutter ordering boundary checks;
- `tool/mobile_release_static_audit.sh` passed;
- `flutter analyze` passed with no issues;
- `flutter test` passed with 249 tests;
- Node workspace typecheck, lint, test, and build passed for the active web
  workspaces and shared core package;
- BFF health smoke passed;
- Supabase Edge Function formatting, checks, and tests passed;
- core order lifecycle Deno tests passed;
- release script syntax checks passed.

The command ended with:

```text
Local go-live checks passed. External/provider tasks still require evidence in docs/release/production-go-live-task-register.md.
```

## Fail-Closed Evidence Validators

The local gate is green, but the production evidence validators still correctly
fail because external/provider evidence and owner signoffs are not complete.

### World-Class Evidence

Command:

```bash
./tool/check_world_class_evidence.sh
```

Result: `FAIL`

Open blockers:

- P0 credential rotation and secret inventory remains `PENDING`;
- P0 world-class benchmark completion remains `PENDING`;
- P1 scheduler and cron monitoring remains `PENDING`;
- P1 Android release artifact remains `PARTIAL`;
- P1 iOS archive/TestFlight readiness remains `PARTIAL`;
- P1 critical user-flow UAT remains `PENDING`;
- P1 production observability and alerting remains `PENDING`;
- P1 incident response and rollback readiness remains `PENDING`.

### Secret Rotation Evidence

Command:

```bash
node tool/validate_secret_rotation_evidence.mjs
```

Result: `FAIL`

Open blockers:

- `releaseCandidate` is still `TBD`;
- security owner and release owner signoff fields are incomplete;
- launch approval is not granted;
- all credential classes are still `PENDING`, including Supabase anon key,
  Supabase service-role key, Supabase database credentials, Supabase PAT,
  Cloudflare runtime secrets, Supabase Edge secrets, CI/CD secrets, and local
  operator secrets;
- post-rotation checks still need evidence references for full-history secret
  scanning, production env isolation, Supabase live validation, and deployed
  web surface smoke.

### Critical UAT Evidence

Command:

```bash
node tool/validate_critical_uat_signoff.mjs
```

Result: `FAIL`

Open blockers:

- `releaseCandidate` is still `TBD`;
- QA owner and release owner signoff fields are incomplete;
- launch approval is not granted;
- all listed mobile, venue, admin, TV, realtime, and backend isolation UAT
  flows remain `PENDING`.

### iOS TestFlight Evidence

Command:

```bash
node tool/validate_ios_testflight_evidence.mjs
```

Result: `FAIL`

Open blockers:

- mobile owner and release owner signoff fields are incomplete;
- launch approval is not granted;
- signed archive, signed IPA, physical iPhone install, push smoke, TestFlight,
  and App Store review metadata checks remain `PENDING`.

## Additional Repo-Owned Hardening Added

After the local gate pass, the repo gained a dedicated Supabase API
authorization-abuse entrypoint:

```bash
./tool/supabase_api_authorization_abuse_tests.sh --readiness
./tool/supabase_api_authorization_abuse_tests.sh --contract
```

The script composes the existing RLS audit and Hospitality Core Phase 2 SQL
contracts. The contract mode is rollback-based and exercises negative
authorization paths already covered by the SQL contracts, including customer
mutation rejection, cross-venue staff/order/reconciliation/staff-call rejection,
direct table mutation denial, unsupported payment rejection, and admin-only
surface checks.

This improves the P2 API authorization-abuse evidence row from `PENDING` to
`PARTIAL`. It must not be marked `PASS` until the script is run against the
release target and Edge Function auth-abuse evidence is attached.

Validation status on 2026-06-02:

- `bash -n tool/supabase_api_authorization_abuse_tests.sh` passed;
- `./tool/supabase_api_authorization_abuse_tests.sh --readiness` could not
  complete in this environment because the linked Supabase CLI connection timed
  out while creating the login role and requested `SUPABASE_DB_PASSWORD` or a
  direct `SUPABASE_DB_URL`;
- `--contract` was not run without a working release-target database
  connection.

## Current Launch Decision

Decision: `NO-GO`

Reason: the repo-owned local gate passes, but FANZONE still lacks required
production/provider proof and owner signoffs for P0/P1 launch controls. The
next implementation work should focus on closing evidence in this order:

1. credential rotation and secret inventory;
2. live production Supabase Phase 2 validation and post-rotation checks;
3. deployed web/PWA runtime, CORS, and header proof;
4. Android release artifact proof;
5. iOS archive, IPA, device, push, and TestFlight proof;
6. critical user-flow UAT;
7. scheduler, observability, incident, and rollback proof;
8. final fail-closed go/no-go rerun.

## Operations Evidence Validator Added

The repo now has a structured operations evidence file:

```bash
release/operations/operations-readiness-evidence.json
```

Validate it with:

```bash
node tool/validate_operations_readiness_evidence.mjs
```

The validator is fail-closed and currently expected to fail until production
scheduler history, cron smoke evidence, observability dashboards, alert routes,
incident ownership, rollback tag, database restore plan, post-deploy watch, a
sample alert test, and release-owner approval are recorded.
