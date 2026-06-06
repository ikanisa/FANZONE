#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const targetPath =
  process.argv[2] || "release/operations/incident-rollback-code-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@|Bearer\s+[A-Za-z0-9._~+/\-]+=*)/;
const privateEmailPattern =
  /\b[A-Z0-9._%+-]+@(?!example\.com\b|example\.test\b)[A-Z0-9.-]+\.[A-Z]{2,}\b/i;

const requiredControls = [
  "Incident readiness bundle structure generated",
  "Rollback safeguards are documented",
  "Post-deploy watch signals are mapped",
  "Private owner data is not committed",
];

const requiredBundleFiles = [
  "manifest.json",
  "owners-and-escalation-redacted.txt",
  "rollback-tag.txt",
  "database-restore-plan.txt",
  "runbook-review.txt",
  "post-deploy-watch.txt",
  "sample-alert-test-redacted.txt",
];

const requiredRefs = [
  "tool/generate_incident_readiness_bundle.mjs",
  "docs/operations/incident-runbooks.md",
  "docs/release/rollback.md",
  "docs/operations/scheduler-observability.md",
  "release/operations/operations-observability-snapshot-evidence.json",
];

const requiredFragments = new Map([
  [
    "tool/generate_incident_readiness_bundle.mjs",
    [
      "owners-and-escalation-redacted.txt",
      "rollback-tag.txt",
      "database-restore-plan.txt",
      "runbook-review.txt",
      "post-deploy-watch.txt",
      "sample-alert-test-redacted.txt",
      "PENDING_OWNER_SIGNOFF",
      "Do not store private phone numbers",
      "Never delete order, FET ledger, payment, pool settlement, or audit history",
    ],
  ],
  [
    "docs/operations/incident-runbooks.md",
    [
      "owners-and-escalation-redacted.txt",
      "rollback-tag.txt",
      "database-restore-plan.txt",
      "runbook-review.txt",
      "post-deploy-watch.txt",
      "sample-alert-test-redacted.txt",
      "approved_for_launch",
    ],
  ],
  [
    "docs/release/rollback.md",
    [
      "Never delete wallet ledger, audit, order, or settlement history",
      "Prefer forward fixes",
      "Emergency Feature Disables",
      "Post-Rollback",
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

function requireFile(errors, ref) {
  if (!fs.existsSync(repoPath(ref))) errors.push(`${ref} must exist.`);
}

function requireFragments(errors, ref, fragments) {
  requireFile(errors, ref);
  if (!fs.existsSync(repoPath(ref))) return;
  const text = fs.readFileSync(repoPath(ref), "utf8");
  for (const fragment of fragments) {
    if (!text.includes(fragment)) errors.push(`${ref} must include ${fragment}.`);
  }
}

function assertNoPrivateData(errors, ref) {
  const filePath = repoPath(ref);
  if (!fs.existsSync(filePath)) return;
  const text = fs.readFileSync(filePath, "utf8");
  if (credentialPattern.test(text)) {
    errors.push(`${ref} must not contain live credential-looking values.`);
  }
  if (privateEmailPattern.test(text)) {
    errors.push(`${ref} must not contain private email addresses.`);
  }
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw) || privateEmailPattern.test(raw)) {
  console.error(`Incident rollback code evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain private contact or credential-like data.");
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
if (!String(data.scope || "").includes("incident response and rollback")) {
  errors.push("scope must describe incident response and rollback readiness.");
}
if (data.status !== "PASS_WITH_PENDING_OWNER_SIGNOFF") {
  errors.push("status must be PASS_WITH_PENDING_OWNER_SIGNOFF.");
}
if (!hasText(data.bundleRoot)) errors.push("bundleRoot is required.");

const bundleRoot = data.bundleRoot || "";
for (const file of requiredBundleFiles) {
  requireFile(errors, path.join(bundleRoot, file));
  assertNoPrivateData(errors, path.join(bundleRoot, file));
}

const manifestPath = repoPath(path.join(bundleRoot, "manifest.json"));
if (fs.existsSync(manifestPath)) {
  const manifest = readJson(manifestPath);
  if (manifest.schemaVersion !== 1) errors.push("manifest.schemaVersion must be 1.");
  if (manifest.sourceCommit !== data.sourceCommit) {
    errors.push("manifest.sourceCommit must match evidence sourceCommit.");
  }
  if (manifest.status !== "CODE_OWNED_TEMPLATE_READY_PENDING_OWNER_SIGNOFF") {
    errors.push("manifest.status must be CODE_OWNED_TEMPLATE_READY_PENDING_OWNER_SIGNOFF.");
  }
  for (const file of requiredBundleFiles.filter((item) => item !== "manifest.json")) {
    if (!Array.isArray(manifest.requiredFiles) || !manifest.requiredFiles.includes(file)) {
      errors.push(`manifest.requiredFiles must include ${file}.`);
    }
  }
}

const controls = Array.isArray(data.controls) ? data.controls : [];
for (const controlName of requiredControls) {
  const control = controls.find((item) => item?.name === controlName);
  if (!control) {
    errors.push(`Missing control: ${controlName}.`);
    continue;
  }
  if (control.status !== "PASS") errors.push(`${controlName} must be PASS.`);
  if (!hasText(control.proof)) errors.push(`${controlName} must include proof.`);
}

const refs = Array.isArray(data.evidenceRefs) ? data.evidenceRefs : [];
for (const ref of requiredRefs) {
  if (!refs.includes(ref)) errors.push(`evidenceRefs must include ${ref}.`);
  requireFragments(errors, ref, requiredFragments.get(ref) || []);
}
for (const file of requiredBundleFiles) {
  const ref = path.join(bundleRoot, file);
  if (!refs.includes(ref)) errors.push(`evidenceRefs must include ${ref}.`);
}

const commands = Array.isArray(data.commands) ? data.commands : [];
for (const command of [
  "node tool/generate_incident_readiness_bundle.mjs",
  "node tool/validate_incident_rollback_code_evidence.mjs",
]) {
  const item = commands.find((entry) => entry?.command === command);
  if (item?.status !== "PASS") {
    errors.push(`${command} must be recorded with PASS status.`);
  }
}

const pending = Array.isArray(data.pendingExternalEvidence)
  ? data.pendingExternalEvidence
  : [];
for (const required of [
  "Named incident commander",
  "Private escalation channel",
  "Immutable release tag",
  "Production backup manifest",
  "Provider alert-route sample test",
  "Final operations readiness approval",
]) {
  if (!pending.some((item) => String(item).includes(required))) {
    errors.push(`pendingExternalEvidence must include ${required}.`);
  }
}

if (errors.length > 0) {
  console.error(`Incident rollback code evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Incident rollback code evidence validation passed for ${targetPath}.`);
