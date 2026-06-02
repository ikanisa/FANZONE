#!/usr/bin/env node
import { readFileSync } from "node:fs";

const files = {
  app: "packages/core/src/orderLifecycle.ts",
  edge: "supabase/functions/_shared/order_lifecycle.ts",
};

function parseArray(source, name) {
  const match = source.match(
    new RegExp(`export\\s+const\\s+${name}[^=]*=\\s*\\[([\\s\\S]*?)\\]\\s+as\\s+const`),
  );
  if (!match) throw new Error(`Missing exported array: ${name}`);
  return [...match[1].matchAll(/"([^"]+)"/g)].map((item) => item[1]);
}

function parseTransitions(source) {
  const body = source.match(
    /export function nextOrderStatuses[\s\S]*?switch \(status\) \{([\s\S]*?)\n  \}/,
  )?.[1];
  if (!body) throw new Error("Missing nextOrderStatuses switch body");

  const transitions = new Map();
  let pendingCases = [];
  for (const line of body.split("\n")) {
    const caseMatch = line.match(/case "([^"]+)":/);
    if (caseMatch) {
      pendingCases.push(caseMatch[1]);
      continue;
    }

    const returnMatch = line.match(/return \[([^\]]*)\]/);
    if (returnMatch) {
      const next = [...returnMatch[1].matchAll(/"([^"]+)"/g)].map((item) =>
        item[1]
      );
      for (const status of pendingCases) {
        transitions.set(status, next);
      }
      pendingCases = [];
    }
  }

  return transitions;
}

function sameArray(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function read(path) {
  return readFileSync(path, "utf8");
}

const appSource = read(files.app);
const edgeSource = read(files.edge);
const appTargetStatuses = parseArray(appSource, "targetOrderStatuses");
const edgeTargetStatuses = parseArray(edgeSource, "targetOrderStatuses");
const appReasonStatuses = parseArray(appSource, "orderStatusesRequiringReason");
const edgeReasonStatuses = parseArray(edgeSource, "orderStatusesRequiringReason");
const edgeLegacyStatuses = parseArray(edgeSource, "legacyOrderStatuses");
const appActiveStatuses = parseArray(appSource, "activeOrderStatuses");
const appTransitions = parseTransitions(appSource);
const edgeTransitions = parseTransitions(edgeSource);
const failures = [];

if (!sameArray(appTargetStatuses, edgeTargetStatuses)) {
  failures.push(
    `targetOrderStatuses differ: app=${appTargetStatuses.join(",")} edge=${edgeTargetStatuses.join(",")}`,
  );
}

if (!sameArray(appReasonStatuses, edgeReasonStatuses)) {
  failures.push(
    `orderStatusesRequiringReason differ: app=${appReasonStatuses.join(",")} edge=${edgeReasonStatuses.join(",")}`,
  );
}

for (const legacyStatus of edgeLegacyStatuses) {
  if (!appActiveStatuses.includes(legacyStatus)) {
    failures.push(`legacy status ${legacyStatus} is not active in app helpers`);
  }
}

const allTransitionStatuses = new Set([
  ...appTransitions.keys(),
  ...edgeTransitions.keys(),
]);

for (const status of allTransitionStatuses) {
  const appNext = appTransitions.get(status);
  const edgeNext = edgeTransitions.get(status);
  if (!appNext || !edgeNext) {
    failures.push(`missing transition rule for ${status}`);
    continue;
  }
  if (!sameArray(appNext, edgeNext)) {
    failures.push(
      `transition mismatch for ${status}: app=${appNext.join(",")} edge=${edgeNext.join(",")}`,
    );
  }
}

console.log("FANZONE order lifecycle parity scan");

if (failures.length > 0) {
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log(
  `Order lifecycle parity scan passed for ${allTransitionStatuses.size} status rule(s).`,
);
