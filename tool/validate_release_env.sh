#!/usr/bin/env bash
# Validate FANZONE release env files without printing secret values.
set -euo pipefail

usage() {
  echo "Usage: $0 <local|development|staging|production|path-to-env-file> [--client|--server|--all]" >&2
}

TARGET="${1:-}"
SCOPE="${2:---all}"

if [[ -z "${TARGET}" ]]; then
  usage
  exit 1
fi

case "${TARGET}" in
  local|development)
    ENV_FILE=".env"
    ;;
  staging)
    ENV_FILE=".env.staging"
    ;;
  production)
    ENV_FILE=".env.production"
    ;;
  *)
    ENV_FILE="${TARGET}"
    ;;
esac

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing release env file: ${ENV_FILE}" >&2
  exit 1
fi

case "${SCOPE}" in
  --client|--server|--all) ;;
  *)
    usage
    exit 1
    ;;
esac

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

failures=0

require_key() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "${value}" ]]; then
    echo "Missing ${name}" >&2
    failures=$((failures + 1))
    return
  fi

  case "${value}" in
    *replace-with*|*your-*|*example.com*|*your-project*|*placeholder*)
      echo "${name} still contains a placeholder value" >&2
      failures=$((failures + 1))
      ;;
  esac
}

require_jwt_role() {
  local name="$1"
  local expected_role="$2"
  local value="${!name:-}"

  if ! command -v node >/dev/null 2>&1; then
    echo "node is required to validate ${name} JWT role." >&2
    failures=$((failures + 1))
    return
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
    failures=$((failures + 1))
  fi
}

require_client() {
  require_key SUPABASE_URL
  require_key SUPABASE_ANON_KEY
  require_key VITE_SUPABASE_URL
  require_key VITE_SUPABASE_ANON_KEY
  require_key VITE_GUEST_APP_URL
  require_key VITE_PUBLIC_APP_URL
  require_key VITE_TV_DISPLAY_URL

  [[ "${SUPABASE_URL:-}" == https://*.supabase.co ]] || {
    echo "SUPABASE_URL must be a hosted Supabase HTTPS URL" >&2
    failures=$((failures + 1))
  }
  [[ "${SUPABASE_ANON_KEY:-}" == eyJ* ]] || {
    echo "SUPABASE_ANON_KEY does not look like a Supabase JWT" >&2
    failures=$((failures + 1))
  }
  [[ "${VITE_SUPABASE_ANON_KEY:-}" == eyJ* ]] || {
    echo "VITE_SUPABASE_ANON_KEY does not look like a Supabase JWT" >&2
    failures=$((failures + 1))
  }
  require_jwt_role SUPABASE_ANON_KEY anon
  require_jwt_role VITE_SUPABASE_ANON_KEY anon
}

require_server() {
  require_key SUPABASE_SERVICE_ROLE_KEY
  require_key EDGE_SERVICE_ROLE_KEY
  require_key SUPABASE_DB_URL
  require_key FANZONE_JWT_SECRET
  require_key WABA_ACCESS_TOKEN
  require_key WABA_PHONE_NUMBER_ID
  require_key WABA_OTP_TEMPLATE_NAME
  require_key CRON_SECRET
  require_key PUSH_NOTIFY_SECRET

  [[ "${SUPABASE_SERVICE_ROLE_KEY:-}" == eyJ* ]] || {
    echo "SUPABASE_SERVICE_ROLE_KEY does not look like a Supabase JWT" >&2
    failures=$((failures + 1))
  }
  [[ "${SUPABASE_DB_URL:-}" == postgresql://* ]] || {
    echo "SUPABASE_DB_URL must be a PostgreSQL connection string" >&2
    failures=$((failures + 1))
  }
}

case "${SCOPE}" in
  --client)
    require_client
    ;;
  --server)
    require_server
    ;;
  --all)
    require_client
    require_server
    ;;
esac

if env | cut -d= -f1 | rg -q '^(VITE_.*(SERVICE|SERVICE_ROLE|DB|DATABASE|POSTGRES|WABA|WHATSAPP_ACCESS|META_ACCESS|CRON_SECRET)|.*SERVICE_ROLE.*VITE_)'; then
  echo "Refusing env: backend/admin secrets must not be exposed through VITE_* variables" >&2
  failures=$((failures + 1))
fi

if [[ "${failures}" -ne 0 ]]; then
  echo "Release env validation failed for ${ENV_FILE} (${failures} issue(s))." >&2
  exit 1
fi

echo "Release env OK for ${ENV_FILE} (${SCOPE})."
