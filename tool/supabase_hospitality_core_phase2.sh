#!/usr/bin/env bash
# Run Hospitality Core Phase 2 Supabase validation as one operator entrypoint.
# --readiness is non-mutating schema/grant/RPC shape validation.
# --contract runs rollback-based behavioral SQL contracts after migrations apply.
set -euo pipefail

mode="${1:---readiness}"

case "${mode}" in
  --readiness)
    ./tool/supabase_order_lifecycle_smoke.sh --readiness
    ./tool/supabase_manual_payment_reconciliation_smoke.sh --readiness
    ./tool/supabase_staff_call_acknowledgement_smoke.sh --readiness
    ;;
  --contract)
    ./tool/supabase_order_lifecycle_smoke.sh --contract
    ./tool/supabase_manual_payment_reconciliation_smoke.sh --contract
    ./tool/supabase_staff_call_acknowledgement_smoke.sh --contract
    ;;
  *)
    echo "Usage: $0 [--readiness|--contract]" >&2
    exit 2
    ;;
esac
