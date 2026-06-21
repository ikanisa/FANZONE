#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const args = new Set(process.argv.slice(2));
const write = args.has("--write");
const check = args.has("--check") || !write;
const root = process.cwd();
const matrixPath = path.resolve(root, "release/qa/flutter-mobile-ux-matrix.json");
const summaryPath = path.resolve(root, "docs/release/flutter-mobile-ux-matrix-summary.md");

const strictPendingPattern = /^(pending|tbd|todo|planned|blocked)\b/i;
const priorities = ["P0", "P1", "P2"];
const statuses = ["pass", "partial", "planned", "blocked", "not_applicable"];
const types = ["route", "redirect", "wizard", "overlay", "component"];

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read ${filePath}: ${error.message}`);
  }
}

function countBy(rows, field, values) {
  const counts = Object.fromEntries(values.map((value) => [value, 0]));
  for (const row of rows) counts[row[field]] = (counts[row[field]] || 0) + 1;
  return counts;
}

function markdownCountTable(title, counts, values) {
  return [
    `## ${title}`,
    "",
    "| Value | Count |",
    "| --- | ---: |",
    ...values.map((value) => `| ${value} | ${counts[value] || 0} |`),
    "",
  ].join("\n");
}

function missingProofKeys(row, proofKeys) {
  if (row.status === "not_applicable") return [];
  return proofKeys.filter((key) => {
    const value = row.proof?.[key];
    return typeof value !== "string" ||
      value.trim().length === 0 ||
      strictPendingPattern.test(value.trim());
  });
}

function escapeCell(value) {
  return String(value ?? "").replaceAll("|", "\\|").replace(/\s+/g, " ").trim();
}

function generateSummary(matrix) {
  const rows = Array.isArray(matrix.rows) ? matrix.rows : [];
  const proofKeys = Array.isArray(matrix.proofKeys) ? matrix.proofKeys : [];
  const statusCounts = countBy(rows, "status", statuses);
  const priorityCounts = countBy(rows, "priority", priorities);
  const typeCounts = countBy(rows, "type", types);
  const incompleteRows = rows.filter((row) =>
    row.status !== "pass" && row.status !== "not_applicable"
  );
  const p0p1Incomplete = incompleteRows.filter((row) =>
    row.priority === "P0" || row.priority === "P1"
  );
  const passCount = rows.filter((row) => row.status === "pass").length;
  const applicableCount = rows.filter((row) => row.status !== "not_applicable").length;
  const passPercent = applicableCount === 0
    ? "0.0"
    : ((passCount / applicableCount) * 100).toFixed(1);

  const lines = [
    "# FANZONE Flutter Mobile UX Matrix Summary",
    "",
    `Generated from \`release/qa/flutter-mobile-ux-matrix.json\`.`,
    `Matrix timestamp: \`${matrix.generatedAtUtc ?? "unknown"}\`.`,
    "",
    "This summary is generated. Update it with `npm run generate:flutter-mobile-ux-summary`.",
    "",
    "## Readiness",
    "",
    `- Applicable surfaces passing strict evidence: ${passCount}/${applicableCount} (${passPercent}%).`,
    `- Incomplete applicable surfaces: ${incompleteRows.length}.`,
    `- Incomplete P0/P1 surfaces: ${p0p1Incomplete.length}.`,
    `- Final 100% claim remains blocked until \`node tool/validate_flutter_mobile_ux_matrix.mjs --require-pass\` passes.`,
    "",
    markdownCountTable("Status Counts", statusCounts, statuses),
    markdownCountTable("Priority Counts", priorityCounts, priorities),
    markdownCountTable("Surface Type Counts", typeCounts, types),
    "## P0/P1 Incomplete Surfaces",
    "",
    "| Priority | Status | Type | Path | Name | Missing Proof Buckets | Source |",
    "| --- | --- | --- | --- | --- | --- | --- |",
  ];

  for (const row of p0p1Incomplete) {
    const missing = missingProofKeys(row, proofKeys);
    lines.push(
      `| ${escapeCell(row.priority)} | ${escapeCell(row.status)} | ${escapeCell(row.type)} | ` +
        `${escapeCell(row.path)} | ${escapeCell(row.name)} | ` +
        `${escapeCell(missing.length === 0 ? "status not pass" : missing.join(", "))} | ` +
        `${escapeCell(row.source)} |`,
    );
  }

  lines.push(
    "",
    "## Next Evidence Actions",
    "",
    "- Capture compact, medium, and expanded screenshots for every P0/P1 route and overlay.",
    "- Add or link large-text, screen-reader, contrast, keyboard/safe-area, reduced-motion, and state evidence for every P0/P1 row.",
    "- Promote rows to `pass` only after each proof bucket points to current evidence.",
    "- Run `node tool/validate_flutter_mobile_ux_matrix.mjs --require-pass` before any 100% or world-class claim.",
    "",
  );

  return `${lines.join("\n").replace(/\n{3,}/g, "\n\n")}\n`;
}

const summary = generateSummary(readJson(matrixPath));

if (write) {
  fs.mkdirSync(path.dirname(summaryPath), { recursive: true });
  fs.writeFileSync(summaryPath, summary);
  console.log(`Wrote ${path.relative(root, summaryPath)}`);
}

if (check) {
  if (!fs.existsSync(summaryPath)) {
    console.error(`Missing generated summary: ${path.relative(root, summaryPath)}`);
    process.exit(1);
  }
  const current = fs.readFileSync(summaryPath, "utf8");
  if (current !== summary) {
    console.error(`${path.relative(root, summaryPath)} is stale.`);
    console.error("Run: npm run generate:flutter-mobile-ux-summary");
    process.exit(1);
  }
  console.log(`Flutter mobile UX summary is current: ${path.relative(root, summaryPath)}`);
}
