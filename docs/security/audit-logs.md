# Audit Logs

Auditability is required for sensitive platform, venue, pool, wallet, and payment-status actions.

## Audit Sources

| Source | Purpose |
| --- | --- |
| `audit_logs` | General platform audit record for actor, action, entity, before/after JSON, and timestamp. |
| `payment_events` | Manual/off-platform payment status events by order. |
| `pool_operation_audit_logs` | Pool-specific operational audit trail. |
| Wallet transaction rows | Ledger-level credit/debit history. |
| Edge Function logs | Runtime request/error diagnostics. |

## Required Audited Actions

- manual order paid, partially paid, refunded, disputed, or unpaid changes;
- reward rule and venue FET configuration changes;
- wallet credit/debit/admin adjustment/freeze operations;
- pool creation, endorsement, rejection, cancellation, and settlement;
- match result updates and settlement triggers;
- admin role grants/revokes;
- venue claim approval/rejection;
- feature flag and platform control changes.

## Audit Event Requirements

Each event should capture:

- actor user id;
- actor role when available;
- action name;
- entity type and id;
- before state;
- after state;
- timestamp;
- source function or RPC;
- safe metadata only.

Never log:

- service-role keys;
- database passwords;
- raw OTPs;
- full provider secrets;
- complete service account JSON;
- payment instrument details.

## Operator Review

Daily:

- inspect failed payment confirmations;
- inspect failed pool settlements;
- inspect admin access changes;
- inspect wallet adjustments;
- inspect unusually high manual payment reversals.

Weekly:

- export audit samples for release record;
- verify audit log retention;
- verify no sensitive secrets are present in logs;
- compare wallet ledger totals with configured supply caps.
