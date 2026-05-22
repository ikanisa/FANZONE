#!/usr/bin/env bash
# Non-destructive product-boundary gate for customer/admin/runtime surfaces.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "FANZONE product-boundary scan"

FORBIDDEN_PATTERN='(betting|gambling|wager|wagering|odds|cash[- ]?out|cash prize|cash prizes|jackpot|paid prediction|paid predictions|pooled prize|pooled prizes)'

# Keep this focused on active product/runtime copy. Legal, release, SQL, and
# architecture files may describe forbidden behavior as policy boundaries.
if rg -n -i "${FORBIDDEN_PATTERN}" \
  lib \
  apps/admin \
  apps/venue-portal \
  apps/website \
  apps/tv-display \
  packages/core \
  pubspec.yaml \
  --glob '!**/node_modules/**' \
  --glob '!**/dist/**' \
  --glob '!**/build/**' \
  --glob '!**/*.test.*' \
  --glob '!**/*test.*'; then
  echo
  echo "Forbidden betting, wagering, odds, cash-out, cash-prize, or paid-prediction language found in active product surfaces." >&2
  echo "Use hospitality, free-to-play challenge, loyalty-points, leaderboard, reward, or coupon language instead." >&2
  exit 1
fi

echo "Product-boundary scan passed."
