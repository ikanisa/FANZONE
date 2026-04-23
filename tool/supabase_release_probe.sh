#!/usr/bin/env bash
set -euo pipefail

if [[ -f ".env" ]]; then
  set -a
  source .env
  set +a
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "SUPABASE_URL and SUPABASE_ANON_KEY must be set in the environment or .env."
  exit 1
fi

api_get_status() {
  local path="$1"
  curl -s -o /dev/null -w '%{http_code}' \
    "${SUPABASE_URL}/rest/v1/${path}" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}"
}

auth_status="$(curl -s -o /dev/null -w '%{http_code}' \
  "${SUPABASE_URL}/auth/v1/settings" \
  -H "apikey: ${SUPABASE_ANON_KEY}")"
matches_status="$(api_get_status 'matches?select=id&limit=1')"
app_matches_status="$(api_get_status 'app_matches?select=id&limit=1')"
leaderboard_status="$(api_get_status 'public_leaderboard?select=*')"
standings_status="$(api_get_status 'standings?select=id&limit=1')"
team_aliases_status="$(api_get_status 'team_aliases?select=id&limit=1')"
prediction_output_status="$(api_get_status 'predictions_engine_outputs?select=id&limit=1')"
wallet_status="$(api_get_status 'fet_wallets?select=user_id&limit=1')"
transactions_status="$(api_get_status 'fet_wallet_transactions?select=id&limit=1')"
profiles_status="$(api_get_status 'profiles?select=id&limit=1')"
wallet_body="$(curl -s \
  "${SUPABASE_URL}/rest/v1/fet_wallets?select=user_id&limit=1" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}")"
transactions_body="$(curl -s \
  "${SUPABASE_URL}/rest/v1/fet_wallet_transactions?select=id&limit=1" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}")"
profiles_body="$(curl -s \
  "${SUPABASE_URL}/rest/v1/profiles?select=id&limit=1" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}")"

favorite_team_write_status="$(curl -s -o /dev/null -w '%{http_code}' \
  -X POST "${SUPABASE_URL}/rest/v1/user_favorite_teams" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"00000000-0000-0000-0000-000000000000","team_id":"release-probe","team_name":"Release Probe"}')"
competition_follow_write_status="$(curl -s -o /dev/null -w '%{http_code}' \
  -X POST "${SUPABASE_URL}/rest/v1/user_followed_competitions" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"00000000-0000-0000-0000-000000000000","competition_id":"release-probe"}')"

echo "auth.settings                ${auth_status}"
echo "matches.read                 ${matches_status}"
echo "app_matches.read             ${app_matches_status}"
echo "public_leaderboard.read      ${leaderboard_status}"
echo "standings.read               ${standings_status}"
echo "team_aliases.read            ${team_aliases_status}"
echo "predictions_engine_outputs.read ${prediction_output_status}"
echo "fet_wallets.read             ${wallet_status}"
echo "fet_wallet_transactions.read ${transactions_status}"
echo "profiles.read                ${profiles_status}"
echo "user_favorite_teams.write    ${favorite_team_write_status}"
echo "user_followed_competitions.write ${competition_follow_write_status}"

[[ "${auth_status}" == "200" ]] || {
  echo "Auth settings endpoint failed."
  exit 1
}
[[ "${matches_status}" == "200" ]] || {
  echo "Public matches read failed."
  exit 1
}
[[ "${app_matches_status}" == "200" ]] || {
  echo "app_matches is not readable."
  exit 1
}
[[ "${leaderboard_status}" == "200" ]] || {
  echo "public_leaderboard is not readable."
  exit 1
}
[[ "${team_aliases_status}" == "200" ]] || {
  echo "team_aliases is not readable."
  exit 1
}
[[ "${standings_status}" == "200" ]] || {
  echo "standings is not readable."
  exit 1
}
[[ "${prediction_output_status}" == "200" ]] || {
  echo "predictions_engine_outputs is not readable."
  exit 1
}
[[ "${favorite_team_write_status}" != "201" ]] || {
  echo "Protected favorite-team table accepted anon writes."
  exit 1
}
[[ "${competition_follow_write_status}" != "201" ]] || {
  echo "Protected competition follow table accepted anon writes."
  exit 1
}
[[ "${wallet_body}" == "[]" ]] || {
  echo "fet_wallets leaked data to an anonymous request."
  exit 1
}
[[ "${transactions_body}" == "[]" ]] || {
  echo "fet_wallet_transactions leaked data to an anonymous request."
  exit 1
}
if [[ "${profiles_status}" == "200" ]]; then
  [[ "${profiles_body}" == "[]" ]] || {
    echo "profiles leaked data to an anonymous request."
    exit 1
  }
elif [[ "${profiles_status}" != "401" && "${profiles_status}" != "403" ]]; then
  echo "profiles probe returned an unexpected status (${profiles_status})."
  exit 1
fi

if [[ "${ENABLE_WALLET:-false}" == "true" ]]; then
  [[ "${wallet_status}" == "200" ]] || {
    echo "Wallet is enabled but fet_wallets is unavailable."
    exit 1
  }
  [[ "${transactions_status}" == "200" ]] || {
    echo "Wallet is enabled but fet_wallet_transactions is unavailable."
    exit 1
  }
fi

echo "Supabase release probe passed."
