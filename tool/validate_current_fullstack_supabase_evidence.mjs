#!/usr/bin/env node

import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const targetPath =
  process.argv[2] || "release/qa/current-fullstack-supabase-evidence.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const requiredCoveredFunctions = [
  "fan-trivia",
  "song-guess",
  "music-bingo",
  "sync-livescore-football",
  "whatsapp-otp",
  "order_create",
  "order_mark_paid",
  "order_update_status",
  "payment-hub",
  "menu_ocr_parse",
  "settle-match-pools",
  "dispatch-match-alerts",
  "push-notify",
  "generate-pool-social-card",
  "ring_bell",
];

const requiredTeamCatalogGroups = [
  "localClubs",
  "topEuropeanClubs",
  "worldCupNationalTeams",
];

const requiredExternalGateFragments = [
  "Secret rotation",
  "Operations scheduler",
  "Human legal review",
  "iOS archive",
  "Google Play",
];

const requiredPostMergeMigrations = [
  "20260604120000",
  "20260604123000",
  "20260606110000",
  "20260606113000",
  "20260606124500",
  "20260606125000",
  "20260606130500",
  "20260606133500",
  "20260606134000",
  "20260606140500",
  "20260606141000",
  "20260606152000",
  "20260606154500",
  "20260606161000",
  "20260606170000",
  "20260606173000",
  "20260606174000",
];

const requiredPostMergeFunctions = [
  ...requiredCoveredFunctions,
  "admin_user_management",
];

const requiredPostMergeBlockers = [
  "android-device-uat",
  "github-actions",
  "authenticated-live-probes",
];

