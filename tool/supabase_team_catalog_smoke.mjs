#!/usr/bin/env node

import fs from "node:fs";
import process from "node:process";

loadDotEnv(".env");

const supabaseUrl = trimTrailingSlash(process.env.SUPABASE_URL || "");
const anonKey =
  process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_PUBLIC_KEY || "";
const localCountryCode = (
  process.env.FANZONE_TEAM_CATALOG_LOCAL_COUNTRY || "MT"
)
  .trim()
  .toUpperCase();

const failures = [];

if (!supabaseUrl) failures.push("SUPABASE_URL is required.");
if (!anonKey) failures.push("SUPABASE_ANON_KEY is required.");
if (!localCountryCode) {
  failures.push("FANZONE_TEAM_CATALOG_LOCAL_COUNTRY must not be empty.");
}

if (failures.length === 0) {
  const [localTeams, topEuropeanTeams, nationalTeams] = await Promise.all([
    fetchTeams({
      label: `local clubs for ${localCountryCode}`,
      params: {
        select:
          "id,name,country,country_code,league_name,region,team_type,is_active",
        is_active: "eq.true",
        country_code: `eq.${localCountryCode}`,
        team_type: "eq.club",
        limit: "25",
      },
    }),
    fetchTeams({
      label: "top European clubs",
      params: {
        select:
          "id,name,country,country_code,league_name,region,team_type,is_active,is_featured,is_popular_pick,popular_pick_rank",
        is_active: "eq.true",
        region: "eq.europe",
        team_type: "eq.club",
        or: "(is_popular_pick.eq.true,is_featured.eq.true)",
        order: "popular_pick_rank.asc.nullslast,name.asc",
        limit: "25",
      },
    }),
    fetchTeams({
      label: "World Cup national teams",
      params: {
        select:
          "id,name,country,country_code,league_name,competition_ids,region,team_type,is_active",
        is_active: "eq.true",
        team_type: "eq.national",
        limit: "50",
      },
    }),
  ]);

  requireRows(localTeams, `No active local club teams found for ${localCountryCode}.`);
  requireRows(topEuropeanTeams, "No active top European club teams found.");
  requireRows(nationalTeams, "No active national teams found.");

  const invalidTopClub = topEuropeanTeams.find(
    (team) =>
      team.region !== "europe" ||
      team.team_type !== "club" ||
      (team.is_popular_pick !== true && team.is_featured !== true),
  );
  if (invalidTopClub) {
    failures.push("Top European query returned a non-featured or non-European club row.");
  }

  const worldCupNational = nationalTeams.filter((team) => {
    const league = String(team.league_name || "").toLowerCase();
    const competitions = Array.isArray(team.competition_ids)
      ? team.competition_ids
      : [];
    return league.includes("world cup") || competitions.includes("fifa_world_cup");
  });
  requireRows(worldCupNational, "No World Cup national-team rows found.");

  if (failures.length === 0) {
    console.log("Supabase team catalog smoke passed.");
    console.log(`local_country=${localCountryCode}`);
    console.log(`local_clubs=${localTeams.length}`);
    console.log(`top_european_clubs=${topEuropeanTeams.length}`);
    console.log(`world_cup_national_teams=${worldCupNational.length}`);
  }
}

if (failures.length > 0) {
  console.error("Supabase team catalog smoke failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

function loadDotEnv(filePath) {
  if (!fs.existsSync(filePath)) return;
  const raw = fs.readFileSync(filePath, "utf8");
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const match = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(trimmed);
    if (!match) continue;
    const [, key, rawValue] = match;
    if (process.env[key]) continue;
    process.env[key] = rawValue
      .trim()
      .replace(/^['"]|['"]$/g, "");
  }
}

function trimTrailingSlash(value) {
  return value.trim().replace(/\/+$/, "");
}

async function fetchTeams({ label, params }) {
  const url = new URL(`${supabaseUrl}/rest/v1/teams`);
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);
  }

  const response = await fetch(url, {
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    const body = await response.text();
    failures.push(`${label} query failed with HTTP ${response.status}: ${body.slice(0, 240)}`);
    return [];
  }

  const rows = await response.json();
  if (!Array.isArray(rows)) {
    failures.push(`${label} query did not return a JSON array.`);
    return [];
  }
  return rows;
}

function requireRows(rows, message) {
  if (!Array.isArray(rows) || rows.length === 0) failures.push(message);
}
