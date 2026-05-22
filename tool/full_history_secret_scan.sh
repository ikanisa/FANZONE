#!/usr/bin/env bash
# Scan committed history for obvious live credentials without printing values.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

SECRET_PATTERN='(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql://[^[:space:]]+:[^[:space:]]+@)'
found=0

echo "Scanning committed history for obvious credential patterns..."

while IFS= read -r rev; do
  matches="$(
    git grep -IlE "${SECRET_PATTERN}" "${rev}" -- \
      ':!.github/workflows/ci.yml' \
      ':!.github/workflows/secret-regex-scan.yml' \
      ':!docs/free-account-release.md' \
      ':!docs/secret-rotation-runbook.md' \
      ':!docs/release/production-go-live-task-register.md' \
      ':!docs/production-readiness/00-executive-summary.md' \
      ':!docs/production-readiness/01-repo-inventory.md' \
      ':!docs/production-readiness/02-validation-baseline.md' \
      ':!tool/go_live_readiness.sh' \
      ':!tool/full_history_secret_scan.sh' \
      ':!tool/mobile_release_static_audit.sh' \
      ':!.env*.example' \
      ':!**/.env*.example' \
      ':!**/package-lock.json' || true
  )"

  if [[ -n "${matches}" ]]; then
    found=1
    while IFS= read -r match; do
      [[ -z "${match}" ]] && continue
      echo "Potential credential pattern in ${match}"
    done <<<"${matches}"
  fi
done < <(git rev-list --all)

if [[ "${found}" -ne 0 ]]; then
  echo "Full-history secret scan failed. Review the reported revision/file locations and rotate any exposed credentials." >&2
  exit 1
fi

echo "Full-history secret scan passed."
