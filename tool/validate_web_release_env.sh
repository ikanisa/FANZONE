#!/usr/bin/env bash
# Validate browser-safe Vite release env for a FANZONE web surface.
set -euo pipefail

APP_NAME="${1:?Usage: $0 <website|venue-portal|tv-display|admin>}"

case "${APP_NAME}" in
  website|admin)
    REQUIRED_KEYS=(VITE_SUPABASE_URL VITE_SUPABASE_ANON_KEY)
    ;;
  venue-portal)
    REQUIRED_KEYS=(VITE_SUPABASE_URL VITE_SUPABASE_ANON_KEY VITE_GUEST_APP_URL VITE_TV_DISPLAY_URL)
    ;;
  tv-display)
    REQUIRED_KEYS=(VITE_SUPABASE_URL VITE_SUPABASE_ANON_KEY VITE_PUBLIC_APP_URL)
    ;;
  *)
    echo "Unknown app: ${APP_NAME}" >&2
    exit 1
    ;;
esac

BLOCKED_PATTERNS=(
  'SERVICE_ROLE'
  'SUPABASE_DB'
  'DATABASE_URL'
  'POSTGRES'
  'WABA_'
  'WHATSAPP_ACCESS_TOKEN'
  'META_ACCESS_TOKEN'
  'CRON_SECRET'
)

missing=0
for key in "${REQUIRED_KEYS[@]}"; do
  value="${!key:-}"
  if [[ -z "${value}" ]]; then
    echo "Missing ${key} for ${APP_NAME}." >&2
    missing=1
  fi
done

if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  while IFS='=' read -r name _; do
    if [[ "${name}" == *"${pattern}"* ]]; then
      echo "Refusing browser release env: ${name} must not be exposed to ${APP_NAME}." >&2
      exit 1
    fi
  done < <(env)
done

case "${VITE_SUPABASE_URL:-}" in
  https://*.supabase.co) ;;
  *)
    echo "VITE_SUPABASE_URL must be a hosted Supabase HTTPS URL." >&2
    exit 1
    ;;
esac

if [[ "${VITE_SUPABASE_ANON_KEY:-}" != eyJ* ]]; then
  echo "VITE_SUPABASE_ANON_KEY does not look like a Supabase JWT anon key." >&2
  exit 1
fi

echo "Web release env OK for ${APP_NAME}."

