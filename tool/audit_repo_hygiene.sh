#!/usr/bin/env bash
# Static repo hygiene checks for generated files, local secrets, and release drift.
set -euo pipefail

failures=0

fail() {
  echo "$1" >&2
  failures=$((failures + 1))
}

tracked_generated="$(
  git ls-files | rg '(^build/|/dist/|\.log$|\.env$|\.jks$|\.keystore$|google-services\.json|GoogleService-Info\.plist|node_modules|\.dart_tool|coverage/)' || true
)"
if [[ -n "${tracked_generated}" ]]; then
  fail "Generated, secret, or local build artifacts are tracked:
${tracked_generated}"
fi

if git grep -n 'VITE_PRIVILEGED_SESSION_MODE=browser' -- \
  ':!docs/**' \
  ':!apps/**/.env.example' \
  ':!tool/**' >/tmp/fanzone-browser-session-mode.txt; then
  fail "Production code/config references browser privileged session mode:
$(cat /tmp/fanzone-browser-session-mode.txt)"
fi
rm -f /tmp/fanzone-browser-session-mode.txt

if git grep -n 'FANZONE_EDGE_ALLOW_WILDCARD_CORS=true' -- \
  ':!docs/**' \
  ':!*.example' \
  ':!**/*.example' >/tmp/fanzone-wildcard-cors.txt; then
  fail "Production code/config enables wildcard CORS:
$(cat /tmp/fanzone-wildcard-cors.txt)"
fi
rm -f /tmp/fanzone-wildcard-cors.txt

for required in \
  docs/release/world-class-production-benchmark.md \
  docs/release/world-class-evidence-matrix.md \
  docs/release/production-go-live-task-register.md \
  tool/go_live_readiness.sh \
  tool/check_world_class_evidence.sh \
  tool/collect_world_class_evidence.sh; do
  [[ -f "${required}" ]] || fail "Missing required production-readiness artifact: ${required}"
done

if [[ "${failures}" -ne 0 ]]; then
  echo "Repo hygiene audit failed with ${failures} issue(s)." >&2
  exit 1
fi

echo "Repo hygiene audit passed."
