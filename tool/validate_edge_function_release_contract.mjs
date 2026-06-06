#!/usr/bin/env node

import fs from "node:fs";
import process from "node:process";

const requiredFunctions = [
  { name: "fan-trivia", verifyJwt: false },
  { name: "song-guess", verifyJwt: false },
  { name: "music-bingo", verifyJwt: false },
  { name: "sync-livescore-football", verifyJwt: false },
  { name: "whatsapp-otp", verifyJwt: false },
  { name: "order_create", verifyJwt: false },
  { name: "order_mark_paid", verifyJwt: false },
  { name: "order_update_status", verifyJwt: false },
  { name: "payment-hub", verifyJwt: false },
  { name: "menu_ocr_parse", verifyJwt: false },
  { name: "settle-match-pools", verifyJwt: false },
  { name: "dispatch-match-alerts", verifyJwt: false },
  { name: "push-notify", verifyJwt: false },
  { name: "generate-pool-social-card", verifyJwt: false },
  { name: "ring_bell", verifyJwt: false },
];

const files = {
  config: "supabase/config.toml",
  deployment: "docs/release/deployment-readme.md",
  backend: "docs/architecture/backend.md",
  evidenceCollector: "tool/collect_world_class_evidence.sh",
};

function read(path) {
  return fs.readFileSync(path, "utf8");
}

const config = read(files.config);
const deployment = read(files.deployment);
const backend = read(files.backend);
const evidenceCollector = read(files.evidenceCollector);
const errors = [];

for (const fn of requiredFunctions) {
  const deployLine = `supabase functions deploy ${fn.name}`;
  if (!deployment.includes(deployLine)) {
    errors.push(`${files.deployment} must include: ${deployLine}`);
  }

  if (!backend.includes(`| \`${fn.name}\``)) {
    errors.push(`${files.backend} must list ${fn.name} in the Edge Function inventory.`);
  }

  if (fn.deployOnly) continue;

  const sectionPattern = new RegExp(
    `\\[functions\\.${fn.name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\]\\s+verify_jwt\\s*=\\s*${fn.verifyJwt}`,
    "m",
  );
  if (!sectionPattern.test(config)) {
    errors.push(`${files.config} must configure [functions.${fn.name}] verify_jwt = ${fn.verifyJwt}.`);
  }
}

if (!deployment.includes("tool/supabase_game_edge_smoke.sh")) {
  errors.push(`${files.deployment} must run tool/supabase_game_edge_smoke.sh after deployment.`);
}

if (!deployment.includes("tool/supabase_app_edge_smoke.sh")) {
  errors.push(`${files.deployment} must run tool/supabase_app_edge_smoke.sh after deployment.`);
}

if (!deployment.includes("tool/supabase_whatsapp_auth_smoke.sh")) {
  errors.push(`${files.deployment} must run tool/supabase_whatsapp_auth_smoke.sh after deployment.`);
}

if (!deployment.includes("tool/supabase_edge_job_smoke.sh")) {
  errors.push(`${files.deployment} must run tool/supabase_edge_job_smoke.sh after deployment.`);
}

if (!deployment.includes("tool/scheduler_payload_smoke.sh")) {
  errors.push(`${files.deployment} must run tool/scheduler_payload_smoke.sh after deployment.`);
}

for (const smokeTool of [
  "tool/supabase_whatsapp_auth_smoke.sh",
  "tool/supabase_app_edge_smoke.sh",
  "tool/supabase_game_edge_smoke.sh",
  "tool/scheduler_payload_smoke.sh",
]) {
  if (!evidenceCollector.includes(smokeTool)) {
    errors.push(`${files.evidenceCollector} must collect ${smokeTool}.`);
  }
}

if (errors.length > 0) {
  console.error("Edge Function release contract validation failed:");
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log("Edge Function release contract validation passed.");
