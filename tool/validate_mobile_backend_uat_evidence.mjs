#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/qa/current-fullstack-supabase-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredFlows = new Map([
  [
    "MOB-SETTLEMENT-001",
    {
      command: "./tool/supabase_mobile_pool_settlement_uat.sh",
      script: "tool/supabase_mobile_pool_settlement_uat.sh",
      sql: "supabase/tests/mobile_pool_settlement_uat.sql",
      logFragments: [
        "FANZONE mobile pool settlement UAT",
        "\"flow_id\": \"MOB-SETTLEMENT-001\"",
        "\"eligible_payout_fet\":",
        "\"eligible_win_tx_id\":",
        "\"settlement_id\":",
        "\"stake_release_count\":",
        "\"eligible_wallet_before\":",
        "\"eligible_wallet_after\":",
      ],
      sqlFragments: [
        "flow_id', 'MOB-SETTLEMENT-001'",
        "public.settle_match_pool",
        "public.get_wallet_balance",
        "RAISE EXCEPTION",
      ],
      proofFragments: [
        "Eligible entry received payout",
        "winner/loser/ineligible stakes were released",
        "linked Supabase SQL",
      ],
    },
  ],
  [
    "MOB-WALLET-001",
    {
      command: "./tool/supabase_mobile_wallet_payment_uat.sh",
      script: "tool/supabase_mobile_wallet_payment_uat.sh",
      sql: "supabase/tests/mobile_wallet_payment_confirmation_uat.sql",
      logFragments: [
        "FANZONE mobile wallet payment-confirmation UAT",
        "\"flow_id\": \"MOB-WALLET-001\"",
        "\"payment_event_id\":",
        "\"audit_id\":",
        "\"wallet_tx_id\":",
        "\"wallet_before\":",
        "\"wallet_after\":",
      ],
      sqlFragments: [
        "'MOB-WALLET-001' AS flow_id",
        "public.venue_update_order_payment_status",
        "public.get_wallet_balance",
        "fet_wallet_transactions",
        "RAISE EXCEPTION",
      ],
      proofFragments: [
        "Manual payment confirmation credited FET rewards",
        "wallet transaction/audit evidence",
        "linked Supabase SQL",
      ],
    },
  ],
]);

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

function pushMissingFragments(errors, label, text, fragments) {
  for (const fragment of fragments) {
    if (!text.includes(fragment)) {
      errors.push(`${label} must include ${fragment}.`);
    }
  }
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Mobile backend UAT evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (data.projectRef !== "kjuhheobmdvjwgnzlcwx") {
  errors.push("projectRef must match the linked production Supabase project.");
}

const mobileUat = Array.isArray(data.mobileUatSql) ? data.mobileUatSql : [];
const mobileUatByFlow = new Map(
  mobileUat
    .filter((flow) => hasText(flow?.flowId))
    .map((flow) => [flow.flowId, flow]),
);

for (const [flowId, expected] of requiredFlows) {
  const item = mobileUatByFlow.get(flowId);
  if (!item) {
    errors.push(`mobileUatSql missing ${flowId}.`);
    continue;
  }
  if (item.status !== "PASS") errors.push(`mobileUatSql.${flowId}.status must be PASS.`);
  if (item.command !== expected.command) {
    errors.push(`mobileUatSql.${flowId}.command must be ${expected.command}.`);
  }
  if (!hasText(item.proof)) {
    errors.push(`mobileUatSql.${flowId}.proof is required.`);
  } else {
    pushMissingFragments(
      errors,
      `mobileUatSql.${flowId}.proof`,
      item.proof,
      expected.proofFragments,
    );
  }

  for (const ref of [expected.script, expected.sql, item.log]) {
    if (!repoRefExists(ref)) {
      errors.push(`mobileUatSql.${flowId} missing repo ref: ${ref}`);
    }
  }

  if (repoRefExists(expected.script)) {
    const script = readText(expected.script);
    if (credentialPattern.test(script)) {
      errors.push(`mobileUatSql.${flowId}.script appears to contain a live credential pattern.`);
    }
    if (!script.includes(expected.sql)) {
      errors.push(`mobileUatSql.${flowId}.script must reference ${expected.sql}.`);
    }
  }

  if (repoRefExists(expected.sql)) {
    const sql = readText(expected.sql);
    if (credentialPattern.test(sql)) {
      errors.push(`mobileUatSql.${flowId}.sql appears to contain a live credential pattern.`);
    }
    pushMissingFragments(errors, `mobileUatSql.${flowId}.sql`, sql, expected.sqlFragments);
  }

  if (repoRefExists(item.log)) {
    const log = readText(item.log);
    if (credentialPattern.test(log)) {
      errors.push(`mobileUatSql.${flowId}.log appears to contain a live credential pattern.`);
    }
    pushMissingFragments(errors, `mobileUatSql.${flowId}.log`, log, expected.logFragments);
    if (log.includes("RAISE EXCEPTION") || log.includes("ERROR:")) {
      errors.push(`mobileUatSql.${flowId}.log must not contain SQL failure output.`);
    }
  }
}

const userVisible = data.userVisibleFlowEvidence?.mobileBackendUat || {};
if (userVisible.status !== "PASS") {
  errors.push("userVisibleFlowEvidence.mobileBackendUat.status must be PASS.");
}
if (userVisible.command !== "node tool/validate_mobile_backend_uat_evidence.mjs") {
  errors.push(
    "userVisibleFlowEvidence.mobileBackendUat.command must be node tool/validate_mobile_backend_uat_evidence.mjs.",
  );
}
if (userVisible.evidence !== "release/qa/current-fullstack-supabase-evidence.json") {
  errors.push(
    "userVisibleFlowEvidence.mobileBackendUat.evidence must be release/qa/current-fullstack-supabase-evidence.json.",
  );
}

if (errors.length > 0) {
  console.error(`Mobile backend UAT evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Mobile backend UAT evidence validation passed for ${targetPath}.`);
