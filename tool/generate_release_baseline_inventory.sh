#!/usr/bin/env bash
# Generate a source-commit-bound FANZONE release baseline inventory.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

fail_on_blockers=false
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
out_dir="output/release-evidence/${timestamp}/baseline"

usage() {
  cat >&2 <<'USAGE'
Usage: tool/generate_release_baseline_inventory.sh [--out-dir DIR] [--fail-on-blockers]

Creates a read-only release baseline report with git state, evidence matrix
inventory, task register references, and fail-closed validator results.

The default mode is inventory-only: expected validator failures are recorded
without making report generation fail. Use --fail-on-blockers only in a final
release gate where any blocker should make the command exit non-zero.
USAGE
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --out-dir)
      [[ "$#" -ge 2 ]] || {
        usage
        exit 2
      }
      out_dir="$2"
      shift 2
      ;;
    --fail-on-blockers)
      fail_on_blockers=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

logs_dir="${out_dir}/logs"
mkdir -p "${logs_dir}"

report="${out_dir}/current-state.md"
summary="${out_dir}/validator-summary.tsv"
blocker_count=0
validator_blockers=0

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

status_is_ready() {
  case "$1" in
    PASS | N/A) return 0 ;;
    *) return 1 ;;
  esac
}

markdown_escape() {
  printf '%s' "$1" | sed 's/|/\\|/g'
}

run_validator() {
  local label="$1"
  shift
  local slug
  slug="$(printf '%s' "${label}" | tr '[:upper:] ' '[:lower:]-' | tr -cd '[:alnum:]-_')"
  local log="${logs_dir}/${slug}.log"

  if "$@" >"${log}" 2>&1; then
    printf '%s\tPASS\t%s\n' "${label}" "${log}" >>"${summary}"
  else
    printf '%s\tFAIL\t%s\n' "${label}" "${log}" >>"${summary}"
    blocker_count=$((blocker_count + 1))
    validator_blockers=$((validator_blockers + 1))
  fi
}

matrix_inventory() {
  local matrix="docs/release/world-class-evidence-matrix.md"
  awk '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    function ready(status) {
      return status == "PASS" || status == "N/A"
    }
    /^## P[0-9]+ Evidence Matrix$/ {
      priority=$2
      next
    }
    /^\|/ && $0 !~ /\| ---/ && $0 !~ /\| Control \|/ && priority != "" {
      split($0, cells, "|")
      control=trim(cells[2])
      flutter=trim(cells[3])
      venue=trim(cells[4])
      admin=trim(cells[5])
      tv=trim(cells[6])
      evidence=trim(cells[7])
      decision=(ready(flutter) && ready(venue) && ready(admin) && ready(tv) && evidence != "" && evidence != "TBD" && tolower(evidence) !~ /evidence required/) ? "READY-ROW" : "BLOCKED"
      gsub(/\|/, "\\|", control)
      gsub(/\|/, "\\|", evidence)
      printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", priority, control, flutter, venue, admin, tv, decision, evidence
    }
  ' "${matrix}"
}

matrix_blocker_count() {
  local priority_pattern="${1:-P[0-9]+}"
  matrix_inventory | awk -F'|' -v priority_pattern="${priority_pattern}" '
    NR > 0 {
      priority=$2
      decision=$8
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", priority)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", decision)
      if (priority ~ priority_pattern && decision == "BLOCKED") count++
    }
    END { print count + 0 }
  '
}

git_head="$(git rev-parse --short HEAD)"
git_branch="$(git rev-parse --abbrev-ref HEAD)"
git_status="$(git status --short)"
remote_head="unavailable"
if git rev-parse --verify origin/main >/dev/null 2>&1; then
  remote_head="$(git rev-parse --short origin/main)"
fi
divergence="unavailable"
if git rev-parse --verify main >/dev/null 2>&1 && git rev-parse --verify origin/main >/dev/null 2>&1; then
  divergence="$(git rev-list --left-right --count main...origin/main)"
fi

