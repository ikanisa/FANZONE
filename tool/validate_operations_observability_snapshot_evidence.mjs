#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const targetPath =
  process.argv[2] ||
  "release/operations/operations-observability-snapshot-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredControls = [
  "Admin-only operations snapshot RPC exists",
  "Launch observability signals are aggregated",
  "Raw operational rows remain protected",
  "Linked Supabase contract proof passed",
];

const requiredRefs = [
  "supabase/migrations/20260606161000_admin_operations_observability_snapshot.sql",
  "supabase/tests/operations_observability_snapshot.sql",
  "tool/supabase_operations_observability_snapshot.sh",
  "output/release-evidence/operations-observability-snapshot/20260606T061251Z.log",
  "release/operations/observability-telemetry-code-evidence.json",
  "docs/operations/scheduler-observability.md",
  "docs/release/world-class-evidence-matrix.md",
  "docs/release/production-go-live-task-register.md",
];

const requiredFileFragments = new Map([
  [
    "supabase/migrations/20260606161000_admin_operations_observability_snapshot.sql",
    [
      "CREATE OR REPLACE FUNCTION public.admin_operations_observability_snapshot()",
      "SECURITY DEFINER",
      "public.is_admin_manager",
      "Admin operations observability snapshot requires a platform admin",
      "app_runtime_errors",
      "product_events",
      "orders",
      "payment_events",
      "fet_wallet_transactions",
      "match_pools",
      "bell_requests",
      "notification_log",
      "device_tokens",
      "matches",
      "runtime_errors_24h",
      "manual_payments",
      "fet_ledger",
      "push_notifications",
      "latest_livescore_sync_at",
      "REVOKE ALL ON FUNCTION public.admin_operations_observability_snapshot()",
      "GRANT EXECUTE ON FUNCTION public.admin_operations_observability_snapshot()",
    ],
  ],
  [
    "supabase/tests/operations_observability_snapshot.sql",
    [
      "operations_observability_snapshot_passed",
      "Anonymous users must not execute admin_operations_observability_snapshot",
      "admin_operations_observability_snapshot must include",
      "Admin operations observability snapshot requires a platform admin",
    ],
  ],
  [
    "tool/supabase_operations_observability_snapshot.sh",
    [
      "supabase/tests/operations_observability_snapshot.sql",
      "SUPABASE_OPERATIONS_OBSERVABILITY_DB_URL",
      "supabase db query --linked",
      "output/release-evidence/operations-observability-snapshot",
    ],
  ],
  [
    "output/release-evidence/operations-observability-snapshot/20260606T061251Z.log",
    [
      "FANZONE operations observability snapshot",
      "operations_observability_snapshot_passed",
      "supabase/tests/operations_observability_snapshot.sql",
    ],
  ],
]);

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDateTime(value) {
  return (
    hasText(value) &&
    Number.isFinite(Date.parse(value)) &&
    value.includes("T") &&
    value.endsWith("Z")
  );
}

function repoPath(ref) {
  return path.resolve(process.cwd(), ref);
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
}

function gitCommitExists(value) {
  if (!hasText(value) || value === "TBD") return false;
  try {
    execFileSync("git", ["cat-file", "-e", `${value}^{commit}`], {
      cwd: process.cwd(),
      stdio: "ignore",
    });
    return true;
  } catch {
    return false;
  }
}

function requireFragments(errors, ref, fragments) {
  const filePath = repoPath(ref);
  if (!fs.existsSync(filePath)) {
    errors.push(`${ref} must exist.`);
    return;
  }
  const text = fs.readFileSync(filePath, "utf8");
  for (const fragment of fragments) {
    if (!text.includes(fragment)) {
      errors.push(`${ref} must include ${fragment}.`);
    }
  }
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(
    `Operations observability snapshot evidence validation failed for ${targetPath}:`,
  );
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!hasText(data.releaseCandidate)) errors.push("releaseCandidate is required.");
if (!gitCommitExists(data.sourceCommit)) {
  errors.push("sourceCommit must name an existing git commit.");
}
if (!String(data.scope || "").includes("operations observability snapshot")) {
  errors.push("scope must describe operations observability snapshot.");
}
if (data.status !== "PASS_WITH_PENDING_EXTERNAL_OPERATIONS_SIGNOFF") {
  errors.push("status must be PASS_WITH_PENDING_EXTERNAL_OPERATIONS_SIGNOFF.");
}

const controls = Array.isArray(data.controls) ? data.controls : [];
for (const controlName of requiredControls) {
  const control = controls.find((item) => item?.name === controlName);
  if (!control) {
    errors.push(`Missing control: ${controlName}.`);
    continue;
  }
  if (control.status !== "PASS") {
    errors.push(`${controlName} must be PASS.`);
  }
  if (!hasText(control.proof)) {
    errors.push(`${controlName} must include proof.`);
  }
}

const refs = Array.isArray(data.evidenceRefs) ? data.evidenceRefs : [];
for (const ref of requiredRefs) {
  if (!refs.includes(ref)) {
    errors.push(`evidenceRefs must include ${ref}.`);
  }
  requireFragments(errors, ref, requiredFileFragments.get(ref) || []);
}

const commands = Array.isArray(data.commands) ? data.commands : [];
for (const [command, label] of [
  [
    "tool/supabase_operations_observability_snapshot.sh",
    "linked SQL command",
  ],
  [
    "node tool/validate_operations_observability_snapshot_evidence.mjs",
    "validator command",
  ],
  [
    "bash -n tool/supabase_operations_observability_snapshot.sh",
    "shell syntax command",
  ],
]) {
  const item = commands.find((entry) => entry?.command === command);
  if (item?.status !== "PASS") {
    errors.push(`${label} must be recorded with PASS status.`);
  }
}

const pending = Array.isArray(data.pendingExternalEvidence)
  ? data.pendingExternalEvidence
  : [];
for (const required of [
  "Capture production provider dashboard",
  "Capture scheduler provider history",
  "Capture operations owner, incident commander, and release owner signoff",
]) {
  if (!pending.some((item) => String(item).includes(required))) {
    errors.push(`pendingExternalEvidence must include ${required}.`);
  }
}

if (errors.length > 0) {
  console.error(
    `Operations observability snapshot evidence validation failed for ${targetPath}:`,
  );
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(
  `Operations observability snapshot evidence validation passed for ${targetPath}.`,
);
