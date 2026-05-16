#!/usr/bin/env bash
# Validate production env files without printing secret values.
set -euo pipefail

env_file="${1:-.env.production}"

if [[ ! -f "${env_file}" ]]; then
  echo "Missing production env file: ${env_file}" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${env_file}"
set +a

tool/validate_release_env.sh "${env_file}" --client
tool/validate_web_release_env.sh website
tool/validate_web_release_env.sh admin
tool/validate_web_release_env.sh venue-portal
tool/validate_web_release_env.sh tv-display

echo "Production client env isolation OK for mobile and web surfaces."