: >"${summary}"
run_validator "release evidence contract" tool/validate_release_evidence_contract.sh
run_validator "world-class evidence gate" tool/check_world_class_evidence.sh
run_validator "secret rotation evidence" node tool/validate_secret_rotation_evidence.mjs
run_validator "critical UAT evidence" node tool/validate_critical_uat_signoff.mjs
run_validator "Android release evidence" node tool/validate_android_release_evidence.mjs
run_validator "iOS TestFlight evidence" node tool/validate_ios_testflight_evidence.mjs
run_validator "operations readiness evidence" node tool/validate_operations_readiness_evidence.mjs
run_validator "privacy legal readiness evidence" node tool/validate_privacy_legal_readiness_evidence.mjs
run_validator "load reliability evidence" node tool/validate_load_reliability_evidence.mjs

matrix_p0_p1_blockers="$(matrix_blocker_count 'P[01]')"
matrix_all_blockers="$(matrix_blocker_count 'P[0-9]+')"
if [[ "${matrix_p0_p1_blockers}" -ne 0 ]]; then
  blocker_count=$((blocker_count + matrix_p0_p1_blockers))
fi

{
  echo "# FANZONE Release Baseline Inventory"
  echo
  echo "Generated: ${timestamp}"
  echo
  echo "This is an inventory snapshot, not launch approval. FANZONE remains"
  echo "\`NO-GO\` unless every P0/P1 control has real evidence and all fail-closed"
  echo "release gates pass."
  echo
  echo "## Repository State"
  echo
  echo "| Item | Evidence |"
  echo "| --- | --- |"
  echo "| Branch | \`${git_branch}\` |"
  echo "| Source commit | \`${git_head}\` |"
  echo "| Remote main | \`${remote_head}\` |"
  echo "| Divergence | \`${divergence}\` |"
  if [[ -z "${git_status}" ]]; then
    echo "| Working tree | Clean |"
  else
    echo "| Working tree | Dirty; see \`${logs_dir}/git-status.log\` |"
    printf '%s\n' "${git_status}" >"${logs_dir}/git-status.log"
  fi
  echo "| Report root | \`${out_dir}\` |"
  echo "| Validator blockers | \`${validator_blockers}\` |"
  echo "| P0/P1 matrix blocker rows | \`${matrix_p0_p1_blockers}\` |"
  echo "| All matrix blocker rows | \`${matrix_all_blockers}\` |"
  echo
  echo "## Validator Results"
  echo
  echo "| Validator | Result | Log |"
  echo "| --- | --- | --- |"
  while IFS=$'\t' read -r label result log; do
    echo "| $(markdown_escape "${label}") | \`${result}\` | \`${log}\` |"
  done <"${summary}"
  echo
  echo "## Evidence Matrix Inventory"
  echo
  echo "| Priority | Control | Flutter app | Bars/Venue PWA | Admin PWA | TV PWA | Decision | Evidence |"
  echo "| --- | --- | --- | --- | --- | --- | --- | --- |"
  matrix_inventory
  echo
  echo "## Task Register Source"
  echo
  echo "- Authoritative task register: \`docs/release/production-go-live-task-register.md\`"
  echo "- World-class benchmark: \`docs/release/world-class-production-benchmark.md\`"
  echo "- Evidence matrix: \`docs/release/world-class-evidence-matrix.md\`"
  echo "- Final launch gate: \`tool/check_world_class_evidence.sh\`"
  echo
  echo "## Launch Decision"
  echo
  if [[ "${blocker_count}" -eq 0 ]]; then
    echo "Decision: \`CANDIDATE-GO\`"
    echo
    echo "No blockers were found by this inventory. Run the full release checklist,"
    echo "\`tool/collect_world_class_evidence.sh\`, \`tool/go_live_readiness.sh --local\`,"
    echo "and provider signoff checks before launch."
  else
    echo "Decision: \`NO-GO\`"
    echo
    echo "Open blocker signals: ${blocker_count}"
  fi
} >"${report}"

echo "Release baseline inventory written to ${report}"

if [[ "${blocker_count}" -ne 0 && "${fail_on_blockers}" == true ]]; then
  echo "Release baseline inventory found ${blocker_count} blocker signal(s)." >&2
  exit 1
fi
