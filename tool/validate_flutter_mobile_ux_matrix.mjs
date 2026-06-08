#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const args = process.argv.slice(2);
const requirePass = args.includes("--require-pass");
const targetPath = args.find((arg) => !arg.startsWith("--")) ||
  "release/qa/flutter-mobile-ux-matrix.json";
const absolutePath = path.resolve(process.cwd(), targetPath);

const credentialPattern =
  /(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql:\/\/[^:\s]+:[^@\s]+@)/;

const proofKeys = [
  "compact",
  "medium",
  "expanded",
  "largeText",
  "screenReader",
  "contrast",
  "keyboardSafeArea",
  "reducedMotion",
  "errorEmptyLoading",
  "productBoundary",
  "testEvidence",
  "evidencePath",
];

const expectedRoutes = [
  { path: "/splash", type: "route", routerPath: "/splash" },
  { path: "/feature-unavailable", type: "route", routerPath: "/feature-unavailable" },
  { path: "/", type: "redirect", routerPath: "/" },
  { path: "/onboarding", type: "wizard", routerPath: "/onboarding" },
  { path: "/login", type: "route", routerPath: "/login" },
  { path: "/upgrade", type: "redirect", routerPath: "/upgrade" },
  { path: "/v/:venueSlug", type: "route", routerPath: "/v/:venueSlug" },
  { path: "/bar", type: "route", routerPath: "/bar" },
  { path: "/venue/:venueId", type: "route", routerPath: "/venue/:venueId" },
  { path: "/venues", type: "route", routerPath: "/venues" },
  { path: "/venues/location", type: "route", routerPath: "/venues/location" },
  { path: "/search", type: "route", routerPath: "/search" },
  { path: "/match/:id", type: "route", routerPath: "/match/:id" },
  { path: "/checkout", type: "route", routerPath: "/checkout" },
  { path: "/order/:orderId/success", type: "route", routerPath: "/order/:orderId/success" },
  { path: "/order/:orderId/receipt", type: "route", routerPath: "/order/:orderId/receipt" },
  { path: "/order/:orderId", type: "route", routerPath: "/order/:orderId" },
  { path: "/notifications", type: "route", routerPath: "/notifications" },
  { path: "/profile", type: "route", routerPath: "/profile" },
  { path: "/orders", type: "route", routerPath: "/orders" },
  { path: "/wallet", type: "route", routerPath: "/wallet" },
  {
    path: "/wallet/transaction/:transactionId",
    type: "route",
    routerPath: "/wallet/transaction/:transactionId",
  },
  { path: "/pool/:poolId", type: "route", routerPath: "/pool/:poolId" },
  { path: "/pool/:poolId/join", type: "wizard", routerPath: "/pool/:poolId/join" },
  { path: "/pools/create", type: "wizard", routerPath: "/pools/create" },
  { path: "/game/:gameId", type: "route", routerPath: "/game/:gameId" },
  { path: "/games", type: "redirect", routerPath: "/games" },
  { path: "/home", type: "route", routerPath: "/home" },
  { path: "/home/matches", type: "route", routerPath: "matches" },
  { path: "/pools", type: "route", routerPath: "/pools" },
  { path: "/pools/games", type: "route", routerPath: "games" },
  { path: "/settings", type: "route", routerPath: "/settings" },
  { path: "/settings/privacy", type: "route", routerPath: "privacy" },
  { path: "/settings/help", type: "route", routerPath: "help" },
  { path: "/settings/privacy-policy", type: "route", routerPath: "privacy-policy" },
  { path: "/settings/terms", type: "route", routerPath: "terms" },
  { path: "/pools/:shareSlug", type: "route", routerPath: "/pools/:shareSlug" },
];

const expectedOverlays = [
  "overlay_session_expired_dialog",
  "overlay_sign_in_required_sheet",
  "overlay_onboarding_country_code_picker",
  "overlay_login_country_picker",
  "overlay_menu_item_detail_sheet",
  "overlay_payment_handoff_sheet",
  "overlay_order_support_request_sheet",
  "overlay_payment_proof_sheet",
  "overlay_insufficient_fet_sheet",
  "overlay_invite_friends_sheet",
  "overlay_winner_celebration_sheet",
  "overlay_notice_sheet",
  "overlay_profile_fan_editor_sheet",
  "overlay_game_team_name_dialog",
  "overlay_eligibility_rule_sheet",
  "overlay_app_modal_sheet_component",
  "overlay_web_review_comment_dialog",
];

