#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const projectRef = process.env.SUPABASE_PROJECT_REF || "kjuhheobmdvjwgnzlcwx";
const supabaseUrl = (
  process.env.SUPABASE_URL || `https://${projectRef}.supabase.co`
).replace(/\/+$/, "");
const functionName = "admin_user_management";
const outputPath =
  process.argv[2] || "release/qa/admin-auth-deploy-smoke-evidence.json";
const timestamp = new Date().toISOString();
const stamp = timestamp.replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
const archivePath =
  `output/release-evidence/admin-auth-deploy-smoke/${stamp}.json`;

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function parseFunctionList(output) {
  for (const rawLine of output.split("\n")) {
    if (!rawLine.includes(functionName)) continue;
    const cells = rawLine
      .split("|")
      .map((cell) => cell.trim())
      .filter(Boolean);
    const [id, name, slug, status, version, updatedAt] = cells;
    if (name !== functionName || slug !== functionName) continue;
    return {
      idSha256: sha256(id),
      name,
      slug,
      status,
      version: Number.parseInt(version, 10),
      updatedAtUtc: `${updatedAt.replace(" ", "T")}Z`,
    };
  }
  return null;
}

function selectedHeader(response, name) {
  return response.headers.get(name) || "";
}

const listOutput = execFileSync(
  "supabase",
  ["functions", "list", "--project-ref", projectRef],
  { encoding: "utf8" },
);
const deployment = parseFunctionList(listOutput);

const response = await fetch(`${supabaseUrl}/functions/v1/${functionName}`, {
  method: "POST",
  headers: {
    "content-type": "application/json",
  },
  body: JSON.stringify({ action: "list_countries" }),
});

let body = {};
try {
  body = await response.json();
} catch {
  body = {};
}

const anonymousPost = {
  status: response.status,
  sbErrorCode: selectedHeader(response, "sb-error-code"),
  sbProjectRef: selectedHeader(response, "sb-project-ref"),
  xSbEdgeRegion: selectedHeader(response, "x-sb-edge-region"),
  xServedBy: selectedHeader(response, "x-served-by"),
  strictTransportSecurity: selectedHeader(response, "strict-transport-security"),
  responseCode: typeof body.code === "string" ? body.code : "",
  responseMessage:
    typeof body.message === "string" && body.message.length <= 120
      ? body.message
      : "",
};

const allPassed =
  deployment?.status === "ACTIVE" &&
  Number.isInteger(deployment.version) &&
  deployment.version > 0 &&
  response.status === 401 &&
  anonymousPost.responseCode === "UNAUTHORIZED_NO_AUTH_HEADER";

const evidence = {
  schemaVersion: 1,
  generatedAtUtc: timestamp,
  projectRef,
  scope:
    "Credential-free deployed admin authorization boundary smoke for FANZONE Supabase Edge Function",
  command: "node tool/capture_admin_auth_deploy_smoke.mjs",
  status: allPassed ? "PASS" : "FAIL",
  functionName,
  deployment,
  anonymousPost,
  notes: [
    "The deployed admin_user_management function must be active in the linked Supabase project.",
    "A no-token POST must fail before any viewer/admin/super-admin action can execute.",
    "Role-specific behavior is covered by the shared auth unit tests and critical admin UAT evidence; this smoke avoids storing privileged JWTs.",
  ],
};

for (const target of [outputPath, archivePath]) {
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, `${JSON.stringify(evidence, null, 2)}\n`);
}

console.log(
  `Admin auth deploy smoke ${evidence.status}: ${functionName} v${deployment?.version ?? "unknown"}, anonymous POST ${response.status}.`,
);
console.log(`Evidence: ${outputPath}`);
console.log(`Archive: ${archivePath}`);

if (!allPassed) process.exit(1);
