#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const targetPath =
  process.argv[2] || "release/qa/api-authorization-abuse-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredScenarios = [
  "anonymous access rejection",
  "wrong-role RPC rejection",
  "cross-user order isolation",
  "cross-venue staff isolation",
  "cross-venue manual payment rejection",
  "direct table mutation denial",
  "unsupported payment method rejection",
  "portable audit-log evidence checks",
];

const requiredSqlRefs = new Map([
  [
    "supabase/tests/rls_hardening_audit.sql",
    [
      "Auditing RLS and client grants",
      "has_table_privilege",
      "has_function_privilege",
    ],
  ],
  [
    "supabase/tests/order_lifecycle_contract.sql",
    [
      "Verifying order lifecycle contract",
      "Customer inserted order_state_events unexpectedly",
      "venue_transition_order_status",
      "Unsupported card payment unexpectedly succeeded",
    ],
  ],
  [
    "supabase/tests/manual_payment_reconciliation_contract.sql",
    [
      "manual payment reconciliation",
      "venue_manual_payment_reconciliation",
      "Cross-venue reconciliation unexpectedly succeeded",
    ],
  ],
  [
    "supabase/tests/staff_call_acknowledgement_contract.sql",
    [
      "staff-call acknowledgement contract",
      "Direct authenticated bell_requests UPDATE",
      "cross-venue staff",
    ],
  ],
]);

const requiredScripts = [
  "tool/supabase_api_authorization_abuse_tests.sh",
  "tool/supabase_rls_audit.sh",
  "tool/supabase_hospitality_core_phase2.sh",
  "tool/supabase_order_lifecycle_smoke.sh",
  "tool/supabase_manual_payment_reconciliation_smoke.sh",
  "tool/supabase_staff_call_acknowledgement_smoke.sh",
];

const requiredEdgeCommands = [
  "tool/supabase_app_edge_smoke.sh",
  "tool/supabase_game_edge_smoke.sh",
  "tool/supabase_whatsapp_auth_smoke.sh",
  "tool/supabase_edge_job_smoke.sh --unauthorized-only",
  "node tool/validate_edge_function_release_contract.mjs",
];