const allowedTypes = new Set(["route", "redirect", "overlay", "wizard", "component"]);
const allowedStatuses = new Set([
  "pass",
  "partial",
  "planned",
  "blocked",
  "not_applicable",
]);
const allowedPriorities = new Set(["P0", "P1", "P2"]);

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

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read or parse ${filePath}: ${error.message}`);
  }
}

function isStrictProof(value) {
  if (!hasText(value)) return false;
  const normalized = value.trim().toLowerCase();
  return ![
    "pending",
    "tbd",
    "todo",
    "planned",
    "blocked",
  ].some((needle) => normalized === needle || normalized.startsWith(`${needle} `));
}

if (!fs.existsSync(absolutePath)) {
  console.error(`Missing Flutter mobile UX matrix: ${targetPath}`);
  process.exit(1);
}

const raw = fs.readFileSync(absolutePath, "utf8");
if (credentialPattern.test(raw)) {
  console.error(`Flutter mobile UX matrix validation failed for ${targetPath}:`);
  console.error("- matrix appears to contain a live credential pattern.");
  process.exit(1);
}

const data = readJson(absolutePath);
const errors = [];

if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
if (!isIsoDateTime(data.generatedAtUtc)) {
  errors.push("generatedAtUtc must be an ISO UTC timestamp ending in Z.");
}
if (!String(data.scope || "").includes("Flutter customer mobile")) {
  errors.push("scope must describe Flutter customer mobile UX coverage.");
}
if (!Array.isArray(data.proofKeys) ||
  proofKeys.some((key) => !data.proofKeys.includes(key))) {
  errors.push(`proofKeys must include: ${proofKeys.join(", ")}.`);
}

const appRouterPath = repoPath("lib/app_router.dart");
const appRouter = fs.existsSync(appRouterPath) ? fs.readFileSync(appRouterPath, "utf8") : "";
if (!appRouter) errors.push("lib/app_router.dart must exist for route inventory validation.");
for (const route of expectedRoutes) {
  if (!appRouter.includes(`path: '${route.routerPath}'`)) {
    errors.push(`app_router.dart is missing expected GoRoute path ${route.routerPath}.`);
  }
}

const rows = Array.isArray(data.rows) ? data.rows : [];
if (rows.length === 0) errors.push("rows must contain at least one matrix row.");

const ids = new Set();
const routeRowsByPath = new Map();
const overlayIds = new Set();
let passCount = 0;
let nonPassCount = 0;

for (const row of rows) {
  if (!row || typeof row !== "object") {
    errors.push("Each row must be an object.");
    continue;
  }

  if (!hasText(row.id) || !/^[a-z0-9_]+$/.test(row.id)) {
    errors.push(`Invalid row id: ${row.id}`);
  } else if (ids.has(row.id)) {
    errors.push(`Duplicate row id: ${row.id}`);
  } else {
    ids.add(row.id);
  }

  if (!allowedTypes.has(row.type)) errors.push(`${row.id || "row"} has invalid type ${row.type}.`);
  if (!hasText(row.path)) errors.push(`${row.id || "row"} path is required.`);
  if (!hasText(row.name)) errors.push(`${row.id || "row"} name is required.`);
  if (!hasText(row.owner)) errors.push(`${row.id || "row"} owner is required.`);
  if (!allowedPriorities.has(row.priority)) {
    errors.push(`${row.id || "row"} priority must be P0, P1, or P2.`);
  }
  if (!allowedStatuses.has(row.status)) {
    errors.push(`${row.id || "row"} has invalid status ${row.status}.`);
  }

  if (row.status === "pass") passCount += 1;
  if (row.status !== "pass" && row.status !== "not_applicable") nonPassCount += 1;

  if (["route", "redirect", "wizard"].includes(row.type)) {
    if (routeRowsByPath.has(row.path)) errors.push(`Duplicate route matrix path: ${row.path}`);
    routeRowsByPath.set(row.path, row);
  } else if (row.type === "overlay" || row.type === "component") {
    overlayIds.add(row.id);
  }

  if (!repoRefExists(row.source)) {
    errors.push(`${row.id || "row"} source does not exist: ${row.source}`);
  }

  if (!row.proof || typeof row.proof !== "object" || Array.isArray(row.proof)) {
    errors.push(`${row.id || "row"} proof must be an object.`);
    continue;
  }

  for (const key of proofKeys) {
    if (!hasText(row.proof[key])) {
      errors.push(`${row.id || "row"} proof.${key} is required.`);
    }
  }

  if (requirePass && row.status !== "not_applicable") {
    if (row.status !== "pass") {
      errors.push(`${row.id} must be pass in --require-pass mode.`);
    }
    for (const key of proofKeys) {
      if (!isStrictProof(row.proof[key])) {
        errors.push(`${row.id} proof.${key} is not strict evidence: ${row.proof[key]}`);
      }
    }
  }
}

for (const expected of expectedRoutes) {
  const row = routeRowsByPath.get(expected.path);
  if (!row) {
    errors.push(`Matrix is missing route row for ${expected.path}.`);
    continue;
  }
  if (row.type !== expected.type) {
    errors.push(`${expected.path} must be typed as ${expected.type}, found ${row.type}.`);
  }
}

for (const pathValue of routeRowsByPath.keys()) {
  if (!expectedRoutes.some((route) => route.path === pathValue)) {
    errors.push(`Matrix has unexpected route/redirect/wizard path: ${pathValue}`);
  }
}

for (const overlayId of expectedOverlays) {
  if (!overlayIds.has(overlayId)) errors.push(`Matrix is missing overlay/component row ${overlayId}.`);
}

if (errors.length > 0) {
  console.error(`Flutter mobile UX matrix validation failed for ${targetPath}:`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

const routeCount = rows.filter((row) => row.type === "route").length;
const redirectCount = rows.filter((row) => row.type === "redirect").length;
const wizardCount = rows.filter((row) => row.type === "wizard").length;
const overlayCount = rows.filter((row) => row.type === "overlay").length;
const componentCount = rows.filter((row) => row.type === "component").length;

console.log(`Flutter mobile UX matrix validation passed for ${targetPath}.`);
console.log(
  `Rows: ${rows.length} (${routeCount} routes, ${redirectCount} redirects, ` +
    `${wizardCount} wizards, ${overlayCount} overlays, ${componentCount} components).`,
);
console.log(`Status: ${passCount} pass, ${nonPassCount} incomplete, ${requirePass ? "strict" : "inventory"} mode.`);