const requiredUserVisibleFlowEvidence = new Map([
  [
    "whatsappOtp",
    {
      command: "node tool/validate_whatsapp_otp_evidence.mjs",
      evidence: "release/qa/whatsapp-otp-smoke-evidence.json",
    },
  ],
  [
    "settingsSupportNavigation",
    {
      command: "node tool/validate_settings_support_navigation_evidence.mjs",
      evidence: "release/qa/settings-support-navigation-evidence.json",
    },
  ],
  [
    "onboardingFanProfile",
    {
      command: "node tool/validate_onboarding_fan_profile_evidence.mjs",
      evidence: "release/qa/onboarding-fan-profile-evidence.json",
    },
  ],
  [
    "privacyLegalCode",
    {
      command: "node tool/validate_privacy_legal_code_evidence.mjs",
      evidence: "release/qa/privacy-legal-code-evidence.json",
    },
  ],
  [
    "androidDeviceUat",
    {
      command: "node tool/validate_android_device_uat_evidence.mjs",
      evidence: "release/qa/android-device-uat-current.json",
    },
  ],
  [
    "mobileSecurityCode",
    {
      command: "node tool/validate_mobile_security_code_evidence.mjs",
      evidence: "release/qa/mobile-security-code-evidence.json",
    },
  ],
  [
    "mobileBackendUat",
    {
      command: "node tool/validate_mobile_backend_uat_evidence.mjs",
      evidence: "release/qa/current-fullstack-supabase-evidence.json",
    },
  ],
  [
    "cronSmoke",
    {
      command: "node tool/validate_cron_smoke_evidence.mjs",
      evidence: "release/operations/cron-smoke-evidence-20260606T043304Z.json",
    },
  ],
  [
    "schedulerWorkflowCode",
    {
      command: "node tool/validate_scheduler_workflow_code_evidence.mjs",
      evidence: "release/operations/scheduler-workflow-code-evidence.json",
    },
  ],
  [
    "schedulerPostDeployAuditSmoke",
    {
      command: "node tool/validate_scheduler_post_deploy_audit_smoke.mjs",
      evidence:
        "release/operations/scheduler-post-deploy-audit-smoke-evidence.json",
    },
  ],
  [
    "observabilityTelemetryCode",
    {
      command: "node tool/validate_observability_telemetry_code_evidence.mjs",
      evidence: "release/operations/observability-telemetry-code-evidence.json",
    },
  ],
  [
    "operationsObservabilitySnapshot",
    {
      command: "node tool/validate_operations_observability_snapshot_evidence.mjs",
      evidence: "release/operations/operations-observability-snapshot-evidence.json",
    },
  ],
  [
    "incidentRollbackCode",
    {
      command: "node tool/validate_incident_rollback_code_evidence.mjs",
      evidence: "release/operations/incident-rollback-code-evidence.json",
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

function repoRefExists(ref) {
  if (!hasText(ref)) return false;
  if (/^https?:\/\//.test(ref)) return true;
  return fs.existsSync(path.resolve(process.cwd(), ref));
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
}

function sha256(filePath) {
  return crypto
    .createHash("sha256")
    .update(fs.readFileSync(filePath))
    .digest("hex");
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
  if (!/^[a-f0-9]{40}$/.test(commit)) return false;
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

function requireStatus(errors, label, node, expected = "PASS") {
  if (node?.status !== expected) {
    errors.push(`${label}.status must be ${expected}.`);
  }
}

function requireCommand(errors, label, node, expected) {
  if (node?.command !== expected) {
    errors.push(`${label}.command must be ${expected}.`);
  }
}

function requireRefs(errors, label, refs) {
  if (!Array.isArray(refs) || refs.length === 0) {
    errors.push(`${label} must include evidence file refs.`);
    return;
  }
  for (const ref of refs) {
    if (!repoRefExists(ref)) errors.push(`${label} contains missing repo ref: ${ref}`);
  }
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Current fullstack evidence validation failed for ${targetPath}:`);
  console.error("- evidence file appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];
const headCommit = currentGitHead();

if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (data.projectRef !== "kjuhheobmdvjwgnzlcwx") {
  errors.push("projectRef must match the linked production Supabase project.");
}
if (!hasText(data.scope)) errors.push("scope is required.");

const edge = data.edgeFunctions || {};
requireStatus(errors, "edgeFunctions.format", edge.format);
requireCommand(
  errors,
  "edgeFunctions.format",
  edge.format,
  "deno fmt --check supabase/functions",
);
if (!Number.isInteger(edge.format?.filesChecked) || edge.format.filesChecked <= 0) {
  errors.push("edgeFunctions.format.filesChecked must be a positive integer.");
}

requireStatus(errors, "edgeFunctions.typecheck", edge.typecheck);
requireCommand(
  errors,
  "edgeFunctions.typecheck",
  edge.typecheck,
  "find supabase/functions -name '*.ts' -print0 | xargs -0 deno check",
);
if (!Number.isInteger(edge.typecheck?.filesChecked) ||
  edge.typecheck.filesChecked <= 0) {
  errors.push("edgeFunctions.typecheck.filesChecked must be a positive integer.");
}

requireStatus(errors, "edgeFunctions.tests", edge.tests);
requireCommand(
  errors,
  "edgeFunctions.tests",
  edge.tests,
  "deno test --allow-env supabase/functions",
);
if (!Number.isInteger(edge.tests?.testsPassed) || edge.tests.testsPassed <= 0) {
  errors.push("edgeFunctions.tests.testsPassed must be a positive integer.");
}
if (edge.tests?.testsFailed !== 0) {
  errors.push("edgeFunctions.tests.testsFailed must be 0.");
}

for (const key of [
  "gameEdgeDeploymentSmoke",
  "releaseContract",
  "appEdgeDeploymentSmoke",
  "whatsappAuthSmoke",
]) {
  requireStatus(errors, `edgeFunctions.${key}`, edge[key]);
  requireRefs(errors, `edgeFunctions.${key}.files`, edge[key]?.files);
}

requireStatus(errors, "edgeFunctions.edgeCorsSmoke", edge.edgeCorsSmoke);
requireCommand(
  errors,
  "edgeFunctions.edgeCorsSmoke",
  edge.edgeCorsSmoke,
  "node tool/validate_edge_cors_smoke_evidence.mjs",
);
if (edge.edgeCorsSmoke?.evidence !== "release/qa/edge-cors-smoke-evidence.json") {
  errors.push(
    "edgeFunctions.edgeCorsSmoke.evidence must be release/qa/edge-cors-smoke-evidence.json.",
  );
}
if (!repoRefExists(edge.edgeCorsSmoke?.evidence)) {
  errors.push(
    `edgeFunctions.edgeCorsSmoke.evidence does not exist: ${edge.edgeCorsSmoke?.evidence}`,
  );
}
if (
  !Array.isArray(edge.edgeCorsSmoke?.allowedOrigins) ||
  edge.edgeCorsSmoke.allowedOrigins.length !== 4
) {
  errors.push("edgeFunctions.edgeCorsSmoke.allowedOrigins must list four production origins.");
}
if (
  !String(edge.edgeCorsSmoke?.proof || "").includes(
    "exact-origin CORS",
  )
) {
  errors.push("edgeFunctions.edgeCorsSmoke.proof must mention exact-origin CORS.");
}

requireStatus(
  errors,
  "edgeFunctions.adminAuthDeploySmoke",
  edge.adminAuthDeploySmoke,
);
requireCommand(
  errors,
  "edgeFunctions.adminAuthDeploySmoke",
  edge.adminAuthDeploySmoke,
  "node tool/validate_admin_auth_deploy_smoke_evidence.mjs",
);
if (
  edge.adminAuthDeploySmoke?.evidence !==
    "release/qa/admin-auth-deploy-smoke-evidence.json"
) {
  errors.push(
    "edgeFunctions.adminAuthDeploySmoke.evidence must be release/qa/admin-auth-deploy-smoke-evidence.json.",
  );
}
if (!repoRefExists(edge.adminAuthDeploySmoke?.evidence)) {
  errors.push(
    `edgeFunctions.adminAuthDeploySmoke.evidence does not exist: ${edge.adminAuthDeploySmoke?.evidence}`,
  );
}
if (!Number.isInteger(edge.adminAuthDeploySmoke?.deployedVersion) ||
  edge.adminAuthDeploySmoke.deployedVersion < 15) {
  errors.push("edgeFunctions.adminAuthDeploySmoke.deployedVersion must be at least 15.");
}
if (
  !String(edge.adminAuthDeploySmoke?.proof || "").includes(
    "unauthenticated POST",
  )
) {
  errors.push(
    "edgeFunctions.adminAuthDeploySmoke.proof must mention unauthenticated POST.",
  );
}

const coveredFunctions = new Set(edge.releaseContract?.coveredFunctions || []);
for (const functionName of requiredCoveredFunctions) {
  if (!coveredFunctions.has(functionName)) {
    errors.push(`edgeFunctions.releaseContract.coveredFunctions missing ${functionName}.`);
  }
}

requireStatus(
  errors,
  "edgeFunctions.aggregateEvidenceCollection",
  edge.aggregateEvidenceCollection,
  "PASS_WITH_PENDING_EXTERNAL_GATES",
);
if (!repoRefExists(edge.aggregateEvidenceCollection?.summary)) {
  errors.push(
    `edgeFunctions.aggregateEvidenceCollection.summary does not exist: ${edge.aggregateEvidenceCollection?.summary}`,
  );
}
if (!Array.isArray(edge.aggregateEvidenceCollection?.deployedFunctionsRefreshed) ||
  edge.aggregateEvidenceCollection.deployedFunctionsRefreshed.length < 5) {
  errors.push(
    "edgeFunctions.aggregateEvidenceCollection.deployedFunctionsRefreshed must list refreshed deployed functions.",
  );
}

const linked = data.linkedSupabase || {};
for (const key of ["rlsAudit", "fetSupplySmoke", "liveValidation", "teamCatalogSmoke"]) {
  requireStatus(errors, `linkedSupabase.${key}`, linked[key]);
}
requireStatus(errors, "linkedSupabase.apiAuthorizationAbuse", linked.apiAuthorizationAbuse);
requireCommand(
  errors,
  "linkedSupabase.apiAuthorizationAbuse",
  linked.apiAuthorizationAbuse,
  "node tool/validate_api_authorization_abuse_evidence.mjs",
);
if (linked.apiAuthorizationAbuse?.evidence !== "release/qa/api-authorization-abuse-evidence.json") {
  errors.push(
    "linkedSupabase.apiAuthorizationAbuse.evidence must be release/qa/api-authorization-abuse-evidence.json.",
  );
}
if (!repoRefExists(linked.apiAuthorizationAbuse?.evidence)) {
  errors.push(
    `linkedSupabase.apiAuthorizationAbuse.evidence does not exist: ${linked.apiAuthorizationAbuse?.evidence}`,
  );
}
requireStatus(
  errors,
  "linkedSupabase.observabilityTelemetryCode",
  linked.observabilityTelemetryCode,
);
requireCommand(
  errors,
  "linkedSupabase.observabilityTelemetryCode",
  linked.observabilityTelemetryCode,
  "node tool/validate_observability_telemetry_code_evidence.mjs",
);
if (
  linked.observabilityTelemetryCode?.evidence !==
    "release/operations/observability-telemetry-code-evidence.json"
) {
  errors.push(
    "linkedSupabase.observabilityTelemetryCode.evidence must be release/operations/observability-telemetry-code-evidence.json.",
  );
}
if (!repoRefExists(linked.observabilityTelemetryCode?.evidence)) {
  errors.push(
    `linkedSupabase.observabilityTelemetryCode.evidence does not exist: ${linked.observabilityTelemetryCode?.evidence}`,
  );
}
if (
  !String(linked.observabilityTelemetryCode?.notes || "").includes(
    "bounded/redacted Supabase RPC writes",
  )
) {
  errors.push(
    "linkedSupabase.observabilityTelemetryCode.notes must mention bounded/redacted Supabase RPC writes.",
  );
}
requireStatus(
  errors,
  "linkedSupabase.operationsObservabilitySnapshot",
  linked.operationsObservabilitySnapshot,
);
requireCommand(
  errors,
  "linkedSupabase.operationsObservabilitySnapshot",
  linked.operationsObservabilitySnapshot,
  "node tool/validate_operations_observability_snapshot_evidence.mjs",
);
if (
  linked.operationsObservabilitySnapshot?.evidence !==
    "release/operations/operations-observability-snapshot-evidence.json"
) {
  errors.push(
    "linkedSupabase.operationsObservabilitySnapshot.evidence must be release/operations/operations-observability-snapshot-evidence.json.",
  );
}
if (!repoRefExists(linked.operationsObservabilitySnapshot?.evidence)) {
  errors.push(
    `linkedSupabase.operationsObservabilitySnapshot.evidence does not exist: ${linked.operationsObservabilitySnapshot?.evidence}`,
  );
}
if (
  !String(linked.operationsObservabilitySnapshot?.notes || "").includes(
    "Admin-only Supabase operations snapshot",
  )
) {
  errors.push(
    "linkedSupabase.operationsObservabilitySnapshot.notes must mention Admin-only Supabase operations snapshot.",
  );
}
requireStatus(
  errors,
  "linkedSupabase.incidentRollbackCode",
  linked.incidentRollbackCode,
);
requireCommand(
  errors,
  "linkedSupabase.incidentRollbackCode",
  linked.incidentRollbackCode,
  "node tool/validate_incident_rollback_code_evidence.mjs",
);
if (
  linked.incidentRollbackCode?.evidence !==
    "release/operations/incident-rollback-code-evidence.json"
) {
  errors.push(
    "linkedSupabase.incidentRollbackCode.evidence must be release/operations/incident-rollback-code-evidence.json.",
  );
}
if (!repoRefExists(linked.incidentRollbackCode?.evidence)) {
  errors.push(
    `linkedSupabase.incidentRollbackCode.evidence does not exist: ${linked.incidentRollbackCode?.evidence}`,
  );
}
if (
  !String(linked.incidentRollbackCode?.notes || "").includes(
    "Code-owned incident and rollback bundle",
  )
) {
  errors.push(
    "linkedSupabase.incidentRollbackCode.notes must mention Code-owned incident and rollback bundle.",
  );
}
requireStatus(
  errors,
  "linkedSupabase.schedulerWorkflowCode",
  linked.schedulerWorkflowCode,
);
requireCommand(
  errors,
  "linkedSupabase.schedulerWorkflowCode",
  linked.schedulerWorkflowCode,
  "node tool/validate_scheduler_workflow_code_evidence.mjs",
);
if (
  linked.schedulerWorkflowCode?.evidence !==
    "release/operations/scheduler-workflow-code-evidence.json"
) {
  errors.push(
    "linkedSupabase.schedulerWorkflowCode.evidence must be release/operations/scheduler-workflow-code-evidence.json.",
  );
}
if (!repoRefExists(linked.schedulerWorkflowCode?.evidence)) {
  errors.push(
    `linkedSupabase.schedulerWorkflowCode.evidence does not exist: ${linked.schedulerWorkflowCode?.evidence}`,
  );
}
if (
  !String(linked.schedulerWorkflowCode?.notes || "").includes(
    "workflow controls",
  )
) {
  errors.push(
    "linkedSupabase.schedulerWorkflowCode.notes must mention workflow controls.",
  );
}
requireStatus(
  errors,
  "linkedSupabase.schedulerPostDeployAuditSmoke",
  linked.schedulerPostDeployAuditSmoke,
);
requireCommand(
  errors,
  "linkedSupabase.schedulerPostDeployAuditSmoke",
  linked.schedulerPostDeployAuditSmoke,
  "node tool/validate_scheduler_post_deploy_audit_smoke.mjs",
);
if (
  linked.schedulerPostDeployAuditSmoke?.evidence !==
    "release/operations/scheduler-post-deploy-audit-smoke-evidence.json"
) {
  errors.push(
    "linkedSupabase.schedulerPostDeployAuditSmoke.evidence must be release/operations/scheduler-post-deploy-audit-smoke-evidence.json.",
  );
}
if (!repoRefExists(linked.schedulerPostDeployAuditSmoke?.evidence)) {
  errors.push(
    `linkedSupabase.schedulerPostDeployAuditSmoke.evidence does not exist: ${linked.schedulerPostDeployAuditSmoke?.evidence}`,
  );
}
if (
  !String(linked.schedulerPostDeployAuditSmoke?.notes || "").includes(
    "audit run ids",
  )
) {
  errors.push(
    "linkedSupabase.schedulerPostDeployAuditSmoke.notes must mention audit run ids.",
  );
}
requireStatus(
  errors,
  "linkedSupabase.publicUrlSafety",
  linked.publicUrlSafety,
);
requireCommand(
  errors,
  "linkedSupabase.publicUrlSafety",
  linked.publicUrlSafety,
  "./tool/supabase_public_url_safety_contract.sh",
);
if (!repoRefExists(linked.publicUrlSafety?.latestLog)) {
  errors.push(
    `linkedSupabase.publicUrlSafety.latestLog does not exist: ${linked.publicUrlSafety?.latestLog}`,
  );
}
requireRefs(errors, "linkedSupabase.publicUrlSafety.files", linked.publicUrlSafety?.files);
if (
  !String(linked.publicUrlSafety?.notes || "").includes(
    "unsafe public URLs",
  )
) {
  errors.push(
    "linkedSupabase.publicUrlSafety.notes must mention unsafe public URLs.",
  );
}
if (linked.fetSupplySmoke?.latestObservedSupplyCap !== 100000000) {
  errors.push("linkedSupabase.fetSupplySmoke.latestObservedSupplyCap must be 100000000.");
}
for (const key of requiredTeamCatalogGroups) {
  if (!Number.isInteger(linked.teamCatalogSmoke?.observed?.[key]) ||
    linked.teamCatalogSmoke.observed[key] <= 0) {
    errors.push(`linkedSupabase.teamCatalogSmoke.observed.${key} must be positive.`);
  }
}
requireRefs(errors, "linkedSupabase.teamCatalogSmoke.files", linked.teamCatalogSmoke?.files);

const postMerge = data.postMergeValidation || {};
requireStatus(
  errors,
  "postMergeValidation",
  postMerge,
  "PASS_WITH_EXTERNAL_BLOCKERS",
);
if (!isIsoDateTime(postMerge.generatedAtUtc)) {
  errors.push("postMergeValidation.generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (postMerge.projectRef !== data.projectRef) {
  errors.push("postMergeValidation.projectRef must match projectRef.");
}
if (!/^[a-f0-9]{40}$/.test(String(postMerge.mergedMainCommit || ""))) {
  errors.push("postMergeValidation.mergedMainCommit must be a 40-character git SHA.");
}
if (
  headCommit &&
  postMerge.mergedMainCommit !== headCommit &&
  !isAncestorCommit(postMerge.mergedMainCommit)
) {
  errors.push(
    "postMergeValidation.mergedMainCommit must match or be an ancestor of the current git HEAD.",
  );
}
requireStatus(errors, "postMergeValidation.supabaseLinkedProject", postMerge.supabaseLinkedProject);
if (postMerge.supabaseLinkedProject?.projectRef !== data.projectRef) {
  errors.push("postMergeValidation.supabaseLinkedProject.projectRef must match projectRef.");
}
requireStatus(errors, "postMergeValidation.migrationsApplied", postMerge.migrationsApplied);
const appliedMigrationSet = new Set(postMerge.migrationsApplied?.requiredVersions || []);
for (const migration of requiredPostMergeMigrations) {
  if (!appliedMigrationSet.has(migration)) {
    errors.push(`postMergeValidation.migrationsApplied.requiredVersions missing ${migration}.`);
  }
}
requireStatus(errors, "postMergeValidation.deployedFunctions", postMerge.deployedFunctions);
const activeFunctionSet = new Set(postMerge.deployedFunctions?.activeFunctions || []);
for (const functionName of requiredPostMergeFunctions) {
  if (!activeFunctionSet.has(functionName)) {
    errors.push(`postMergeValidation.deployedFunctions.activeFunctions missing ${functionName}.`);
  }
}
requireStatus(errors, "postMergeValidation.liveAnonymousEdgeSmokes", postMerge.liveAnonymousEdgeSmokes);
for (const command of [
  "SUPABASE_URL=https://kjuhheobmdvjwgnzlcwx.supabase.co tool/supabase_app_edge_smoke.sh",
  "SUPABASE_URL=https://kjuhheobmdvjwgnzlcwx.supabase.co tool/supabase_game_edge_smoke.sh",
]) {
  if (!Array.isArray(postMerge.liveAnonymousEdgeSmokes?.commands) ||
    !postMerge.liveAnonymousEdgeSmokes.commands.includes(command)) {
    errors.push(`postMergeValidation.liveAnonymousEdgeSmokes.commands missing ${command}.`);
  }
}
if (
  !String(postMerge.liveAnonymousEdgeSmokes?.proof || "").includes(
    "reject anonymous calls",
  )
) {
  errors.push("postMergeValidation.liveAnonymousEdgeSmokes.proof must mention anonymous rejection.");
}
requireStatus(errors, "postMergeValidation.reviewWeb", postMerge.reviewWeb);
if (postMerge.reviewWeb?.route !== "/home") {
  errors.push("postMergeValidation.reviewWeb.route must be /home.");
}
const bottomNavigation = postMerge.reviewWeb?.bottomNavigation || [];
if (JSON.stringify(bottomNavigation) !== JSON.stringify(["Home", "Play", "Settings"])) {
  errors.push("postMergeValidation.reviewWeb.bottomNavigation must be exactly Home, Play, Settings.");
}
for (const section of ["Bars", "Live & Upcoming Matches"]) {
  if (!Array.isArray(postMerge.reviewWeb?.observedHomeSections) ||
    !postMerge.reviewWeb.observedHomeSections.includes(section)) {
    errors.push(`postMergeValidation.reviewWeb.observedHomeSections missing ${section}.`);
  }
}
if (!/^[a-f0-9]{64}$/.test(String(postMerge.reviewWeb?.webMainDartJsSha256 || ""))) {
  errors.push("postMergeValidation.reviewWeb.webMainDartJsSha256 must be a SHA-256 hash.");
}
if (!Number.isInteger(postMerge.reviewWeb?.webMainDartJsSizeBytes) ||
  postMerge.reviewWeb.webMainDartJsSizeBytes <= 0) {
  errors.push("postMergeValidation.reviewWeb.webMainDartJsSizeBytes must be positive.");
}
requireStatus(errors, "postMergeValidation.androidReleaseArtifact", postMerge.androidReleaseArtifact);
if (postMerge.androidReleaseArtifact?.buildCommand !== "flutter build apk --release") {
  errors.push("postMergeValidation.androidReleaseArtifact.buildCommand must be flutter build apk --release.");
}
if (!/^[a-f0-9]{64}$/.test(String(postMerge.androidReleaseArtifact?.sha256 || ""))) {
  errors.push("postMergeValidation.androidReleaseArtifact.sha256 must be a SHA-256 hash.");
}
if (!Number.isInteger(postMerge.androidReleaseArtifact?.sizeBytes) ||
  postMerge.androidReleaseArtifact.sizeBytes <= 0) {
  errors.push("postMergeValidation.androidReleaseArtifact.sizeBytes must be positive.");
}
requireStatus(errors, "postMergeValidation.postMergeFlutterChecks", postMerge.postMergeFlutterChecks);
for (const command of [
  "flutter analyze",
  "flutter test test/app_router_test.dart test/screen_widgets_test.dart test/features/games/games_repository_test.dart test/features/onboarding/fan_profile_selector_test.dart",
]) {
  if (!Array.isArray(postMerge.postMergeFlutterChecks?.commands) ||
    !postMerge.postMergeFlutterChecks.commands.includes(command)) {
    errors.push(`postMergeValidation.postMergeFlutterChecks.commands missing ${command}.`);
  }
}
const blockerMap = new Map(
  (postMerge.externalBlockers || []).map((blocker) => [blocker?.id, blocker]),
);
for (const blockerId of requiredPostMergeBlockers) {
  const blocker = blockerMap.get(blockerId);
  if (!blocker) {
    errors.push(`postMergeValidation.externalBlockers missing ${blockerId}.`);
    continue;
  }
  if (blocker.status !== "BLOCKED_EXTERNAL") {
    errors.push(`postMergeValidation.externalBlockers.${blockerId}.status must be BLOCKED_EXTERNAL.`);
  }
  if (!hasText(blocker.proof)) {
    errors.push(`postMergeValidation.externalBlockers.${blockerId}.proof is required.`);
  }
}

const localGoLive = data.localGoLiveReadiness || {};
requireStatus(
  errors,
  "localGoLiveReadiness",
  localGoLive,
  "PASS_WITH_EXTERNAL_PROVIDER_TASKS",
);
if (localGoLive.command !== "./tool/go_live_readiness.sh --local") {
  errors.push(
    "localGoLiveReadiness.command must be ./tool/go_live_readiness.sh --local.",
  );
}
if (
  localGoLive.validator !==
    "node tool/validate_local_go_live_readiness_evidence.mjs"
) {
  errors.push(
    "localGoLiveReadiness.validator must be node tool/validate_local_go_live_readiness_evidence.mjs.",
  );
}
if (
  localGoLive.evidence !==
    "release/qa/local-go-live-readiness-evidence.json"
) {
  errors.push(
    "localGoLiveReadiness.evidence must be release/qa/local-go-live-readiness-evidence.json.",
  );
}
if (!repoRefExists(localGoLive.evidence)) {
  errors.push(
    `localGoLiveReadiness.evidence does not exist: ${localGoLive.evidence}`,
  );
}
if (!/^[a-f0-9]{40}$/.test(String(localGoLive.sourceCommit || ""))) {
  errors.push("localGoLiveReadiness.sourceCommit must be a 40-character git SHA.");
} else if (
  headCommit &&
  localGoLive.sourceCommit !== headCommit &&
  !isAncestorCommit(localGoLive.sourceCommit)
) {
  errors.push(
    "localGoLiveReadiness.sourceCommit must match or be an ancestor of current git HEAD.",
  );
}
if (
  !String(localGoLive.proof || "").includes(
    "Full local go-live readiness gate passed",
  )
) {
  errors.push(
    "localGoLiveReadiness.proof must mention the full local go-live readiness gate pass.",
  );
}

const mobileUat = Array.isArray(data.mobileUatSql) ? data.mobileUatSql : [];
for (const flowId of ["MOB-SETTLEMENT-001", "MOB-WALLET-001"]) {
  const item = mobileUat.find((flow) => flow?.flowId === flowId);
  if (!item) {
    errors.push(`mobileUatSql missing ${flowId}.`);
    continue;
  }
  requireStatus(errors, `mobileUatSql.${flowId}`, item);
  if (!repoRefExists(item.log)) {
    errors.push(`mobileUatSql.${flowId}.log does not exist: ${item.log}`);
  }
}

const liveScore = data.liveScore || {};
requireStatus(errors, "liveScore.unitTest", liveScore.unitTest);
requireStatus(errors, "liveScore.dryExport", liveScore.dryExport);
if (liveScore.dryExport?.resourceId !== "livescore_world_cup_2026") {
  errors.push("liveScore.dryExport.resourceId must be livescore_world_cup_2026.");
}
if (liveScore.dryExport?.providerCompetitionId !== "734") {
  errors.push("liveScore.dryExport.providerCompetitionId must be 734.");
}
if (!Number.isInteger(liveScore.dryExport?.rows) || liveScore.dryExport.rows <= 0) {
  errors.push("liveScore.dryExport.rows must be positive.");
}
requireStatus(errors, "liveScore.edgeScheduler", liveScore.edgeScheduler);
if (!repoRefExists(liveScore.edgeScheduler?.latestCredentialFreeSmoke)) {
  errors.push(
    `liveScore.edgeScheduler.latestCredentialFreeSmoke does not exist: ${liveScore.edgeScheduler?.latestCredentialFreeSmoke}`,
  );
}
if (!repoRefExists(liveScore.edgeScheduler?.latestCredentialedSmoke)) {
  errors.push(
    `liveScore.edgeScheduler.latestCredentialedSmoke does not exist: ${liveScore.edgeScheduler?.latestCredentialedSmoke}`,
  );
}
requireRefs(errors, "liveScore.edgeScheduler.files", liveScore.edgeScheduler?.files);

requireStatus(errors, "releaseBoundary", data.releaseBoundary);
requireCommand(
  errors,
  "releaseBoundary",
  data.releaseBoundary,
  "./tool/product_boundary_scan.sh",
);

const ios = data.iosLocalCompile || {};
requireStatus(errors, "iosLocalCompile", ios);
if (!repoRefExists(ios.log)) {
  errors.push(`iosLocalCompile.log does not exist: ${ios.log}`);
} else if (sha256(path.resolve(process.cwd(), ios.log)) !== ios.logSha256) {
  errors.push("iosLocalCompile.logSha256 does not match iosLocalCompile.log.");
}
if (ios.validator !== "node tool/validate_ios_local_compile_evidence.mjs") {
  errors.push("iosLocalCompile.validator must be node tool/validate_ios_local_compile_evidence.mjs.");
}
if (!repoRefExists(ios.archivePath)) {
  errors.push(`iosLocalCompile.archivePath does not exist: ${ios.archivePath}`);
}
if (!Number.isInteger(ios.archiveSizeKiB) || ios.archiveSizeKiB <= 0) {
  errors.push("iosLocalCompile.archiveSizeKiB must be a positive integer.");
}

const flutter = data.flutterClient || {};
requireStatus(errors, "flutterClient", flutter);
requireCommand(errors, "flutterClient", flutter, "flutter test");
requireStatus(errors, "flutterClient.analysis", flutter.analysis);
requireCommand(
  errors,
  "flutterClient.analysis",
  flutter.analysis,
  "flutter analyze",
);
if (!String(flutter.analysis?.proof || "").includes("no issues")) {
  errors.push("flutterClient.analysis.proof must mention no issues.");
}
requireStatus(errors, "flutterClient.providerWiring", flutter.providerWiring);
requireCommand(
  errors,
  "flutterClient.providerWiring",
  flutter.providerWiring,
  "flutter test test/gateway_providers_test.dart",
);
if (!String(flutter.providerWiring?.proof || "").includes("Onboarding gateway")) {
  errors.push("flutterClient.providerWiring.proof must mention Onboarding gateway.");
}
if (!Number.isInteger(flutter.testsPassed) || flutter.testsPassed <= 0) {
  errors.push("flutterClient.testsPassed must be positive.");
}
if (flutter.testsFailed !== 0) {
  errors.push("flutterClient.testsFailed must be 0.");
}
requireStatus(errors, "flutterClient.coverage", flutter.coverage);
requireCommand(
  errors,
  "flutterClient.coverage",
  flutter.coverage,
  "node tool/validate_flutter_coverage_evidence.mjs",
);
if (flutter.coverage?.evidence !== "release/qa/flutter-coverage-evidence.json") {
  errors.push(
    "flutterClient.coverage.evidence must be release/qa/flutter-coverage-evidence.json.",
  );
}
if (!repoRefExists(flutter.coverage?.evidence)) {
  errors.push(`flutterClient.coverage.evidence does not exist: ${flutter.coverage?.evidence}`);
}
if (!Number.isInteger(flutter.coverage?.testsPassed) || flutter.coverage.testsPassed <= 0) {
  errors.push("flutterClient.coverage.testsPassed must be positive.");
}
if (flutter.coverage?.lineCoveragePercent <= 0) {
  errors.push("flutterClient.coverage.lineCoveragePercent must be positive.");
}
for (const fragment of [
  "Home, Play, Settings",
  "Onboarding phone",
  "Provider wiring",
  "Full Flutter analyzer",
  "Games repository",
  "Ordering lifecycle",
]) {
  if (!Array.isArray(flutter.coveredAreas) ||
    !flutter.coveredAreas.some((area) => String(area).includes(fragment))) {
    errors.push(`flutterClient.coveredAreas must include ${fragment}.`);
  }
}

const userVisibleFlowEvidence = data.userVisibleFlowEvidence || {};
for (const [key, expected] of requiredUserVisibleFlowEvidence) {
  const item = userVisibleFlowEvidence[key];
  requireStatus(errors, `userVisibleFlowEvidence.${key}`, item);
  requireCommand(errors, `userVisibleFlowEvidence.${key}`, item, expected.command);
  if (item?.evidence !== expected.evidence) {
    errors.push(`userVisibleFlowEvidence.${key}.evidence must be ${expected.evidence}.`);
  }
  if (!repoRefExists(item?.evidence)) {
    errors.push(`userVisibleFlowEvidence.${key}.evidence does not exist: ${item?.evidence}`);
  }
}

if (!Array.isArray(data.remainingExternalGates) ||
  data.remainingExternalGates.length === 0) {
  errors.push("remainingExternalGates must list the non-code launch blockers.");
} else {
  for (const fragment of requiredExternalGateFragments) {
    if (!data.remainingExternalGates.some((gate) => String(gate).includes(fragment))) {
      errors.push(`remainingExternalGates must include ${fragment}.`);
    }
  }
}

if (errors.length > 0) {
  console.error(`Current fullstack evidence validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Current fullstack evidence validation passed for ${targetPath}.`);
