/**
 * HTTP handler for gemini-team-discovery edge function.
 *
 * Orchestrates the discovery pipeline:
 * 1. Parse request (region, country_code, or country list)
 * 2. Iterate league catalog entries
 * 3. Call Gemini + Grounding for each country
 * 4. Upsert results into DB
 * 5. Sync onboarding popular teams
 * 6. Return summary or export catalog/data
 */
import { buildCorsHeaders, isAuthorizedEdgeRequest } from "../_shared/http.ts";
import {
  ALLOWED_HEADERS,
  EXPECTED_TEAM_TOTAL,
  FUNCTION_NAME,
  type LeagueEntry,
  leagueForCountryCode,
  leaguesForRegion,
} from "./constants.ts";
import { discoverTeamsForLeague } from "./gemini.ts";
import {
  exportAllTeams,
  exportCatalog,
  exportPopularTeams,
  getActiveTeamCount,
  syncOnboardingPopularTeams,
  upsertTeams,
} from "./repo.ts";
import type {
  CountryResult,
  DiscoveryRequest,
  DiscoveryResponse,
} from "./types.ts";

const corsHeaders = {
  ...buildCorsHeaders(ALLOWED_HEADERS),
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function normalizeRegion(
  value: DiscoveryRequest["region"] | string | null | undefined,
): "europe" | "africa" | "americas" | "all" {
  switch ((value ?? "").trim().toLowerCase()) {
    case "africa":
      return "africa";
    case "europe":
      return "europe";
    case "north_america":
    case "northamerica":
    case "americas":
      return "americas";
    default:
      return "all";
  }
}

function resolveEntries(body: DiscoveryRequest): LeagueEntry[] {
  const requestedCodes = new Set<string>();

  if (body.country_code?.trim()) {
    requestedCodes.add(body.country_code.trim().toUpperCase());
  }

  if (Array.isArray(body.countries)) {
    for (const country of body.countries) {
      const code = country.trim().toUpperCase();
      if (code.length > 0) requestedCodes.add(code);
    }
  }

  const entries = requestedCodes.size > 0
    ? Array.from(requestedCodes)
      .map((code) => leagueForCountryCode(code))
      .filter((entry): entry is LeagueEntry => entry != null)
    : leaguesForRegion(normalizeRegion(body.region));

  if (body.limit && body.limit > 0) {
    return entries.slice(0, body.limit);
  }

  return entries;
}

function authorizeRequest(req: Request, requestId: string): Response | null {
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  const matchSyncSecret = Deno.env.get("MATCH_SYNC_SECRET")?.trim();
  const anonKey = Deno.env.get("FANZONE_ANON_KEY")?.trim();

  if (!serviceRoleKey && !matchSyncSecret && !anonKey) {
    return null;
  }

  const authorized = isAuthorizedEdgeRequest({
    req,
    serviceRoleKey,
    allowServiceRoleBearer: true,
    sharedSecrets: [
      { header: "x-match-sync-secret", value: matchSyncSecret },
    ],
  });

  // Also accept anon key as bearer (for CLI invocation)
  if (authorized) return null;
  if (anonKey) {
    const bearer = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "")
      .trim();
    if (bearer === anonKey) return null;
  }

  return jsonResponse(401, {
    success: false,
    requestId,
    error: "Unauthorized.",
  });
}

function expectedTeamCount(entries: LeagueEntry[]): number {
  return entries.reduce((total, entry) => total + entry.expectedTeams, 0);
}

