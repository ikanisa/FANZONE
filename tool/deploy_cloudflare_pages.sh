#!/usr/bin/env bash
set -euo pipefail

# Local/free-account Cloudflare Pages deploy path.
# Usage:
#   tool/deploy_cloudflare_pages.sh all
#   tool/deploy_cloudflare_pages.sh website admin venue-portal tv-display

if [[ -f ".env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source ".env"
  set +a
fi

if [[ -f "apps/admin/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "apps/admin/.env"
  set +a
fi

load_json_env() {
  local file="$1"
  [[ -f "${file}" ]] || return 0

  if rg -q 'https://your-project-ref\.supabase\.co|your-anon-key|REPLACE_WITH|YOUR_' "${file}"; then
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    SUPABASE_URL="${SUPABASE_URL:-$(jq -r '.SUPABASE_URL // empty' "${file}")}"
    SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$(jq -r '.SUPABASE_ANON_KEY // empty' "${file}")}"
  fi
}

load_json_env "env/ci.production.json"
load_json_env "env/production.json"

export VITE_SUPABASE_URL="${VITE_SUPABASE_URL:-${SUPABASE_URL:-}}"
export VITE_SUPABASE_ANON_KEY="${VITE_SUPABASE_ANON_KEY:-${SUPABASE_ANON_KEY:-}}"
export VITE_APP_ENV="${VITE_APP_ENV:-production}"
export VITE_GUEST_APP_URL="${VITE_GUEST_APP_URL:-https://fanzone.guest.ikanisa.com}"
export VITE_PUBLIC_APP_URL="${VITE_PUBLIC_APP_URL:-https://fanzone.ikanisa.com}"
export VITE_TV_DISPLAY_URL="${VITE_TV_DISPLAY_URL:-https://fanzonetv.ikanisa.com}"
export VITE_PRIVILEGED_SESSION_MODE="${VITE_PRIVILEGED_SESSION_MODE:-bff}"

BRANCH="${CLOUDFLARE_PAGES_BRANCH:-main}"
ALLOW_DIRTY="${FANZONE_ALLOW_DIRTY_DEPLOY:-false}"
REQUESTED_APPS=()

for arg in "$@"; do
  case "${arg}" in
    --allow-dirty)
      ALLOW_DIRTY="true"
      ;;
    *)
      REQUESTED_APPS+=("${arg}")
      ;;
  esac
done

if [[ "${ALLOW_DIRTY}" != "true" ]] && [[ -n "$(git status --porcelain)" ]]; then
  git status --short
  echo "Refusing Cloudflare Pages deploy from a dirty worktree. Commit/stash changes, or rerun with --allow-dirty for an explicit local preview." >&2
  exit 1
fi

WRANGLER_DIRTY_ARGS=()
if [[ "${ALLOW_DIRTY}" == "true" ]]; then
  WRANGLER_DIRTY_ARGS=(--commit-dirty=true)
fi

deploy_app() {
  local app="$1"
  local package_name project_name dist_dir

  case "${app}" in
    website)
      package_name="@fanzone/website"
      project_name="${CLOUDFLARE_WEBSITE_PROJECT_NAME:-fanzone-website}"
      dist_dir="apps/website/dist"
      ;;
    admin)
      package_name="@fanzone/admin"
      project_name="${CLOUDFLARE_ADMIN_PROJECT_NAME:-fanzone-admin}"
      dist_dir="apps/admin/dist"
      ;;
    venue-portal)
      package_name="@fanzone/venue-portal"
      project_name="${CLOUDFLARE_VENUE_PORTAL_PROJECT_NAME:-fanzone-venue-portal}"
      dist_dir="apps/venue-portal/dist"
      ;;
    tv-display)
      package_name="@fanzone/tv-display"
      project_name="${CLOUDFLARE_TV_DISPLAY_PROJECT_NAME:-fanzone-tv-display}"
      dist_dir="apps/tv-display/dist"
      ;;
    *)
      echo "Unknown app '${app}'. Expected website, admin, venue-portal, tv-display, or all." >&2
      exit 1
      ;;
  esac

  echo "Validating browser env for ${app}..."
  ./tool/validate_web_release_env.sh "${app}"

  echo "Building ${app}..."
  npm run build -w "${package_name}"

  echo "Deploying ${app} to Cloudflare Pages project ${project_name}..."
  local -a deploy_args=(
    pages
    deploy
    "${dist_dir}"
    "--project-name=${project_name}"
    "--branch=${BRANCH}"
  )
  if [[ "${#WRANGLER_DIRTY_ARGS[@]}" -gt 0 ]]; then
    deploy_args+=("${WRANGLER_DIRTY_ARGS[@]}")
  fi
  npx wrangler "${deploy_args[@]}"
}

if [[ "${REQUESTED_APPS[0]:-all}" == "all" ]]; then
  APPS=(website admin venue-portal tv-display)
else
  APPS=("${REQUESTED_APPS[@]}")
fi

for app in "${APPS[@]}"; do
  deploy_app "${app}"
done
