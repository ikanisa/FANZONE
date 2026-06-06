#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const projectRef = process.env.SUPABASE_PROJECT_REF || "kjuhheobmdvjwgnzlcwx";
const supabaseUrl = (
  process.env.SUPABASE_URL || `https://${projectRef}.supabase.co`
).replace(/\/+$/, "");

const outputPath =
  process.argv[2] || "release/qa/edge-cors-smoke-evidence.json";
const timestamp = new Date().toISOString();
const stamp = timestamp.replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
const archivalPath =
  `output/release-evidence/edge-cors-smoke/${stamp}.json`;

const functionsToCheck = [
  "whatsapp-otp",
  "generate-pool-social-card",
];

const allowedOrigins = [
  "https://fanzone.ikanisa.com",
  "https://fanzoneadmin.ikanisa.com",
  "https://fanzone.venue.ikanisa.com",
  "https://fanzonetv.ikanisa.com",
];

const blockedOrigins = [
  "https://evil.example",
];

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function headerValue(headers, name) {
  return headers.get(name) || "";
}

async function checkPreflight(functionName, origin, expectedAllowed) {
  const response = await fetch(`${supabaseUrl}/functions/v1/${functionName}`, {
    method: "OPTIONS",
    headers: {
      Origin: origin,
      "Access-Control-Request-Method": "POST",
    },
  });

  const allowOrigin = headerValue(response.headers, "access-control-allow-origin");
  const allowMethods = headerValue(response.headers, "access-control-allow-methods");
  const allowHeaders = headerValue(response.headers, "access-control-allow-headers");
  const vary = headerValue(response.headers, "vary");

  const passed = expectedAllowed
    ? response.status >= 200 &&
      response.status < 300 &&
      allowOrigin === origin &&
      allowMethods.toUpperCase().includes("POST") &&
      allowHeaders.toLowerCase().includes("authorization") &&
      vary.toLowerCase().includes("origin")
    : allowOrigin === "";

  return {
    functionName,
    originSha256: sha256(origin),
    origin,
    expectedAllowed,
    status: response.status,
    accessControlAllowOrigin: allowOrigin,
    accessControlAllowMethods: allowMethods,
    accessControlAllowHeaders: allowHeaders,
    vary,
    passed,
  };
}

const checks = [];
for (const functionName of functionsToCheck) {
  for (const origin of allowedOrigins) {
    checks.push(await checkPreflight(functionName, origin, true));
  }
  for (const origin of blockedOrigins) {
    checks.push(await checkPreflight(functionName, origin, false));
  }
}

const allPassed = checks.every((check) => check.passed);
const evidence = {
  schemaVersion: 1,
  generatedAtUtc: timestamp,
  projectRef,
  scope:
    "Credential-free deployed Supabase Edge CORS preflight smoke for browser-callable FANZONE functions",
  command: "node tool/capture_edge_cors_smoke.mjs",
  status: allPassed ? "PASS" : "FAIL",
  functions: functionsToCheck,
  allowedOrigins,
  blockedOriginHashes: blockedOrigins.map((origin) => sha256(origin)),
  checks,
  notes: [
    "Allowed production origins must be reflected exactly and must not use wildcard CORS.",
    "Blocked origins must not receive access-control-allow-origin.",
    "No Supabase key, service-role key, database URL, PAT, or bearer credential is required for OPTIONS preflight smoke.",
  ],
};

for (const target of [outputPath, archivalPath]) {
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, `${JSON.stringify(evidence, null, 2)}\n`);
}

console.log(
  `Edge CORS smoke ${evidence.status}: ${checks.filter((check) => check.passed).length}/${checks.length} checks passed.`,
);
console.log(`Evidence: ${outputPath}`);
console.log(`Archive: ${archivalPath}`);

if (!allPassed) process.exit(1);
