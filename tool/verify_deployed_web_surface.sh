#!/usr/bin/env bash
# Verify deployed FANZONE web/PWA security headers and BFF health.
set -euo pipefail

usage() {
  echo "Usage: $0 <website|admin|venue-portal|tv-display> <https-url>" >&2
}

surface="${1:-}"
base_url="${2:-}"

if [[ -z "${surface}" || -z "${base_url}" ]]; then
  usage
  exit 2
fi

case "${surface}" in
  website|admin|venue-portal|tv-display) ;;
  *)
    usage
    exit 2
    ;;
esac

if [[ "${base_url}" != https://* ]]; then
  echo "${surface} URL must be HTTPS for production: ${base_url}" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

base_url="${base_url%/}"
headers_file="${tmp_dir}/${surface}.headers"
body_file="${tmp_dir}/${surface}.body"

http_code="$(curl -sS -L -D "${headers_file}" -o "${body_file}" -w '%{http_code}' "${base_url}/")"
if [[ "${http_code}" -lt 200 || "${http_code}" -ge 300 ]]; then
  echo "${surface} root returned HTTP ${http_code}." >&2
  exit 1
fi

require_header() {
  local name="$1"
  local expected="${2:-}"
  if ! grep -iq "^${name}:" "${headers_file}"; then
    echo "${surface} is missing header: ${name}" >&2
    exit 1
  fi
  if [[ -n "${expected}" ]] && ! grep -iq "^${name}:.*${expected}" "${headers_file}"; then
    echo "${surface} header ${name} does not include expected value: ${expected}" >&2
    exit 1
  fi
}

require_header "x-content-type-options" "nosniff"
require_header "referrer-policy" "strict-origin-when-cross-origin"
require_header "content-security-policy" "default-src"
require_header "strict-transport-security" "max-age="
require_header "permissions-policy"

case "${surface}" in
  admin|venue-portal)
    require_header "x-frame-options" "DENY"
    ;;
  website|tv-display)
    require_header "x-frame-options" "SAMEORIGIN"
    ;;
esac

if [[ "${surface}" == "admin" || "${surface}" == "venue-portal" ]]; then
  bff_headers="${tmp_dir}/${surface}.bff.headers"
  bff_body="${tmp_dir}/${surface}.bff.body"
  bff_code="$(
    curl -sS -D "${bff_headers}" -o "${bff_body}" -w '%{http_code}' \
      "${base_url}/api/auth/session"
  )"
  if [[ "${bff_code}" -ne 200 ]]; then
    echo "${surface} BFF session endpoint returned HTTP ${bff_code}." >&2
    exit 1
  fi
  if ! grep -iq '^cache-control:.*no-store' "${bff_headers}"; then
    echo "${surface} BFF session endpoint must return cache-control: no-store." >&2
    exit 1
  fi
  if ! grep -Eq '"authenticated"[[:space:]]*:[[:space:]]*false' "${bff_body}"; then
    echo "${surface} BFF unauthenticated session response did not return authenticated=false." >&2
    exit 1
  fi
fi

echo "${surface} deployed web surface OK: ${base_url}"