function hasText(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDateTime(value) {
  return hasText(value) && Number.isFinite(Date.parse(value)) &&
    value.includes("T") && value.endsWith("Z");
}

function repoPath(ref) {
  return path.resolve(process.cwd(), ref);
}

function repoRefExists(ref) {
  return hasText(ref) && fs.existsSync(repoPath(ref));
}

function readText(ref) {
  return fs.readFileSync(repoPath(ref), "utf8");
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

function requireFragments(errors, label, text, fragments) {
  for (const fragment of fragments) {
    if (!text.toLowerCase().includes(fragment.toLowerCase())) {
      errors.push(`${label} must include ${fragment}.`);
    }
  }
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`API authorization abuse evidence validation failed for ${targetPath}:`);
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
if (data.projectRef !== "kjuhheobmdvjwgnzlcwx") {
  errors.push("projectRef must match the linked production Supabase project.");
}
if (!String(data.scope || "").includes("authorization abuse")) {
  errors.push("scope must describe authorization abuse coverage.");
}

const contract = data.contractRun || {};
if (contract.command !== "./tool/supabase_api_authorization_abuse_tests.sh --contract") {
  errors.push("contractRun.command must be ./tool/supabase_api_authorization_abuse_tests.sh --contract.");
}
if (contract.status !== "PASS") errors.push("contractRun.status must be PASS.");
if (!isIsoDateTime(contract.executedAtUtc)) {
  errors.push("contractRun.executedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!repoRefExists(contract.log)) {
  errors.push(`contractRun.log does not exist: ${contract.log}`);
} else {
  const log = readText(contract.log);
  if (credentialPattern.test(log)) {
    errors.push("contractRun.log appears to contain a live credential pattern.");
  }
  requireFragments(errors, "contractRun.log", log, [
    "FANZONE backend authorization abuse contract",
    "Project ref: kjuhheobmdvjwgnzlcwx",
    "Command: ./tool/supabase_api_authorization_abuse_tests.sh --contract",
    "Initialising login role",
    "\"rows\": []",
    "set_config",
  ]);
  if (/\b(ERROR|FAIL|EXCEPTION)\b/i.test(log)) {
    errors.push("contractRun.log must not contain SQL failure output.");
  }
}

const coveredScenarios = new Set(data.coveredAbuseScenarios || []);
for (const scenario of requiredScenarios) {
  if (!coveredScenarios.has(scenario)) {
    errors.push(`coveredAbuseScenarios missing ${scenario}.`);
  }
}

const sqlRefs = new Set(data.sqlContractRefs || []);
for (const [ref, fragments] of requiredSqlRefs) {
  if (!sqlRefs.has(ref)) errors.push(`sqlContractRefs missing ${ref}.`);
  if (!repoRefExists(ref)) {
    errors.push(`SQL contract ref does not exist: ${ref}`);
    continue;
  }
  const text = readText(ref);
  if (credentialPattern.test(text)) {
    errors.push(`${ref} appears to contain a live credential pattern.`);
  }
  requireFragments(errors, ref, text, fragments);
}

const scriptRefs = new Set(data.scriptRefs || []);
for (const ref of requiredScripts) {
  if (!scriptRefs.has(ref)) errors.push(`scriptRefs missing ${ref}.`);
  if (!repoRefExists(ref)) errors.push(`Script ref does not exist: ${ref}`);
}

const edge = data.edgeFunctionAuthCoverage || {};
if (edge.status !== "PASS") errors.push("edgeFunctionAuthCoverage.status must be PASS.");
if (edge.evidence !== "release/qa/current-fullstack-supabase-evidence.json") {
  errors.push("edgeFunctionAuthCoverage.evidence must be release/qa/current-fullstack-supabase-evidence.json.");
}
if (!repoRefExists(edge.evidence)) {
  errors.push(`edgeFunctionAuthCoverage.evidence does not exist: ${edge.evidence}`);
}
const edgeCommands = new Set(edge.commands || []);
for (const command of requiredEdgeCommands) {
  if (!edgeCommands.has(command)) {
    errors.push(`edgeFunctionAuthCoverage.commands missing ${command}.`);
  }
}
requireFragments(errors, "edgeFunctionAuthCoverage.proof", edge.proof || "", [
  "anonymous rejection",
  "verified JWT",
  "Edge Functions",
]);

const critical = data.criticalUatRef || {};
if (critical.status !== "PASS") errors.push("criticalUatRef.status must be PASS.");
if (critical.evidence !== "release/qa/critical-user-flow-uat.json") {
  errors.push("criticalUatRef.evidence must be release/qa/critical-user-flow-uat.json.");
}
if (critical.flowId !== "BACKEND-ISO-001") {
  errors.push("criticalUatRef.flowId must be BACKEND-ISO-001.");
}
if (repoRefExists(critical.evidence)) {
  const uat = readJson(repoPath(critical.evidence));
  const flow = (uat.flows || []).find((item) => item?.id === "BACKEND-ISO-001");
  if (!flow) {
    errors.push("critical UAT evidence is missing BACKEND-ISO-001.");
  } else {
    if (flow.status !== "PASS") errors.push("critical UAT BACKEND-ISO-001 status must be PASS.");
    if (!String(flow.notes || "").includes("cross-user")) {
      errors.push("critical UAT BACKEND-ISO-001 notes must mention cross-user coverage.");
    }
    if (!String(flow.notes || "").includes("cross-venue")) {
      errors.push("critical UAT BACKEND-ISO-001 notes must mention cross-venue coverage.");
    }
  }
} else {
  errors.push(`criticalUatRef.evidence does not exist: ${critical.evidence}`);
}

if (data.validator?.command !== "node tool/validate_api_authorization_abuse_evidence.mjs") {
  errors.push("validator.command must be node tool/validate_api_authorization_abuse_evidence.mjs.");
}
if (data.validator?.status !== "PASS") errors.push("validator.status must be PASS.");

if (errors.length > 0) {
  console.error(`API authorization abuse evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`API authorization abuse evidence validation passed for ${targetPath}.`);
