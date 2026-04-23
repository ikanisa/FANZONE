import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.49.4";

import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("EDGE_SERVICE_ROLE_KEY")
  ?.trim() || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() || "";
const CRON_SECRET = Deno.env.get("CRON_SECRET")?.trim() || "";

type DatasetType =
  | "competitions"
  | "seasons"
  | "teams"
  | "team_aliases"
  | "matches"
  | "standings";

type CsvRecord = Record<string, string>;

interface ImportPayload {
  datasetType: DatasetType;
  csv?: string;
  rows?: Record<string, unknown>[];
  generatePredictions?: boolean;
}

interface ImportErrorRow {
  row: number;
  reason: string;
}

type AnySupabase = SupabaseClient<any, "public", any>;

function slugify(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(
    /^-+|-+$/g,
    "",
  );
}

function seasonStartYear(label: string): number {
  const match = label.trim().match(/(\d{4})(?:\D+(\d{2,4}))?/);
  if (!match) return new Date().getUTCFullYear();
  return Number(match[1]);
}

function seasonEndYear(label: string): number {
  const match = label.trim().match(/(\d{4})(?:\D+(\d{2,4}))?/);
  if (!match) return new Date().getUTCFullYear();
  const start = Number(match[1]);
  const endPart = match[2];
  if (!endPart) return start + 1;
  if (endPart.length === 2) {
    return Math.floor(start / 100) * 100 + Number(endPart);
  }
  return Number(endPart);
}

function toBoolean(value: unknown, fallback = false): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value !== "string") return fallback;

  const normalized = value.trim().toLowerCase();
  if (["true", "1", "yes", "y"].includes(normalized)) return true;
  if (["false", "0", "no", "n"].includes(normalized)) return false;
  return fallback;
}

function toInt(value: unknown, fallback = 0): number {
  if (typeof value === "number") return Math.trunc(value);
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.trunc(parsed);
  }
  return fallback;
}

function readString(
  record: Record<string, unknown>,
  keys: string[],
): string | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim() !== "") {
      return value.trim();
    }
  }
  return null;
}

