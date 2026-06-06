#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const targetPath =
  process.argv[2] ||
  "release/operations/observability-telemetry-code-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredControls = [
  "Runtime crash telemetry remains available before sign-in",
  "Product analytics is authenticated-only",
  "Client roles cannot write observability tables directly",
  "Telemetry payloads are bounded and redacted",
  "Telemetry metadata and analytics properties are redacted",
  "Runtime telemetry stores event type and metadata",
];

const requiredRefs = [
  "supabase/migrations/20260606152000_observability_telemetry_hardening.sql",
  "supabase/migrations/20260606154500_observability_metadata_redaction.sql",
  "supabase/tests/observability_telemetry_hardening.sql",
  "supabase/tests/rls_hardening_audit.sql",
  "tool/supabase_observability_telemetry_hardening.sh",
  "output/release-evidence/observability-telemetry-hardening/20260606T060909Z.log",
  "lib/services/app_telemetry.dart",
  "lib/services/product_analytics_service.dart",
  "lib/core/errors/app_error_boundary.dart",
  "lib/main.dart",
];

const requiredFileFragments = new Map([
  [
    "supabase/migrations/20260606152000_observability_telemetry_hardening.sql",
    [
      "ADD COLUMN IF NOT EXISTS event_type",
      "ADD COLUMN IF NOT EXISTS metadata",
      "CREATE OR REPLACE FUNCTION public.observability_redact_text",
      "CREATE OR REPLACE FUNCTION public.observability_safe_timestamptz",
      "jsonb_array_length(p_errors) > 20",
      "jsonb_array_length(p_events) > 50",
      "Authentication is required for product analytics",
      "REVOKE ALL ON TABLE public.app_runtime_errors FROM anon, authenticated",
      "REVOKE ALL ON TABLE public.product_events FROM anon, authenticated",
      "GRANT EXECUTE ON FUNCTION public.log_app_runtime_errors_batch(jsonb)",
      "TO anon, authenticated, service_role",
      "GRANT EXECUTE ON FUNCTION public.log_product_events_batch(jsonb)",
      "TO authenticated, service_role",
    ],
  ],
  [
    "supabase/migrations/20260606154500_observability_metadata_redaction.sql",
    [
      "CREATE OR REPLACE FUNCTION public.observability_redact_jsonb",
      "public.observability_redact_jsonb(v_error->'metadata')",
      "public.observability_redact_jsonb(p_properties)",
      "public.observability_redact_jsonb(v_event->'properties')",
      "REVOKE ALL ON FUNCTION public.observability_redact_jsonb(jsonb, integer)",
      "TO service_role",
      "Redacts token-like keys and values in telemetry metadata before storage",
    ],
  ],
  [
    "supabase/tests/observability_telemetry_hardening.sql",
    [
      "observability_telemetry_hardening_passed",
      "Client roles must not write observability tables directly",
      "Anonymous users must not execute product analytics RPCs",
      "Runtime telemetry RPC must remain executable by anon and authenticated roles",
      "Runtime telemetry RPC must redact, bound, and persist event metadata",
      "Observability JSONB redaction must remove token-like metadata",
      "observability_redact_jsonb",
    ],
  ],
  [
    "supabase/tests/rls_hardening_audit.sql",
    [
      "app_runtime_errors",
      "product_events",
      "Anonymous role has write access to sensitive tables",
      "Authenticated role has direct write access to managed tables",
    ],
  ],
  [
    "tool/supabase_observability_telemetry_hardening.sh",
    [
      "supabase/tests/observability_telemetry_hardening.sql",
      "SUPABASE_OBSERVABILITY_DB_URL",
      "supabase db query --linked",
      "psql",
      "output/release-evidence/observability-telemetry-hardening",
    ],
  ],
  [
    "output/release-evidence/observability-telemetry-hardening/20260606T060909Z.log",
    [
      "observability_telemetry_hardening_passed",
      "FANZONE observability telemetry hardening",
      "supabase/tests/observability_telemetry_hardening.sql",
    ],
  ],
  [
    "lib/services/app_telemetry.dart",
    [
      "log_app_runtime_errors_batch",
      "_maxQueueLength = 100",
      "StructuredCacheStore.writeList",
      "AppConfig.appVersion",
    ],
  ],
  [
    "lib/services/product_analytics_service.dart",
    [
      "log_product_events_batch",
      "_maxBatchSize = 10",
      "_maxQueueLength = 100",
      "_connection.currentUser == null",
      "ProductAnalytics.trackScreen",
    ],
  ],
  [
    "lib/core/errors/app_error_boundary.dart",
    [
      "FlutterError.onError",
      "AppTelemetry.captureException",
      "ErrorWidget.builder",
      "Retry screen",
    ],
  ],
  [
    "lib/main.dart",
    [
      "PlatformDispatcher.instance.onError",
      "AppTelemetry.captureException",
      "AppTelemetry.start()",
      "AppTelemetry.flush()",
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
    `Observability telemetry code evidence validation failed for ${targetPath}:`,
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
if (!String(data.scope || "").includes("runtime observability")) {
  errors.push("scope must describe runtime observability.");
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
const validatorCommand = commands.find(
  (item) => item?.command === "node tool/validate_observability_telemetry_code_evidence.mjs",
);
if (validatorCommand?.status !== "PASS") {
  errors.push("validator command must be recorded with PASS status.");
}

const shellSyntaxCommand = commands.find(
  (item) => item?.command === "bash -n tool/supabase_observability_telemetry_hardening.sh",
);
if (shellSyntaxCommand?.status !== "PASS") {
  errors.push("shell syntax command must be recorded with PASS status.");
}

const linkedSqlCommand = commands.find(
  (item) => item?.command === "tool/supabase_observability_telemetry_hardening.sh",
);
if (linkedSqlCommand?.status !== "PASS") {
  errors.push("linked SQL hardening command must be recorded with PASS status.");
}
if (
  !String(linkedSqlCommand?.proof || "").includes(
    "output/release-evidence/observability-telemetry-hardening/20260606T060909Z.log",
  )
) {
  errors.push("linked SQL hardening proof must include the latest log path.");
}

const pending = Array.isArray(data.pendingExternalEvidence)
  ? data.pendingExternalEvidence
  : [];
for (const required of [
  "Capture production dashboard/alert-route evidence",
  "Capture operations owner, incident commander, and release owner signoff",
]) {
  if (!pending.some((item) => String(item).includes(required))) {
    errors.push(`pendingExternalEvidence must include ${required}.`);
  }
}

if (errors.length > 0) {
  console.error(
    `Observability telemetry code evidence validation failed for ${targetPath}:`,
  );
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(
  `Observability telemetry code evidence validation passed for ${targetPath}.`,
);
