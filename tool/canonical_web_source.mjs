#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const repoRoot = "/Volumes/PRO-G40/FANZONE";
const sourceRoot = process.env.FANZONE_CANONICAL_SOURCE?.trim() || "";
const sourceSrc = sourceRoot ? path.join(sourceRoot, "src") : "";
const targetRoot = path.join(repoRoot, "website");
const targetSrc = path.join(targetRoot, "src");
const manifestPath = path.join(targetRoot, "canonical-source-manifest.json");

const ignoredNames = new Set([".DS_Store"]);

async function exists(targetPath) {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

async function listFiles(rootDir, currentDir = rootDir) {
  const entries = await fs.readdir(currentDir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    if (ignoredNames.has(entry.name)) continue;
    const fullPath = path.join(currentDir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await listFiles(rootDir, fullPath));
      continue;
    }
    files.push(path.relative(rootDir, fullPath).split(path.sep).join("/"));
  }

  files.sort();
  return files;
}

function normalizeLines(text) {
  return text.replace(/\r\n/g, "\n");
}

function normalizeSourceForHash(text) {
  return normalizeLines(text)
    .replace(/import\s+type\s+\{/g, "import {")
    .replace(/\{\s*type\s+/g, "{ ")
    .replace(/,\s*type\s+/g, ", ")
    .trimEnd();
}

async function hashFile(filePath) {
  const extension = path.extname(filePath);
  if ([".ts", ".tsx", ".js", ".jsx", ".css", ".json", ".md"].includes(extension)) {
    const content = normalizeSourceForHash(await fs.readFile(filePath, "utf8"));
    return crypto.createHash("sha256").update(content).digest("hex");
  }

  const content = await fs.readFile(filePath);
  return crypto.createHash("sha256").update(content).digest("hex");
}

function extractRoutes(appSource) {
  const routes = [];
  const routePattern = /<Route\s+path="([^"]+)"/g;
  for (const match of appSource.matchAll(routePattern)) {
    routes.push(match[1]);
  }
  return [...new Set(routes)];
}

function extractCssTokens(cssSource) {
  const tokens = {};
  const tokenPattern = /--([\w-]+):\s*([^;]+);/g;
  for (const match of cssSource.matchAll(tokenPattern)) {
    tokens[match[1]] = match[2].trim();
  }
  return tokens;
}

async function buildManifest(rootDir, label) {
  const srcDir = path.join(rootDir, "src");
  const files = await listFiles(srcDir);
  const hashedFiles = {};

  for (const relativePath of files) {
    hashedFiles[relativePath] = await hashFile(path.join(srcDir, relativePath));
  }

  const appSource = normalizeLines(
    await fs.readFile(path.join(srcDir, "App.tsx"), "utf8"),
  );
  const cssSource = normalizeLines(
    await fs.readFile(path.join(srcDir, "index.css"), "utf8"),
  );

  return {
    sourceLabel: label,
    generatedAt: new Date().toISOString(),
    routes: extractRoutes(appSource),
    cssTokens: extractCssTokens(cssSource),
    files: hashedFiles,
    components: files
      .filter((file) => file.startsWith("components/") && file.endsWith(".tsx")),
  };
}

function comparableManifest(manifest) {
  return {
    routes: manifest.routes,
    cssTokens: manifest.cssTokens,
    files: manifest.files,
    components: manifest.components,
  };
}

function assertEqualManifests(left, right, message) {
  const leftJson = JSON.stringify(comparableManifest(left));
  const rightJson = JSON.stringify(comparableManifest(right));
  if (leftJson !== rightJson) {
    throw new Error(message);
  }
}

async function syncCanonicalSource() {
  if (!sourceSrc || !await exists(sourceSrc)) {
    throw new Error(`Canonical source not found at ${sourceSrc}`);
  }

  await fs.rm(targetSrc, { recursive: true, force: true });
  await fs.cp(sourceSrc, targetSrc, {
    recursive: true,
    filter: (filePath) => !ignoredNames.has(path.basename(filePath)),
  });

  const manifest = await buildManifest(sourceRoot, sourceRoot);
  await fs.writeFile(`${manifestPath}`, `${JSON.stringify(manifest, null, 2)}\n`);

  console.log(`Synced canonical UI source from ${sourceRoot} to ${targetSrc}`);
  console.log(`Wrote manifest to ${manifestPath}`);
}

async function snapshotCanonicalSource() {
  const manifest = await buildManifest(targetRoot, targetRoot);
  await fs.writeFile(`${manifestPath}`, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`Wrote canonical snapshot to ${manifestPath}`);
}

async function checkCanonicalSource() {
  const websiteManifest = await buildManifest(targetRoot, targetSrc);

  if (sourceSrc && await exists(sourceSrc)) {
    const sourceManifest = await buildManifest(sourceRoot, sourceRoot);
    assertEqualManifests(
      sourceManifest,
      websiteManifest,
      "website/src has drifted from the canonical FANZONE source app.",
    );
    console.log("Canonical source check passed against the external FANZONE source.");
    return;
  }

  if (!await exists(manifestPath)) {
    throw new Error(
      `Canonical manifest missing at ${manifestPath}. Run the sync command locally first.`,
    );
  }

  const manifest = JSON.parse(await fs.readFile(manifestPath, "utf8"));
  assertEqualManifests(
    manifest,
    websiteManifest,
    "website/src no longer matches the committed canonical snapshot.",
  );
  console.log("Canonical source check passed against the committed snapshot.");
}

async function main() {
  const command = process.argv[2];
  switch (command) {
    case "sync":
      await syncCanonicalSource();
      return;
    case "snapshot":
      await snapshotCanonicalSource();
      return;
    case "check":
      await checkCanonicalSource();
      return;
    default:
      console.error("Usage: node tool/canonical_web_source.mjs <sync|snapshot|check>");
      process.exitCode = 1;
  }
}

await main();
