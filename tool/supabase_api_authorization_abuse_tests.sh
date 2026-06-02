#!/usr/bin/env bash
# Run API authorization abuse checks against the configured Supabase target.
# --readiness is non-mutating schema/grant/RPC shape validation.
# --contract runs rollback-based behavioral contracts with negative
# cross-user, cross-venue, direct-table-mutation, and role-abuse checks.
set -euo pipefail

mode="${1:---readiness}"

case "${mode}" in
  --readiness)
    ./tool/supabase_rls_audit.sh
    ./tool/supabase_hospitality_core_phase2.sh --readiness
    ;;
  --contract)
    ./tool/supabase_rls_audit.sh
    ./tool/supabase_hospitality_core_phase2.sh --contract
    ;;
  *)
    echo "Usage: $0 [--readiness|--contract]" >&2
    exit 2
    ;;
esac
