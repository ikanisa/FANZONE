#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI is required." >&2
  exit 1
fi

PROJECT_REF="${1:-}"

if [[ -z "$PROJECT_REF" ]]; then
  PROJECT_REF="$(
    python3 - <<'PY'
import json
from pathlib import Path

env_path = Path("env/production.json")
if not env_path.exists():
    raise SystemExit("")

data = json.loads(env_path.read_text())
url = (data.get("SUPABASE_URL") or "").strip()
if ".supabase.co" in url:
    print(url.split("https://", 1)[-1].split(".supabase.co", 1)[0])
PY
  )"
fi

if [[ -z "$PROJECT_REF" ]]; then
  echo "Usage: $0 <project-ref>" >&2
  echo "Or ensure env/production.json contains SUPABASE_URL." >&2
  exit 1
fi

echo "Deploying team crest infrastructure to project: $PROJECT_REF"

if [[ -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
  echo "Linking project with provided SUPABASE_DB_PASSWORD..."
  supabase link --project-ref "$PROJECT_REF" -p "$SUPABASE_DB_PASSWORD"

  echo "Applying remote migrations..."
  supabase db push --linked --include-all
else
  echo "SUPABASE_DB_PASSWORD is not set; skipping remote migration push." >&2
  echo "Set SUPABASE_DB_PASSWORD to apply $ROOT_DIR/supabase/migrations/20260420020000_team_crest_registry.sql" >&2
fi

if [[ -n "${GEMINI_API_KEY:-}" || -n "${TEAM_CREST_SYNC_SECRET:-}" || -n "${TEAM_CREST_BUCKET:-}" ]]; then
  echo "Updating Edge Function secrets..."
  secret_args=()

  if [[ -n "${GEMINI_API_KEY:-}" ]]; then
    secret_args+=("GEMINI_API_KEY=${GEMINI_API_KEY}")
  fi

  if [[ -n "${TEAM_CREST_SYNC_SECRET:-}" ]]; then
    secret_args+=("TEAM_CREST_SYNC_SECRET=${TEAM_CREST_SYNC_SECRET}")
  fi

  if [[ -n "${TEAM_CREST_BUCKET:-}" ]]; then
    secret_args+=("TEAM_CREST_BUCKET=${TEAM_CREST_BUCKET}")
  fi

  supabase secrets set --project-ref "$PROJECT_REF" "${secret_args[@]}"
else
  echo "No GEMINI_API_KEY / TEAM_CREST_SYNC_SECRET / TEAM_CREST_BUCKET values provided; skipping secrets update." >&2
fi

echo "Deploying gemini-team-crests Edge Function..."
supabase functions deploy gemini-team-crests --project-ref "$PROJECT_REF" --use-api --no-verify-jwt

echo "Done."