function parseCsvRecords(csv: string): CsvRecord[] {
  const rows: string[][] = [];
  let currentField = "";
  let currentRow: string[] = [];
  let inQuotes = false;

  for (let index = 0; index < csv.length; index += 1) {
    const char = csv[index];
    const next = csv[index + 1];

    if (char === '"') {
      if (inQuotes && next === '"') {
        currentField += '"';
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (char === "," && !inQuotes) {
      currentRow.push(currentField.trim());
      currentField = "";
      continue;
    }

    if ((char === "\n" || char === "\r") && !inQuotes) {
      if (char === "\r" && next === "\n") {
        index += 1;
      }
      currentRow.push(currentField.trim());
      currentField = "";
      if (currentRow.some((value) => value.length > 0)) {
        rows.push(currentRow);
      }
      currentRow = [];
      continue;
    }

    currentField += char;
  }

  if (currentField.length > 0 || currentRow.length > 0) {
    currentRow.push(currentField.trim());
    if (currentRow.some((value) => value.length > 0)) {
      rows.push(currentRow);
    }
  }

  if (!rows.length) return [];

  const headers = rows[0].map((header) => header.trim());
  return rows.slice(1).map((values) => {
    const record: CsvRecord = {};
    headers.forEach((header, index) => {
      record[header] = values[index]?.trim() ?? "";
    });
    return record;
  });
}

function normalizeRows(payload: ImportPayload): Record<string, unknown>[] {
  if (Array.isArray(payload.rows) && payload.rows.length > 0) {
    return payload.rows;
  }

  if (typeof payload.csv === "string" && payload.csv.trim() !== "") {
    return parseCsvRecords(payload.csv);
  }

  return [];
}

function chunk<T>(values: T[], size: number): T[][] {
  const output: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    output.push(values.slice(index, index + size));
  }
  return output;
}

function uniqueStrings(values: Array<string | null | undefined>): string[] {
  return [
    ...new Set(
      values.map((value) => value?.trim() ?? "").filter((value) =>
        value !== ""
      ),
    ),
  ];
}

async function runRpc(
  supabase: AnySupabase,
  fnName: string,
  params: Record<string, unknown>,
) {
  const { error } = await supabase.rpc(fnName, params);
  if (error) {
    throw error;
  }
}

async function resolveTeamId(
  supabase: AnySupabase,
  cache: Map<string, string>,
  rawValue: string | null,
): Promise<string | null> {
  if (!rawValue) return null;
  const normalized = rawValue.trim();
  if (normalized === "") return null;

  const cacheKey = normalized.toLowerCase();
  if (cache.has(cacheKey)) {
    return cache.get(cacheKey)!;
  }

  const directTeam = await supabase
    .from("teams")
    .select("id")
    .eq("id", normalized)
    .maybeSingle();

  const directTeamId = typeof directTeam.data?.id === "string"
    ? directTeam.data.id
    : null;
  if (directTeamId) {
    cache.set(cacheKey, directTeamId);
    return directTeamId;
  }

  const alias = await supabase
    .from("team_aliases")
    .select("team_id")
    .ilike("alias_name", normalized)
    .maybeSingle();

  const aliasTeamId = typeof alias.data?.team_id === "string"
    ? alias.data.team_id
    : null;
  if (aliasTeamId) {
    cache.set(cacheKey, aliasTeamId);
    return aliasTeamId;
  }

  const teamByName = await supabase
    .from("teams")
    .select("id")
    .ilike("name", normalized)
    .maybeSingle();

  const teamByNameId = typeof teamByName.data?.id === "string"
    ? teamByName.data.id
    : null;
  if (teamByNameId) {
    cache.set(cacheKey, teamByNameId);
    return teamByNameId;
  }

  return null;
}

async function ensureSeasonId(
  supabase: AnySupabase,
  competitionId: string,
  explicitSeasonId: string | null,
  seasonLabel: string | null,
): Promise<string> {
  if (explicitSeasonId) return explicitSeasonId;

  const label = seasonLabel?.trim() || "Unknown";
  const seasonId = `${competitionId}:${slugify(label) || "unknown"}`;

  await supabase.from("seasons").upsert(
    {
      id: seasonId,
      competition_id: competitionId,
      season_label: label,
      start_year: seasonStartYear(label),
      end_year: seasonEndYear(label),
      is_current: false,
    },
    { onConflict: "id" },
  );

  return seasonId;
}

async function upsertInBatches(
  supabase: AnySupabase,
  table: string,
  rows: Record<string, unknown>[],
  onConflict: string,
) {
  for (const batch of chunk(rows, 200)) {
    const { error } = await supabase.from(table).upsert(batch, { onConflict });
    if (error) {
      throw error;
    }
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: buildCorsHeaders("content-type, x-cron-secret"),
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (
    !isAuthorizedEdgeRequest({
      req,
      sharedSecrets: [{ header: "x-cron-secret", value: CRON_SECRET }],
    })
  ) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const payload = await req.json() as ImportPayload;
    const datasetType = payload.datasetType;

    if (!datasetType) {
      return Response.json(
        { error: "datasetType is required" },
        { status: 400, headers: buildCorsHeaders("content-type") },
      );
    }

    const rows = normalizeRows(payload);
    if (!rows.length) {
      return Response.json(
        { error: "Provide csv or rows with at least one record" },
        { status: 400, headers: buildCorsHeaders("content-type") },
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const errors: ImportErrorRow[] = [];
    const teamCache = new Map<string, string>();
    const upserts: Record<string, unknown>[] = [];

    if (datasetType === "competitions") {
      rows.forEach((row, index) => {
        const id = readString(row, ["id"]);
        const name = readString(row, ["name"]);
        if (!id || !name) {
          errors.push({ row: index + 2, reason: "id and name are required" });
          return;
        }

        upserts.push({
          id,
          name,
          country_or_region:
            readString(row, ["country_or_region", "country", "region"]) ??
              "Global",
          competition_type: readString(row, ["competition_type"]) ?? "league",
          is_international: toBoolean(row.is_international, false),
          is_active: toBoolean(row.is_active, true),
          short_name: readString(row, ["short_name"]),
          country: readString(row, ["country"]),
        });
      });

      await upsertInBatches(supabase, "competitions", upserts, "id");
    }

    if (datasetType === "seasons") {
      rows.forEach((row, index) => {
        const competitionId = readString(row, ["competition_id"]);
        const seasonLabel = readString(row, ["season_label"]);
        if (!competitionId || !seasonLabel) {
          errors.push({
            row: index + 2,
            reason: "competition_id and season_label are required",
          });
          return;
        }

        const id = readString(row, ["id"]) ??
          `${competitionId}:${slugify(seasonLabel) || "unknown"}`;

        upserts.push({
          id,
          competition_id: competitionId,
          season_label: seasonLabel,
          start_year: toInt(row.start_year, seasonStartYear(seasonLabel)),
          end_year: toInt(row.end_year, seasonEndYear(seasonLabel)),
          is_current: toBoolean(row.is_current, false),
        });
      });

      await upsertInBatches(supabase, "seasons", upserts, "id");
    }

    if (datasetType === "teams") {
      rows.forEach((row, index) => {
        const id = readString(row, ["id"]);
        const name = readString(row, ["name"]);
        if (!id || !name) {
          errors.push({ row: index + 2, reason: "id and name are required" });
          return;
        }

        upserts.push({
          id,
          name,
          country: readString(row, ["country"]),
          team_type: readString(row, ["team_type"]) ?? "club",
          short_name: readString(row, ["short_name"]),
          crest_url: readString(row, ["crest_url", "logo_url"]),
          logo_url: readString(row, ["logo_url", "crest_url"]),
          is_active: toBoolean(row.is_active, true),
          updated_at: new Date().toISOString(),
        });
      });

      await upsertInBatches(supabase, "teams", upserts, "id");
    }

    if (datasetType === "team_aliases") {
      for (let index = 0; index < rows.length; index += 1) {
        const row = rows[index];
        const teamId = readString(row, ["team_id"]);
        const aliasName = readString(row, ["alias_name"]);
        if (!teamId || !aliasName) {
          errors.push({
            row: index + 2,
            reason: "team_id and alias_name are required",
          });
          continue;
        }

        const existingAlias = await supabase
          .from("team_aliases")
          .select("alias_name")
          .eq("team_id", teamId)
          .ilike("alias_name", aliasName)
          .maybeSingle();

        const canonicalAliasName =
          typeof existingAlias.data?.alias_name === "string"
            ? existingAlias.data.alias_name
            : aliasName;

        upserts.push({
          team_id: teamId,
          alias_name: canonicalAliasName,
          source_name: readString(row, ["source_name"]) ?? "csv_import",
        });
      }

      await upsertInBatches(
        supabase,
        "team_aliases",
        upserts,
        "team_id,alias_name",
      );
    }

    if (datasetType === "matches") {
      for (let index = 0; index < rows.length; index += 1) {
        const row = rows[index];
        const id = readString(row, ["id"]);
        const competitionId = readString(row, ["competition_id"]);
        const matchDate = readString(row, ["match_date", "date"]);
        const homeTeamId = await resolveTeamId(
          supabase,
          teamCache,
          readString(row, ["home_team_id", "home_team"]),
        );
        const awayTeamId = await resolveTeamId(
          supabase,
          teamCache,
          readString(row, ["away_team_id", "away_team"]),
        );

        if (!id || !competitionId || !matchDate || !homeTeamId || !awayTeamId) {
          errors.push({
            row: index + 2,
            reason:
              "id, competition_id, match_date, home team, and away team are required",
          });
          continue;
        }

        const seasonId = await ensureSeasonId(
          supabase,
          competitionId,
          readString(row, ["season_id"]),
          readString(row, ["season_label"]),
        );

        upserts.push({
          id,
          competition_id: competitionId,
          season_id: seasonId,
          stage: readString(row, ["stage"]),
          matchday_or_round: readString(row, ["matchday_or_round", "round"]),
          match_date: matchDate,
          home_team_id: homeTeamId,
          away_team_id: awayTeamId,
          home_goals: row.home_goals ?? row.ft_home ?? null,
          away_goals: row.away_goals ?? row.ft_away ?? null,
          result_code: readString(row, ["result_code"]),
          match_status: readString(row, ["match_status", "status"]) ??
            "scheduled",
          is_neutral: toBoolean(row.is_neutral, false),
          source_name: readString(row, ["source_name", "data_source"]) ??
            "csv_import",
          source_url: readString(row, ["source_url"]),
          notes: readString(row, ["notes"]),
        });
      }

      await upsertInBatches(supabase, "matches", upserts, "id");
    }

    if (datasetType === "standings") {
      for (let index = 0; index < rows.length; index += 1) {
        const row = rows[index];
        const competitionId = readString(row, ["competition_id"]);
        const teamId = await resolveTeamId(
          supabase,
          teamCache,
          readString(row, ["team_id", "team_name"]),
        );
        if (!competitionId || !teamId) {
          errors.push({
            row: index + 2,
            reason: "competition_id and team identifier are required",
          });
          continue;
        }

        const seasonId = await ensureSeasonId(
          supabase,
          competitionId,
          readString(row, ["season_id"]),
          readString(row, ["season_label", "season"]),
        );

        upserts.push({
          competition_id: competitionId,
          season_id: seasonId,
          snapshot_type: readString(row, ["snapshot_type"]) ?? "current",
          snapshot_date: readString(row, ["snapshot_date"]) ??
            new Date().toISOString().slice(0, 10),
          team_id: teamId,
          position: toInt(row.position, 999),
          played: toInt(row.played, 0),
          wins: toInt(row.wins ?? row.won, 0),
          draws: toInt(row.draws ?? row.drawn, 0),
          losses: toInt(row.losses ?? row.lost, 0),
          goals_for: toInt(row.goals_for, 0),
          goals_against: toInt(row.goals_against, 0),
          goal_difference: toInt(
            row.goal_difference,
            toInt(row.goals_for, 0) - toInt(row.goals_against, 0),
          ),
          points: toInt(row.points, 0),
          source_name: readString(row, ["source_name"]) ?? "csv_import",
          source_url: readString(row, ["source_url"]),
        });
      }

      await upsertInBatches(
        supabase,
        "standings",
        upserts,
        "competition_id,season_id,snapshot_type,snapshot_date,team_id",
      );
    }

    const importedCompetitionIds = uniqueStrings(
      upserts.map((row) => {
        if (typeof row.competition_id === "string") {
          return row.competition_id;
        }
        if (datasetType === "competitions" && typeof row.id === "string") {
          return row.id;
        }
        return null;
      }),
    );

    const importedTeamIds = uniqueStrings([
      ...upserts.map((row) =>
        datasetType === "teams" && typeof row.id === "string" ? row.id : null
      ),
      ...upserts.map((row) =>
        datasetType === "team_aliases" && typeof row.team_id === "string"
          ? row.team_id
          : null
      ),
      ...upserts.map((row) =>
        typeof row.home_team_id === "string" ? row.home_team_id : null
      ),
      ...upserts.map((row) =>
        typeof row.away_team_id === "string" ? row.away_team_id : null
      ),
      ...upserts.map((row) =>
        datasetType === "standings" && typeof row.team_id === "string"
          ? row.team_id
          : null
      ),
    ]);

    const importedMatchIds = uniqueStrings(
      upserts.map((row) =>
        datasetType === "matches" && typeof row.id === "string" ? row.id : null
      ),
    );

    if (datasetType === "competitions" || datasetType === "seasons") {
      await runRpc(supabase, "refresh_competition_derived_fields", {
        p_competition_ids: importedCompetitionIds.length
          ? importedCompetitionIds
          : null,
      });
    }

    if (datasetType === "teams" || datasetType === "team_aliases") {
      await runRpc(supabase, "refresh_team_derived_fields", {
        p_team_ids: importedTeamIds.length ? importedTeamIds : null,
      });
    }

    if (datasetType === "matches") {
      await runRpc(supabase, "refresh_competition_derived_fields", {
        p_competition_ids: importedCompetitionIds.length
          ? importedCompetitionIds
          : null,
      });
      await runRpc(supabase, "refresh_team_derived_fields", {
        p_team_ids: importedTeamIds.length ? importedTeamIds : null,
      });
      await runRpc(supabase, "generate_team_form_features_for_matches", {
        p_match_ids: importedMatchIds,
        p_limit: Math.min(importedMatchIds.length || 250, 500),
      });
    }

    if (datasetType === "standings") {
      await runRpc(supabase, "refresh_competition_derived_fields", {
        p_competition_ids: importedCompetitionIds.length
          ? importedCompetitionIds
          : null,
      });
    }

    if (
      (datasetType === "matches" || datasetType === "standings") &&
      payload.generatePredictions !== false
    ) {
      if (datasetType === "matches" && importedMatchIds.length) {
        await runRpc(supabase, "generate_predictions_for_matches", {
          p_match_ids: importedMatchIds,
          p_limit: Math.min(importedMatchIds.length || 25, 250),
          p_model_version: "simple_form_v1",
          p_include_finished: false,
        });
      } else {
        await runRpc(supabase, "generate_predictions_for_upcoming_matches", {
          p_limit: Math.min(upserts.length || 25, 100),
        });
      }
    }

    return Response.json(
      {
        datasetType,
        received_rows: rows.length,
        imported_rows: upserts.length,
        rejected_rows: errors.length,
        errors,
      },
      { headers: buildCorsHeaders("content-type") },
    );
  } catch (error) {
    return Response.json(
      { error: getErrorMessage(error) },
      { status: 500, headers: buildCorsHeaders("content-type") },
    );
  }
});
