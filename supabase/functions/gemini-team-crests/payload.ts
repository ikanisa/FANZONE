import {
  DEFAULT_DELAY_MS,
  DEFAULT_REFRESH_AFTER_HOURS,
  MAX_BATCH_SIZE,
} from "./constants.ts";
import { HttpError } from "./http.ts";
import type {
  CrestFetchOptions,
  ParsedRequestPayload,
  TeamCrestInput,
} from "./types.ts";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function asBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function asPositiveInteger(value: unknown, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return fallback;
  }

  const rounded = Math.floor(value);
  return rounded > 0 ? rounded : fallback;
}

function asNonNegativeInteger(value: unknown, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return fallback;
  }

  const rounded = Math.floor(value);
  return rounded >= 0 ? rounded : fallback;
}

function normalizeAliases(value: unknown): string[] {
  if (!Array.isArray(value)) return [];

  const aliases = value
    .map(asTrimmedString)
    .filter((alias): alias is string => alias != null)
    .map((alias) => alias.trim())
    .filter((alias) => alias.length > 1);

  return Array.from(new Set(aliases));
}

function parseTeam(raw: unknown): TeamCrestInput {
  if (!isRecord(raw)) {
    throw new HttpError(400, "Each team payload must be a JSON object.");
  }

  const teamId = asTrimmedString(raw.team_id) ?? asTrimmedString(raw.teamId);
  const teamName = asTrimmedString(raw.team_name) ??
    asTrimmedString(raw.teamName);
  const competition = asTrimmedString(raw.competition);
  const country = asTrimmedString(raw.country);
  const aliases = normalizeAliases(raw.aliases);

  if (!teamId) {
    throw new HttpError(400, "Each team payload requires team_id.");
  }

  if (!teamName) {
    throw new HttpError(400, `Team ${teamId} requires team_name.`);
  }

  return {
    team_id: teamId,
    team_name: teamName,
    competition,
    country,
    aliases,
  };
}

function parseOptions(raw: Record<string, unknown>): CrestFetchOptions {
  return {
    force: asBoolean(raw.force, false),
    apply_to_team: asBoolean(raw.apply_to_team ?? raw.applyToTeam, true),
    dry_run: asBoolean(raw.dry_run ?? raw.dryRun, false),
    refresh_if_older_than_hours: asPositiveInteger(
      raw.refresh_if_older_than_hours ?? raw.refreshIfOlderThanHours,
      DEFAULT_REFRESH_AFTER_HOURS,
    ),
    delay_ms: asNonNegativeInteger(
      raw.delay_ms ?? raw.delayMs,
      DEFAULT_DELAY_MS,
    ),
  };
}

export function parseRequestPayload(body: unknown): ParsedRequestPayload {
  if (!isRecord(body)) {
    throw new HttpError(400, "Request body must be a JSON object.");
  }

  const options = parseOptions(body);
  const topLevelTeam = (
      asTrimmedString(body.team_id) ||
      asTrimmedString(body.teamId) ||
      isRecord(body.team)
    )
    ? parseTeam(isRecord(body.team) ? body.team : body)
    : null;

  const rawTeams = Array.isArray(body.teams) ? body.teams : [];
  const parsedTeams = rawTeams.map(parseTeam);

  const merged = [
    ...(topLevelTeam ? [topLevelTeam] : []),
    ...parsedTeams,
  ];

  if (merged.length === 0) {
    throw new HttpError(
      400,
      "Provide either a top-level team payload or a teams[] array.",
    );
  }

  if (merged.length > MAX_BATCH_SIZE) {
    throw new HttpError(
      400,
      `Batch size exceeds ${MAX_BATCH_SIZE} teams per request.`,
    );
  }

  const deduped = new Map<string, TeamCrestInput>();
  for (const team of merged) {
    if (!deduped.has(team.team_id)) {
      deduped.set(team.team_id, team);
    }
  }

  return {
    teams: Array.from(deduped.values()),
    options,
  };
}
