#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const repo = process.env.GITHUB_REPOSITORY || "ikanisa/FANZONE";
const outputPath =
  process.argv[2] || "release/operations/scheduler-provider-state-evidence.json";
const generatedAtUtc = new Date().toISOString();
const stamp = generatedAtUtc.replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
const archivePath =
  `output/release-evidence/scheduler-provider-state/${stamp}.json`;

const expectedJobs = [
  {
    id: "settle-match-pools",
    workflowName: "Match Pool Settlement Cron",
    workflowPath: ".github/workflows/cron-settle.yml",
    expectedCron: "*/15 * * * *",
  },
  {
    id: "dispatch-match-alerts",
    workflowName: "Match Alert Dispatch Cron",
    workflowPath: ".github/workflows/cron-match-alerts.yml",
    expectedCron: "*/5 * * * *",
  },
  {
    id: "sync-livescore-football",
    workflowName: "LiveScore Football Sync Cron",
    workflowPath: ".github/workflows/cron-livescore-football.yml",
    expectedCron: "7 * * * *",
  },
];

function repoPath(ref) {
  return path.resolve(process.cwd(), ref);
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function runGhJson(args) {
  const output = execFileSync("gh", args, {
    cwd: process.cwd(),
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  return JSON.parse(output);
}

function safeGhJson(args) {
  try {
    return { ok: true, data: runGhJson(args) };
  } catch (error) {
    return {
      ok: false,
      error: String(error.stderr || error.message || error).slice(0, 400),
    };
  }
}

function localWorkflowCron(workflowPath) {
  const text = fs.readFileSync(repoPath(workflowPath), "utf8");
  const match = text.match(/cron:\s*["']([^"']+)["']/);
  return match?.[1] || "";
}

const workflowsResponse = runGhJson([
  "api",
  `repos/${repo}/actions/workflows`,
  "--paginate",
]);
const workflows = Array.isArray(workflowsResponse.workflows)
  ? workflowsResponse.workflows
  : [];

const jobs = expectedJobs.map((job) => {
  const workflow = workflows.find((item) => item.path === job.workflowPath);
  const localCron = localWorkflowCron(job.workflowPath);
  const runsResponse = workflow?.id
    ? safeGhJson([
      "api",
      `repos/${repo}/actions/workflows/${workflow.id}/runs?branch=main&event=schedule&per_page=5`,
    ])
    : { ok: false, error: "Workflow not found on default branch." };
  const runs = runsResponse.ok && Array.isArray(runsResponse.data.workflow_runs)
    ? runsResponse.data.workflow_runs
    : [];
  const recentRuns = runs.map((run) => ({
    idSha256: sha256(String(run.id || "")),
    status: run.status || "",
    conclusion: run.conclusion || "",
    event: run.event || "",
    branch: run.head_branch || "",
    createdAtUtc: run.created_at || "",
    updatedAtUtc: run.updated_at || "",
  }));
  const latestRun = recentRuns[0] || null;
  const providerState =
    !workflow
      ? "MISSING_WORKFLOW_ON_DEFAULT_BRANCH"
      : workflow.state !== "active"
      ? "WORKFLOW_NOT_ACTIVE"
      : !latestRun
      ? "MISSING_SCHEDULE_RUN_HISTORY"
      : latestRun.status === "completed" && latestRun.conclusion === "success"
      ? "PASS"
      : "RECENT_SCHEDULE_RUN_NOT_SUCCESSFUL";

  return {
    id: job.id,
    workflowName: job.workflowName,
    workflowPath: job.workflowPath,
    expectedCron: job.expectedCron,
    localCron,
    workflowFoundOnDefaultBranch: Boolean(workflow),
    workflowState: workflow?.state || "missing",
    workflowIdSha256: workflow?.id ? sha256(String(workflow.id)) : "",
    providerState,
    recentScheduledRuns: recentRuns,
    providerQueryError: runsResponse.ok ? "" : runsResponse.error,
  };
});

const allPass = jobs.every((job) => job.providerState === "PASS");
const evidence = {
  schemaVersion: 1,
  generatedAtUtc,
  repo,
  scope:
    "Credential-free GitHub Actions provider scheduler state for FANZONE production cron workflows",
  command: "node tool/capture_scheduler_provider_state.mjs",
  status: allPass ? "PASS" : "BLOCKED_PROVIDER_STATE",
  jobs,
  notes: [
    "This evidence intentionally records provider state; it must not mark launch-ready if workflows are missing or recent scheduled runs failed.",
    "The local workflow files define the intended cron cadence, but provider run history is authoritative for activation proof.",
    "Run IDs are SHA-256 hashed and no GitHub token or secret value is written to evidence.",
  ],
  pendingExternalEvidence: allPass
    ? []
    : [
      "Push or merge the current scheduler workflow changes to the default branch.",
      "Verify GitHub Actions scheduled runs complete successfully for all three scheduler workflows.",
      "Capture delivered missed-run alert evidence and operations owner signoff.",
    ],
};

for (const target of [outputPath, archivePath]) {
  fs.mkdirSync(path.dirname(repoPath(target)), { recursive: true });
  fs.writeFileSync(repoPath(target), `${JSON.stringify(evidence, null, 2)}\n`);
}

console.log(
  `Scheduler provider state ${evidence.status}: ${jobs.filter((job) => job.providerState === "PASS").length}/${jobs.length} jobs provider-ready.`,
);
console.log(`Evidence: ${outputPath}`);
console.log(`Archive: ${archivePath}`);
