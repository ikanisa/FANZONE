#!/usr/bin/env bash
# Non-destructive product-boundary gate for customer/admin/runtime surfaces.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "FANZONE product-boundary scan"

FORBIDDEN_PATTERN='(betting|gambling|wager|wagering|odds|cash[- ]?out|cash prize|cash prizes|jackpot|paid prediction|paid predictions|pooled prize|pooled prizes)'
WALLET_COPY_PATTERN='(fet wallet|fet wallets|sports-bar wallet|wallet flow|wallet activity|wallet transfer|wallet balance|wallet operations|wallet ledger|open wallet|wallet is unavailable)'
PAID_ENTERTAINMENT_COPY_PATTERN='(\bbuy fet\b|\bstake[ -]fet\b|\bmin[ -]stake\b|\bmax[ -]stake\b|\bbar[ -]stake\b|\bparticipant[ -]stake\b|\bstake amount\b|\bfixed stake\b|\bpool staking\b|\baccepts stakes\b|\best\. upside\b|\bestimated return\b|\bif camp wins now\b|\btotal pot\b|\bfet winnings\b|\bvenue wallet\b|\bbar wallet\b|\bwallet stake\b|\bcredits the wallet\b)'
CUSTOMER_TRANSFER_COPY_PATTERN='(\bsend fet\b|\bfet transfer\b|\bfet transfers\b|\bwallet transfer\b|\brecipient fan id\b|\bconfirm transfer\b|\bunlock transfer\b|\btransfer successful\b|\btransfer sent\b)'

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

if rg -n -i "${WALLET_COPY_PATTERN}" \
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
  echo "Customer or operator-facing wallet copy found in active product surfaces." >&2
  echo "FET must be described as a non-cash rewards ledger or loyalty points, while legacy wallet identifiers may remain internal." >&2
  exit 1
fi

if rg -n -i "${PAID_ENTERTAINMENT_COPY_PATTERN}" \
  lib \
  apps/admin \
  apps/venue-portal \
  apps/website \
  apps/tv-display \
  pubspec.yaml \
  --glob '!**/node_modules/**' \
  --glob '!**/dist/**' \
  --glob '!**/build/**' \
  --glob '!**/*.test.*' \
  --glob '!**/*test.*'; then
  echo
  echo "Paid-entry, staking, pot, winnings, or wallet-like entertainment copy found in active product surfaces." >&2
  echo "Use free-to-play challenge, reward-points, reserve, entry, leaderboard, coupon, or rewards-ledger language instead." >&2
  exit 1
fi

if rg -n -i "${CUSTOMER_TRANSFER_COPY_PATTERN}" \
  lib \
  apps/admin \
  apps/venue-portal \
  apps/website \
  apps/tv-display \
  pubspec.yaml \
  --glob '!**/node_modules/**' \
  --glob '!**/dist/**' \
  --glob '!**/build/**' \
  --glob '!**/*.test.*' \
  --glob '!**/*test.*'; then
  echo
  echo "Customer FET transfer copy found in active product surfaces." >&2
  echo "FET must remain a closed-loop rewards ledger, not a customer wallet or transfer product." >&2
  exit 1
fi

echo "Product-boundary scan passed."
node tool/scoped_realtime_scan.mjs
node tool/order_edge_boundary_scan.mjs
node tool/order_lifecycle_parity_scan.mjs
node tool/venue_portal_hospitality_scan.mjs
node tool/entertainment_reward_boundary_scan.mjs
node tool/flutter_ordering_boundary_scan.mjs