export async function handleTeamDiscoveryRequest(
  req: Request,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const requestId = crypto.randomUUID();
  const startTime = Date.now();
  const unauthorized = authorizeRequest(req, requestId);
  if (unauthorized != null) return unauthorized;

  let body: DiscoveryRequest = {};
  try {
    if (req.method === "POST") {
      body = (await req.json()) as DiscoveryRequest;
    }
  } catch {
    return jsonResponse(400, {
      success: false,
      requestId,
      error: "Invalid JSON body.",
    });
  }

  const entries = resolveEntries(body);
  if (entries.length === 0) {
    return jsonResponse(400, {
      success: false,
      requestId,
      error:
        "No leagues matched. Use { region: 'europe'|'africa'|'americas'|'all' }, { country_code: 'GB' }, or { countries: ['GB', 'ES', ...] }.",
    });
  }

  console.log(
    `[${FUNCTION_NAME}] Starting discovery for ${entries.length} catalog entries.`,
  );

  const results: CountryResult[] = [];
  const errors: string[] = [];
  let totalDiscovered = 0;
  let totalUpserted = 0;

  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index];
    const expectedLeague = entry.league ?? "top-flight discovery";
    const countryLabel = `[${
      index + 1
    }/${entries.length}] ${entry.country} (${expectedLeague})`;

    try {
      console.log(`[${FUNCTION_NAME}] ${countryLabel}: discovering...`);
      const discovery = await discoverTeamsForLeague(entry);

      let upsertedCount = 0;
      if (discovery.teams.length > 0) {
        upsertedCount = await upsertTeams(
          entry,
          discovery.league_name,
          discovery.teams,
        );
      }

      totalDiscovered += discovery.teams.length;
      totalUpserted += upsertedCount;
      results.push({
        countryCode: entry.countryCode,
        country: entry.country,
        league: discovery.league_name,
        expectedTeams: entry.expectedTeams,
        teamsDiscovered: discovery.teams.length,
        teamsUpserted: upsertedCount,
        grounding: body.include_grounding ? discovery.grounding : undefined,
      });

      console.log(
        `[${FUNCTION_NAME}] ${countryLabel}: ${discovery.teams.length} found, ${upsertedCount} upserted.`,
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[${FUNCTION_NAME}] ${countryLabel}: ${message}`);
      errors.push(`${entry.country}: ${message}`);
      results.push({
        countryCode: entry.countryCode,
        country: entry.country,
        league: entry.league ?? `${entry.country} First Division`,
        expectedTeams: entry.expectedTeams,
        teamsDiscovered: 0,
        teamsUpserted: 0,
        error: message,
      });
    }

    if (index < entries.length - 1) {
      await delay(1500);
    }
  }

  try {
    await syncOnboardingPopularTeams();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    errors.push(`syncOnboardingPopularTeams: ${message}`);
  }

  const durationMs = Date.now() - startTime;
  const finalCount = await getActiveTeamCount();

  const response: DiscoveryResponse = {
    success: errors.length === 0,
    requestId,
    totalCountries: results.length,
    expectedTeams: expectedTeamCount(entries),
    totalTeamsDiscovered: totalDiscovered,
    totalTeamsUpserted: totalUpserted,
    results,
    errors,
    durationMs,
  };

  return jsonResponse(200, {
    ...response,
    totalActiveTeamsInDb: finalCount,
  });
}

export async function handleExportRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const requestId = crypto.randomUUID();
  const unauthorized = authorizeRequest(req, requestId);
  if (unauthorized != null) return unauthorized;

  const url = new URL(req.url);
  const searchParams = url.searchParams;
  const regionParam = searchParams.get("region");
  const request: DiscoveryRequest = {
    region: regionParam == null ? undefined : normalizeRegion(regionParam),
    country_code: searchParams.get("country_code") ?? undefined,
    countries: searchParams.get("countries")
      ?.split(",")
      .map((code) => code.trim())
      .filter((code) => code.length > 0),
    limit: searchParams.get("limit") == null
      ? undefined
      : Number(searchParams.get("limit")),
  };
  const entries = resolveEntries(request);

  if (searchParams.get("catalog") === "1") {
    const catalog = entries.length > 0 ? entries : exportCatalog();
    return jsonResponse(200, {
      requestId,
      catalog,
      count: catalog.length,
      expectedTeams: expectedTeamCount(catalog),
      globalExpectedTeams: EXPECTED_TEAM_TOTAL,
    });
  }

  const allowedCountryCodes = entries.length > 0
    ? new Set(entries.map((entry) => entry.countryCode))
    : null;
  const allowedRegions = entries.length > 0
    ? new Set(entries.map((entry) => entry.region))
    : null;
  const teams = (await exportAllTeams()).filter((team) => {
    if (allowedCountryCodes == null && allowedRegions == null) return true;
    const countryCode = String(team.country_code ?? "").toUpperCase();
    const region = String(team.region ?? "").toLowerCase();
    return (
      (allowedCountryCodes?.has(countryCode) ?? false) ||
      (allowedRegions?.has(region as LeagueEntry["region"]) ?? false)
    );
  });
  const popularTeams = (await exportPopularTeams()).filter((team) => {
    if (allowedCountryCodes == null && allowedRegions == null) return true;
    const countryCode = String(team.country_code ?? "").toUpperCase();
    const region = String(team.region ?? "").toLowerCase();
    return (
      (allowedCountryCodes?.has(countryCode) ?? false) ||
      (allowedRegions?.has(region as LeagueEntry["region"]) ?? false)
    );
  });

  return jsonResponse(200, {
    requestId,
    teams,
    popular_teams: popularTeams,
    count: teams.length,
    expectedTeams: entries.length > 0
      ? expectedTeamCount(entries)
      : EXPECTED_TEAM_TOTAL,
  });
}
