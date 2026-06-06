#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/qa/local-go-live-readiness-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredGateGroups = new Map([
  [
    "repo-safety",
    [
      "git status --short",
      "tracked-file secret regex scan",
      "tool/full_history_secret_scan.sh",
      "tool/audit_repo_hygiene.sh",
      "tool/product_boundary_scan.sh",
      "tool/mobile_release_static_audit.sh",
    ],
  ],
  ["flutter-mobile", ["flutter analyze", "flutter test --coverage"]],
  [
    "web-workspaces",
    [
      "npm run typecheck --workspaces --if-present",
      "npm run lint --workspaces --if-present",
      "npm run test --workspaces --if-present",
      "node tool/test_bff_health.mjs",
      "npm run build --workspaces --if-present",
    ],
  ],
  [
    "supabase-edge",
    [
      "deno fmt --check supabase/functions",
      "find supabase/functions -name '*.ts' -print0 | xargs -0 deno check",
      "deno test --allow-env supabase/functions",
      "deno test test/core_order_lifecycle_test.ts",
    ],
  ],
  [
    "release-evidence-validators",
    [
      "node tool/validate_android_device_uat_evidence.mjs",
      "node tool/validate_android_release_evidence.mjs",
      "node tool/validate_critical_uat_signoff.mjs",
      "node tool/validate_current_fullstack_supabase_evidence.mjs",
      "node tool/validate_edge_function_release_contract.mjs",
      "node tool/validate_games_livescore_fullstack_evidence.mjs",
      "node tool/validate_load_reliability_evidence.mjs",
      "node tool/validate_onboarding_team_catalog_evidence.mjs",
      "node tool/validate_privacy_legal_code_evidence.mjs",
    ],
  ],
]);

const requiredExternalTasks = [
  "android-current-apk-device-rerun",
  "authenticated-live-edge-probes",
  "owner-provider-signoff",
];

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDateTime(value) {
  return hasText(value) && Number.isFinite(Date.parse(value)) &&
    value.includes("T") && value.endsWith("Z");
}

function currentGitHead() {
  try {
    return execFileSync("git", ["rev-parse", "HEAD"], {
      cwd: process.cwd(),
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch (_) {
    return null;
  }
}

function isAncestorCommit(commit, descendant = "HEAD") {
  if (!/^[a-f0-9]{40}$/.test(String(commit || ""))) return false;
  try {
    execFileSync("git", ["merge-base", "--is-ancestor", commit, descendant], {
      cwd: process.cwd(),
      stdio: ["ignore", "ignore", "ignore"],
    });
    return true;
  } catch (_) {
    return false;
  }
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
}

function requireStatus(errors, label, node, expected = "PASS") {
  if (node?.status !== expected) {
    errors.push(`${label}.status must be ${expected}.`);
  }
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Local go-live readiness evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];
const headCommit = currentGitHead();

if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!/^[a-f0-9]{40}$/.test(String(data.sourceCommit || ""))) {
  errors.push("sourceCommit must be a 40-character git SHA.");
} else if (
  headCommit &&
  data.sourceCommit !== headCommit &&
  !isAncestorCommit(data.sourceCommit)
) {
  errors.push("sourceCommit must match or be an ancestor of the current git HEAD.");
}
if (data.branch !== "main") errors.push("branch must be main.");
if (data.status !== "PASS_WITH_EXTERNAL_PROVIDER_TASKS") {
  errors.push("status must be PASS_WITH_EXTERNAL_PROVIDER_TASKS.");
}
if (data.command !== "./tool/go_live_readiness.sh --local") {
  errors.push("command must be ./tool/go_live_readiness.sh --local.");
}
if (!String(data.proof || "").includes("Full local go-live readiness gate passed")) {
  errors.push("proof must mention the full local go-live readiness gate pass.");
}

const groupMap = new Map(
  (Array.isArray(data.passedGateGroups) ? data.passedGateGroups : [])
    .map((group) => [group?.id, group]),
);
for (const [groupId, commands] of requiredGateGroups.entries()) {
  const group = groupMap.get(groupId);
  if (!group) {
    errors.push(`passedGateGroups missing ${groupId}.`);
    continue;
  }
  requireStatus(errors, `passedGateGroups.${groupId}`, group);
  for (const command of commands) {
    if (!Array.isArray(group.commands) || !group.commands.includes(command)) {
      errors.push(`passedGateGroups.${groupId}.commands missing ${command}.`);
    }
  }
}

const flutterGroup = groupMap.get("flutter-mobile");
if (!Number.isInteger(flutterGroup?.testsPassed) || flutterGroup.testsPassed < 288) {
  errors.push("passedGateGroups.flutter-mobile.testsPassed must be at least 288.");
}
const edgeGroup = groupMap.get("supabase-edge");
if (!Number.isInteger(edgeGroup?.edgeFunctionTestsPassed) ||
  edgeGroup.edgeFunctionTestsPassed < 69) {
  errors.push("passedGateGroups.supabase-edge.edgeFunctionTestsPassed must be at least 69.");
}
if (!Number.isInteger(edgeGroup?.coreOrderLifecycleTestsPassed) ||
  edgeGroup.coreOrderLifecycleTestsPassed < 4) {
  errors.push("passedGateGroups.supabase-edge.coreOrderLifecycleTestsPassed must be at least 4.");
}

const externalTaskMap = new Map(
  (Array.isArray(data.externalProviderTasks) ? data.externalProviderTasks : [])
    .map((task) => [task?.id, task]),
);
for (const taskId of requiredExternalTasks) {
  const task = externalTaskMap.get(taskId);
  if (!task) {
    errors.push(`externalProviderTasks missing ${taskId}.`);
    continue;
  }
  if (task.status !== "BLOCKED_EXTERNAL") {
    errors.push(`externalProviderTasks.${taskId}.status must be BLOCKED_EXTERNAL.`);
  }
  if (!hasText(task.proof)) {
    errors.push(`externalProviderTasks.${taskId}.proof is required.`);
  }
}

const notes = Array.isArray(data.notes) ? data.notes.join("\n") : "";
for (const fragment of [
  "local code-owned readiness evidence only",
  "physical-device UAT",
  "provider/operator launch approvals",
]) {
  if (!notes.includes(fragment)) errors.push(`notes must include ${fragment}.`);
}

if (errors.length > 0) {
  console.error(`Local go-live readiness evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Local go-live readiness evidence validation passed for ${targetPath}.`);
