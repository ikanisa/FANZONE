# Admin Operations Guide

The admin console is the platform operator surface. UI route guards are convenience controls; database policies and admin RPCs are the security boundary.

## Daily Tasks

- Review failed or pending pool settlements.
- Review payment disputes and unusual manual payment changes.
- Review wallet adjustment queue and frozen wallet events.
- Review venue onboarding and claim requests.
- Review match curation queue for upcoming commercial matches.
- Review Edge Function errors and failed notification sends.

## Match Curation

- Prioritize default competitions and World Cup content.
- Curate other local matches manually by country, venue, popularity, team relevance, and commercial opportunity.
- Do not hardcode World Cup teams, fixtures, countries, dates, or matches in apps.
- Every curated match should have a reason and operator attribution.

## Pool Operations

- Monitor active venue, country, and platform pools.
- Confirm each venue has at most one official pool per match.
- Run settlement only after final match result is confirmed.
- Treat settlement as idempotent; do not manually duplicate payout rows.
- Use audit logs to review operator-triggered settlement actions.

## Venue Operations Support

- Owner/manager can configure FET reward percentage, spend allowance, spend cap, campaign state, table QR, menu, and official venue pools.
- Staff can operate orders and manual payment status according to policy.
- Payment API support is intentionally absent; guide venues to cash, MoMo/USSD, or Revolut-link handoff.

## Wallet Operations

- Wallet balances derive from ledger transactions.
- Manual admin adjustments require a reason and audit event.
- Investigate discrepancies before crediting or debiting users.
- Freeze wallets only with documented abuse, fraud, or support reason.

## Release Operations

- Use [Go-Live Checklist](../release/go-live-checklist.md).
- Use [Rollback](../release/rollback.md) before any production deploy.
- Keep release evidence: commit SHA, migration list, build output, SQL verification output, smoke output, and UAT sign-off.

## Incident Response

Severity guide:

- P0: wallet ledger corruption, settlement double-pay, auth bypass, cross-tenant data leak, production outage.
- P1: order creation/payment confirmation broken, QR entry broken, admin unsafe mutation broken.
- P2: degraded notification, menu OCR failure, non-critical reporting issue.
- P3: copy, layout, or low-impact operational issue.

For P0/P1:

1. Stop affected cron or feature flag.
2. Preserve logs and audit records.
3. Roll back app/function if needed.
4. Reconcile affected orders, wallets, pools, and settlements.
5. Publish internal incident summary and follow-up tasks.
