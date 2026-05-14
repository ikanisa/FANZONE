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
    if [[ "${name}" == VITE_* && "${name}" == *"${pattern}"* ]]; then
      echo "Refusing browser release env: ${name} must not be exposed to ${APP_NAME}." >&2
      exit 1
    fi
  done < <(env)
done

require_jwt_role() {
  local name="$1"
  local expected_role="$2"
  local value="${!name:-}"

  if ! command -v node >/dev/null 2>&1; then
    echo "node is required to validate ${name} JWT role." >&2
    exit 1
  fi

  if ! JWT_VALUE="${value}" EXPECTED_ROLE="${expected_role}" node <<'NODE'
const token = process.env.JWT_VALUE ?? "";
const expectedRole = process.env.EXPECTED_ROLE ?? "";

try {
  const parts = token.split(".");
  if (parts.length !== 3 || parts.some((part) => part.length === 0)) {
    process.exit(2);
  }

  const payload = JSON.parse(
    Buffer.from(parts[1], "base64url").toString("utf8"),
  );
  const role = typeof payload.role === "string" ? payload.role : "";
  process.exit(role === expectedRole ? 0 : 3);
} catch (_error) {
  process.exit(2);
}
NODE
  then
    echo "${name} must be a Supabase JWT with role '${expected_role}'." >&2
    exit 1
  fi
}

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

require_jwt_role VITE_SUPABASE_ANON_KEY anon

if [[ "${APP_NAME}" == "admin" || "${APP_NAME}" == "venue-portal" ]]; then
  if [[ "${VITE_APP_ENV:-production}" == "production" && "${VITE_PRIVILEGED_SESSION_MODE:-bff}" == "browser" ]]; then
    echo "Production ${APP_NAME} releases must use VITE_PRIVILEGED_SESSION_MODE=bff so privileged tokens stay behind HttpOnly cookies." >&2
    exit 1
  fi
fi

echo "Web release env OK for ${APP_NAME}."
