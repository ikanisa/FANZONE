#!/usr/bin/env node
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const root = process.cwd();
const scanRoots = ["lib", "apps", "packages"];
const ignoredSegments = new Set([
  "node_modules",
  "dist",
  "build",
  ".dart_tool",
  ".vite",
]);
const sourceExtensions = new Set([
  ".dart",
  ".js",
  ".jsx",
  ".mjs",
  ".ts",
  ".tsx",
]);

const violations = [];
let checkedSubscriptions = 0;

function extensionOf(path) {
  const dot = path.lastIndexOf(".");
  return dot === -1 ? "" : path.slice(dot);
}

function walk(dir) {
  for (const entry of readdirSync(dir)) {
    if (ignoredSegments.has(entry)) continue;
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      walk(fullPath);
      continue;
    }
    if (sourceExtensions.has(extensionOf(fullPath))) {
      inspectFile(fullPath);
    }
  }
}

function inspectFile(filePath) {
  const source = readFileSync(filePath, "utf8");
  const lines = source.split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const isSupabaseJsRealtime = line.includes("'postgres_changes'") ||
      line.includes('"postgres_changes"');
    const isSupabaseDartRealtime = line.includes(".onPostgresChanges(");
    if (!isSupabaseJsRealtime && !isSupabaseDartRealtime) continue;

    checkedSubscriptions += 1;
    const window = lines.slice(index, index + 14).join("\n");
    if (!/\bfilter\s*:/.test(window)) {
      violations.push({
        filePath,
        line: index + 1,
        detail: "missing realtime filter in subscription config",
      });
      continue;
    }

    if (isSupabaseJsRealtime && /filter\s*:\s*undefined\b/.test(window)) {
      violations.push({
        filePath,
        line: index + 1,
        detail: "realtime filter is explicitly undefined",
      });
    }
  }
}

for (const scanRoot of scanRoots) {
  const fullRoot = join(root, scanRoot);
  try {
    if (statSync(fullRoot).isDirectory()) walk(fullRoot);
  } catch {
    // Optional workspaces may be absent in smaller checkouts.
  }
}

console.log("FANZONE scoped realtime scan");
console.log(`Checked ${checkedSubscriptions} realtime subscription(s).`);

if (violations.length > 0) {
  console.error("\nUnscoped realtime subscriptions found:");
  for (const violation of violations) {
    console.error(
      `- ${relative(root, violation.filePath)}:${violation.line} ${violation.detail}`,
    );
  }
  console.error(
    "\nAdd an id, venue_id, session_id, or equivalent tenant-owned filter. Whole-table realtime channels are not allowed.",
  );
  process.exit(1);
}

console.log("Scoped realtime scan passed.");
