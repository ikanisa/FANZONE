# FANZONE World-Class Production Benchmark

Last updated: 2026-05-16

FANZONE is not production-ready until the Flutter app, bars/venue PWA, admin
PWA, and TV PWA all have a 100% tick-mark against this benchmark. Partial,
untested, undocumented, or provider-only claims do not count. Evidence must be
captured before launch.

## Benchmark Sources

This checklist is grounded in public, recognized standards and practices:

- OWASP ASVS for web application verification:
  https://owasp.org/www-project-application-security-verification-standard/
- OWASP MASVS for mobile application security:
  https://mas.owasp.org/MASVS/
- OWASP API Security Top 10 2023 for API authorization and abuse risks:
  https://owasp.org/API-Security/
- NIST Cybersecurity Framework 2.0 for governance, protection, detection,
  response, and recovery:
  https://www.nist.gov/publications/nist-cybersecurity-framework-csf-20
- W3C WCAG 2.2 for accessibility:
  https://www.w3.org/TR/wcag/
- web.dev PWA checklist for high-quality PWAs:
  https://web.dev/pwa-checklist/
- Google Play core app quality guidelines:
  https://developer.android.com/docs/quality-guidelines/core-app-quality
- Apple App Store Review Guidelines:
  https://developer.apple.com/app-store/review/guidelines/
- Google SRE SLO practice for reliability and measurable service quality:
  https://sre.google/sre-book/service-level-objectives/
- Stripe security posture as a fintech benchmark for SOC-style controls,
  availability, confidentiality, and PCI education:
  https://docs.stripe.com/security/stripe
- Cloudflare Zero Trust principles for least-trust access:
  https://www.cloudflare.com/learning/security/glossary/what-is-zero-trust/
- Supabase RLS guidance for browser-to-database authorization:
  https://supabase.com/docs/guides/database/postgres/row-level-security

## Global 100% Gate

Every surface must be marked `PASS` with evidence. `PARTIAL`, `N/A`, or
`WAIVED` requires written release-owner approval and cannot be used for P0 or
P1 controls.

| Area | Flutter app | Bars/Venue PWA | Admin PWA | TV PWA | Evidence required |
| --- | --- | --- | --- | --- | --- |
| Identity, auth, and session security | Required | Required | Required | Required | OTP/session tests, secure storage/cookie proof, logout/refresh tests |
| Authorization and object isolation | Required | Required | Required | Required | Negative tests for cross-user, cross-venue, admin-role, and anonymous access |
| Supabase RLS and RPC boundaries | Required | Required | Required | Required | Live RLS audit, grant audit, service-role isolation, migration proof |
| Payment and wallet integrity | Required | Required | Required | Display-only where applicable | Order/payment state tests, manual payment audit trail, ledger reconciliation |
| Secrets and key management | Required | Required | Required | Required | Rotation evidence, tracked scan, full-history scan, provider secret inventory |
| Secure build and release | Required | Required | Required | Required | Reproducible build logs, env validation, signing or deploy metadata |
| Accessibility | Required | Required | Required | Required | WCAG 2.2 AA evidence, contrast/tap-target/keyboard/screen-reader checks |
| Performance and reliability | Required | Required | Required | Required | SLOs, load smoke, cold-start targets, runtime error budget |
| Observability and alerting | Required | Required | Required | Required | Error telemetry, dashboards, alert routes, incident owner |
| Privacy and data minimization | Required | Required | Required | Required | Data inventory, retention/deletion/export procedure, support access audit |
| Platform policy compliance | Required | Required | Required | Required | Google Play/Apple review checks for mobile, PWA installability and metadata for web |
| Backup, restore, and rollback | Required | Required | Required | Required | DB backup, restore drill, rollback tag, deploy rollback proof |
| UAT and release evidence | Required | Required | Required | Required | Signed UAT matrix covering critical user journeys and failure paths |

## Surface-Specific Gates

### Flutter App

- `flutter analyze` passes.
- Full `flutter test` passes.
- Android release AAB is signed, installable, and uses production env.
- iOS archive/TestFlight path is proven.
- Deep links open QR ordering from cold and warm states.
- WhatsApp OTP upgrade, anonymous session, wallet, ordering, pools, rewards,
  and external payment handoff all pass UAT.
- Mobile security review covers secure storage, network transport, permissions,
  privacy prompts, logging, crash handling, and app-store policy.

### Bars/Venue PWA

- Typecheck, lint, test, and production build pass.
- Cloudflare BFF runtime variables are verified in the deployed environment.
- Venue role boundaries are proven for owner, manager, staff, and unauthorized
  users.
- Manual payment confirmation remains staff-controlled and auditable.
- QR/table ordering, live order queue, menu, rewards, pools, and settings pass
  deployed browser smoke tests.
- PWA installability, offline/error states, headers, and CORS are verified.

### Admin PWA

- Typecheck, lint, test, and production build pass.
- Admin BFF cookies, refresh, logout, Supabase proxy, and Edge Function proxy are
  verified from the deployed origin.
- Admin role matrix is proven for super-admin, admin, viewer, unauthorized, and
  inactive admin users.
- Sensitive actions write audit logs and expose reviewable event trails.
- Demo mode, wildcard CORS, browser-readable privileged tokens, and service-role
  keys in client config are all blocked.
- Operational dashboards cover orders, payments, wallet/ledger, pools, alerts,
  moderation, and auth failures.

### TV PWA

- Typecheck, lint, and production build pass.
- Production TV domain/DNS and display URL are verified.
- TV surface is read-only and cannot mutate orders, wallets, users, or admin
  state.
- Venue scoping and display-token behavior are proven.
- Large-screen layout, QR legibility, refresh behavior, network loss, and browser
  recovery are smoke-tested.

## Launch Rule

FANZONE can move from `NO-GO` to `GO` only after:

- every row in the global 100% gate is `PASS` for every applicable surface;
- all P0 and P1 tasks in `docs/release/production-go-live-task-register.md` are
  complete with evidence;
- `tool/go_live_readiness.sh --local` passes on a clean checkout;
- live provider evidence proves deployed Cloudflare, Supabase, scheduler,
  secrets, monitoring, backup, rollback, and store-release readiness.
