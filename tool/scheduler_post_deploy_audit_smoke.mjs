#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const projectRef = "kjuhheobmdvjwgnzlcwx";
const supabaseUrl = (
  process.env.SUPABASE_URL || `https://${projectRef}.supabase.co`
).replace(/\/$/, "");

const credentialCandidates = [
  ["CRON_SECRET", "x-cron-secret", process.env.CRON_SECRET],
  ["EDGE_SERVICE_ROLE_KEY", "Authorization", process.env.EDGE_SERVICE_ROLE_KEY],
  [
    "SUPABASE_SERVICE_ROLE_KEY",
    "Authorization",
    process.env.SUPABASE_SERVICE_ROLE_KEY,
  ],
];

const credential = credentialCandidates.find(([, , value]) =>
  typeof value === "string" && value.trim().length > 0
);

const jobs = [
  {
    id: "settle-match-pools",
    command: "tool/run_supabase_cron_job.sh settle-match-pools",
    payload: { limit: 50 },
  },
  {
    id: "dispatch-match-alerts",
    command: "tool/run_supabase_cron_job.sh dispatch-match-alerts",
    payload: {},
  },
  {
    id: "sync-livescore-football",
    command: "tool/run_supabase_cron_job.sh sync-livescore-football",
    payload: {
      resource_id: "livescore_world_cup_2026",
      apply: true,
      include_details: false,
      include_scoreboard: true,
      limit: 200,
      delay_ms: 750,
    },
  },
];

function isoNow() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function stampNow() {
  return isoNow().replace(/[-:]/g, "");
}

function ensureNoCredential(value) {
  const text = JSON.stringify(value);
  for (const [, , secret] of credentialCandidates) {
    if (secret && text.includes(secret)) {
      throw new Error("Refusing to write evidence containing a credential value.");
    }
  }
}

function observedFor(jobId, body) {
  if (jobId === "settle-match-pools") {
    return {
      settledPools: Number(body.settled_pools ?? 0),
      limit: Number(body.limit ?? 0),
      audit: body.audit,
    };
  }
  if (jobId === "dispatch-match-alerts") {
    return {
      kickoffSent: Number(body.kickoff_sent ?? 0),
      goalSent: Number(body.goal_sent ?? 0),
      resultSent: Number(body.result_sent ?? 0),
      dispatchRowsWritten: Number(body.dispatch_rows_written ?? 0),
      errors: Array.isArray(body.errors) ? body.errors : [],
      audit: body.audit,
    };
  }
  return {
    resourceId: String(body.resource_id ?? ""),
    rows: Number(body.rows ?? 0),
    syncRunId: String(body.sync_run_id ?? ""),
    stagedRows: Number(body.staged?.staged_rows ?? 0),
    receivedRows: Number(body.staged?.received_rows ?? 0),
    needsReviewRows: Number(body.staged?.needs_review_rows ?? 0),
    appliedRows: Number(body.applied?.applied_rows ?? 0),
    liveStateUpdatedRows: Number(body.live_state?.updated_rows ?? 0),
    audit: body.audit,
  };
}

async function runJob(job, headerName, headerValue) {
  const response = await fetch(`${supabaseUrl}/functions/v1/${job.id}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      [headerName]: headerName === "Authorization"
        ? `Bearer ${headerValue}`
        : headerValue,
    },
    body: JSON.stringify(job.payload),
  });

  const text = await response.text();
  let body = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text.slice(0, 500) };
  }

  const observed = observedFor(job.id, body);
  const audit = observed.audit;
  const auditTracked = Boolean(
    audit &&
      typeof audit === "object" &&
      audit.status === "tracked" &&
      typeof audit.run_id === "string" &&
      audit.run_id.length > 0,
  );

  return {
    id: job.id,
    command: job.command,
    status: response.ok && auditTracked ? "PASS" : "FAIL",
    httpStatus: response.status,
    auditTracked,
    observed,
  };
}

if (!credential) {
  console.error(
    "Missing CRON_SECRET, EDGE_SERVICE_ROLE_KEY, or SUPABASE_SERVICE_ROLE_KEY.",
  );
  console.error(
    "Set one credential only in the local process environment and rerun this smoke. The value is never written to evidence.",
  );
  process.exit(2);
}

const [credentialName, headerName, headerValue] = credential;
const generatedAtUtc = isoNow();
const results = [];
for (const job of jobs) {
  results.push(await runJob(job, headerName, headerValue.trim()));
}

const evidence = {
  generatedAtUtc,
  scope:
    "Post-deploy scheduler Edge smoke proving deployed cron functions write database-backed audit run ids",
  projectRef,
  supabaseUrl,
  secretValuesPrinted: false,
  credentialHandling: {
    credentialSource: credentialName,
    notes:
      "Credential was read only from the local process environment. Secret values are not written to tracked files or evidence.",
  },
  jobs: results,
  remainingOperationsGates: [
    "Provider scheduler history evidence is still required before scheduler readiness can be marked PASS.",
    "Delivered missed-run alert evidence is still required before scheduler readiness can be marked PASS.",
    "Operations owner, release owner, incident commander, observability dashboard, alert route, rollback, and incident-response signoff remain required by release/operations/operations-readiness-evidence.json.",
  ],
};

ensureNoCredential(evidence);

const outputDir = path.resolve(
  process.cwd(),
  "output/release-evidence/scheduler-post-deploy-smoke",
);
fs.mkdirSync(outputDir, { recursive: true });
const outputPath = path.join(outputDir, `${stampNow()}.json`);
fs.writeFileSync(outputPath, `${JSON.stringify(evidence, null, 2)}\n`);

const failed = results.filter((result) => result.status !== "PASS");
console.log(`Scheduler post-deploy smoke evidence: ${outputPath}`);
for (const result of results) {
  console.log(
    `${result.id}: ${result.status} HTTP ${result.httpStatus} auditTracked=${result.auditTracked}`,
  );
}

if (failed.length > 0) {
  process.exit(1);
}
