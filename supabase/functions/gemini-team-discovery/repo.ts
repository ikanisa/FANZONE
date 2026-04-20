import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

import { LEAGUE_CATALOG, type LeagueEntry } from "./constants.ts";
import type { DiscoveredTeam } from "./types.ts";

interface PopularTeamSeed {
  rank: number;
  teamId: string;
  displayName: string;
  crestUrl: string;
  aliases?: string[];
}

const TEAM_EXPORT_SELECT_COLUMNS =
  "id, name, short_name, country, country_code, league_name, region, logo_url, crest_url, search_terms, aliases, is_popular_pick, popular_pick_rank, is_featured, is_active";

const ONBOARDING_POPULAR_TEAM_SEED: PopularTeamSeed[] = [
  {
    rank: 1,
    teamId: "es-real-madrid",
    displayName: "Real Madrid",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg",
  },
  {
    rank: 2,
    teamId: "es-barcelona",
    displayName: "Barcelona",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/en/4/47/FC_Barcelona_%28crest%29.svg",
    aliases: ["Barca"],
  },
  {
    rank: 3,
    teamId: "gb-arsenal",
    displayName: "Arsenal",
    crestUrl: "https://upload.wikimedia.org/wikipedia/en/5/53/Arsenal_FC.svg",
  },
  {
    rank: 4,
    teamId: "gb-manchester-city",
    displayName: "Manchester City",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/en/e/eb/Manchester_City_FC_badge.svg",
    aliases: ["Man City"],
  },
  {
    rank: 5,
    teamId: "gb-manchester-united",
    displayName: "Manchester United",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/en/7/7a/Manchester_United_FC_crest.svg",
    aliases: ["Man United"],
  },
  {
    rank: 6,
    teamId: "gb-liverpool",
    displayName: "Liverpool",
    crestUrl: "https://upload.wikimedia.org/wikipedia/en/0/0c/Liverpool_FC.svg",
  },
  {
    rank: 7,
    teamId: "gb-chelsea",
    displayName: "Chelsea",
    crestUrl: "https://upload.wikimedia.org/wikipedia/en/c/cc/Chelsea_FC.svg",
  },
  {
    rank: 8,
    teamId: "gb-tottenham-hotspur",
    displayName: "Tottenham Hotspur",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/en/b/b4/Tottenham_Hotspur.svg",
    aliases: ["Tottenham", "Spurs"],
  },
  {
    rank: 9,
    teamId: "de-bayern-munich",
    displayName: "Bayern Munich",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/commons/8/8d/FC_Bayern_M%C3%BCnchen_logo_%282024%29.svg",
    aliases: ["Bayern"],
  },
  {
    rank: 10,
    teamId: "de-borussia-dortmund",
    displayName: "Borussia Dortmund",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/commons/6/67/Borussia_Dortmund_logo.svg",
    aliases: ["Dortmund", "BVB"],
  },
  {
    rank: 11,
    teamId: "fr-paris-saint-germain",
    displayName: "PSG",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/en/a/a7/Paris_Saint-Germain_F.C..svg",
    aliases: ["Paris Saint-Germain"],
  },
  {
    rank: 12,
    teamId: "it-juventus",
    displayName: "Juventus",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/commons/b/bc/Juventus_FC_2017_icon_%28black%29.svg",
  },
  {
    rank: 13,
    teamId: "it-ac-milan",
    displayName: "AC Milan",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/commons/d/da/Associazione_Calcio_Milan.svg",
  },
  {
    rank: 14,
    teamId: "it-inter-milan",
    displayName: "Inter Milan",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/commons/0/05/FC_Internazionale_Milano_2021.svg",
  },
  {
    rank: 15,
    teamId: "it-ssc-napoli",
    displayName: "Napoli",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/commons/2/2d/SSC_Neapel.svg",
    aliases: ["SSC Napoli"],
  },
  {
    rank: 16,
    teamId: "es-atletico-madrid",
    displayName: "Atletico Madrid",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/en/f/f9/Atletico_Madrid_Logo_2024.svg",
    aliases: ["Atleti"],
  },
  {
    rank: 17,
    teamId: "nl-ajax",
    displayName: "Ajax",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/en/7/79/Ajax_Amsterdam.svg",
  },
  {
    rank: 18,
    teamId: "pt-fc-porto",
    displayName: "Porto",
    crestUrl: "https://upload.wikimedia.org/wikipedia/en/f/f1/FC_Porto.svg",
    aliases: ["FC Porto"],
  },
  {
    rank: 19,
    teamId: "pt-sl-benfica",
    displayName: "Benfica",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/en/a/a2/SL_Benfica_logo.svg",
    aliases: ["SL Benfica"],
  },
  {
    rank: 20,
    teamId: "pt-sporting-cp",
    displayName: "Sporting CP",
    crestUrl:
      "https://upload.wikimedia.org/wikipedia/commons/3/33/Sporting_Clube_de_Portugal.svg",
    aliases: ["Sporting"],
  },
];

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing env: ${name}`);
  return value;
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9\s-]/g, "")
    .trim()
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-");
}

function getAdminClient(): SupabaseClient {
  return createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: { autoRefreshToken: false, persistSession: false },
    },
  );
}

function competitionIdFor(countryCode: string) {
  return `league-${countryCode.toLowerCase()}-d1`;
}

function buildSearchTerms(team: DiscoveredTeam) {
  const values = new Set<string>([
    team.name,
    team.short_name,
    ...team.search_terms,
  ]);
  return Array.from(values)
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
}

function dedupeStrings(values: Array<string | null | undefined>): string[] {
  const deduped = new Set<string>();
  for (const value of values) {
    const trimmed = value?.trim();
    if (trimmed) deduped.add(trimmed);
  }
  return Array.from(deduped);
}

function mapExportRow(row: Record<string, unknown>) {
  const aliases = Array.isArray(row.aliases) && row.aliases.length > 0
    ? row.aliases
    : Array.isArray(row.search_terms)
    ? row.search_terms
    : [];

  return {
    id: row.id,
    name: row.name,
    short_name: row.short_name,
    country: row.country,
    country_code: row.country_code,
    league: row.league_name,
    region: row.region,
    aliases,
    crest_url: row.crest_url ?? row.logo_url,
    is_popular: row.is_popular_pick === true || row.is_featured === true,
    popular_rank: row.popular_pick_rank,
    is_active: row.is_active === true,
  };
}

function buildPopularTeamRow(
  teamRow: Record<string, unknown>,
  seed: PopularTeamSeed,
): Record<string, unknown> {
  const searchTerms = dedupeStrings([
    seed.displayName,
    String(teamRow.name ?? ""),
    String(teamRow.short_name ?? ""),
    ...(seed.aliases ?? []),
    ...(Array.isArray(teamRow.aliases) ? teamRow.aliases.map(String) : []),
    ...(Array.isArray(teamRow.search_terms)
      ? teamRow.search_terms.map(String)
      : []),
  ]);
  const crestUrl = String(
    teamRow.crest_url ?? teamRow.logo_url ?? seed.crestUrl,
  ).trim();

  return {
    id: seed.teamId,
    name: seed.displayName,
    short_name: teamRow.short_name,
    country: teamRow.country,
    country_code: teamRow.country_code,
    league_name: teamRow.league_name,
    region: "europe",
    aliases: searchTerms,
    search_terms: searchTerms,
    logo_url: crestUrl,
    crest_url: crestUrl,
    is_active: true,
    is_featured: false,
    is_popular_pick: true,
    popular_pick_rank: seed.rank,
    updated_at: new Date().toISOString(),
  };
}

async function upsertCompetition(
  client: SupabaseClient,
  entry: LeagueEntry,
  leagueName: string,
) {
  const row = {
    id: competitionIdFor(entry.countryCode),
    name: leagueName,
    short_name: leagueName.length > 32 ? leagueName.slice(0, 32) : leagueName,
    country: entry.country,
    tier: 1,
    region: entry.region,
    competition_type: "league",
    is_featured: false,
    updated_at: new Date().toISOString(),
  };

  const { error } = await client
    .from("competitions")
    .upsert(row, { onConflict: "id" });
  if (error) {
    console.error(
      "[gemini-team-discovery] Competition upsert failed:",
      error.message,
    );
  }

  return row.id;
}

export async function upsertTeams(
  entry: LeagueEntry,
  leagueName: string,
  teams: DiscoveredTeam[],
): Promise<number> {
  if (teams.length === 0) return 0;

  const client = getAdminClient();
  const competitionId = await upsertCompetition(client, entry, leagueName);
  let upserted = 0;
  const batchSize = 50;

  for (let index = 0; index < teams.length; index += batchSize) {
    const batch = teams.slice(index, index + batchSize);
    const rows = batch.map((team) => {
      const searchTerms = buildSearchTerms(team);
      const patch: Record<string, unknown> = {
        id: team.id,
        slug: slugify(team.name),
        name: team.name,
        short_name: team.short_name,
        country: entry.country,
        country_code: entry.countryCode,
        region: entry.region,
        league_name: leagueName,
        competition_ids: [competitionId],
        aliases: searchTerms,
        search_terms: searchTerms,
        is_active: true,
        is_featured: false,
        is_popular_pick: false,
        logo_url: team.crest_url,
        updated_at: new Date().toISOString(),
      };

      if (team.crest_url != null) {
        patch["crest_url"] = team.crest_url;
      }

      return patch;
    });

    const { error, count } = await client
      .from("teams")
      .upsert(rows, {
        onConflict: "id",
        ignoreDuplicates: false,
        count: "exact",
      });

    if (error) {
      console.error(
        "[gemini-team-discovery] Team upsert batch failed:",
        error.message,
      );
      continue;
    }

    upserted += count ?? batch.length;
  }

  return upserted;
}

export async function syncOnboardingPopularTeams(): Promise<number> {
  const client = getAdminClient();
  const seededIds = ONBOARDING_POPULAR_TEAM_SEED.map((seed) => seed.teamId);

  await client
    .from("teams")
    .update({ is_popular_pick: false, popular_pick_rank: null })
    .eq("is_active", true);

  for (const seed of ONBOARDING_POPULAR_TEAM_SEED) {
    const { error } = await client
      .from("teams")
      .update({ is_popular_pick: true, popular_pick_rank: seed.rank })
      .eq("id", seed.teamId);
    if (error) {
      console.error(
        "[gemini-team-discovery] Failed to mark popular team:",
        seed.teamId,
        error.message,
      );
    }
  }

  const { data: teamRows, error: selectError } = await client
    .from("teams")
    .select(
      "id, name, short_name, country, country_code, league_name, logo_url, crest_url, aliases, search_terms",
    )
    .in("id", seededIds)
    .eq("is_active", true);

  if (selectError) {
    console.error(
      "[gemini-team-discovery] Popular team seed fetch failed:",
      selectError.message,
    );
    return 0;
  }

  const rowsById = new Map(
    (teamRows ?? []).map((
      row,
    ) => [String(row.id), row as Record<string, unknown>]),
  );
  const popularRows = ONBOARDING_POPULAR_TEAM_SEED
    .map((seed) => {
      const teamRow = rowsById.get(seed.teamId);
      if (teamRow == null) {
        console.warn(
          "[gemini-team-discovery] Popular team missing from teams table:",
          seed.teamId,
        );
        return null;
      }
      return buildPopularTeamRow(teamRow, seed);
    })
    .filter((row): row is Record<string, unknown> => row != null);

  try {
    await client
      .from("onboarding_popular_teams")
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .not("id", "is", null);
  } catch (error) {
    console.error(
      "[gemini-team-discovery] Failed to reset onboarding popular teams:",
      error instanceof Error ? error.message : String(error),
    );
  }

  if (popularRows.length == 0) {
    return 0;
  }

  const { error: upsertError, count } = await client
    .from("onboarding_popular_teams")
    .upsert(popularRows, {
      onConflict: "id",
      ignoreDuplicates: false,
      count: "exact",
    });

  if (upsertError) {
    console.error(
      "[gemini-team-discovery] Popular team upsert failed:",
      upsertError.message,
    );
    return 0;
  }

  return count ?? popularRows.length;
}

export async function getActiveTeamCount(): Promise<number> {
  const client = getAdminClient();
  const { count, error } = await client
    .from("teams")
    .select("*", { count: "exact", head: true })
    .eq("is_active", true);

  if (error) {
    console.error("[gemini-team-discovery] Team count failed:", error.message);
    return 0;
  }

  return count ?? 0;
}

export async function exportAllTeams(): Promise<Record<string, unknown>[]> {
  const client = getAdminClient();
  const { data, error } = await client
    .from("teams")
    .select(TEAM_EXPORT_SELECT_COLUMNS)
    .eq("is_active", true)
    .order("country")
    .order("name");

  if (error) {
    console.error("[gemini-team-discovery] Team export failed:", error.message);
    return [];
  }

  return (data ?? []).map((row) => mapExportRow(row));
}

export async function exportPopularTeams(): Promise<Record<string, unknown>[]> {
  const client = getAdminClient();
  const { data, error } = await client
    .from("onboarding_popular_teams")
    .select(TEAM_EXPORT_SELECT_COLUMNS)
    .eq("is_active", true)
    .order("popular_pick_rank");

  if (error) {
    console.error(
      "[gemini-team-discovery] Popular team export failed:",
      error.message,
    );
    return [];
  }

  return (data ?? []).map((row) => mapExportRow(row));
}

export function exportCatalog() {
  return LEAGUE_CATALOG;
}
