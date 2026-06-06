export const PUBLIC_API_BASE =
  "https://prod-cdn-public-api.livescore.com/v1/api/app";
export const LIVESCORE_WEB_BASE = "https://www.livescore.com";
export const TEAM_IMAGE_BASE =
  "https://storage.livescore.com/images/team/high/";
export const COMPETITION_IMAGE_BASE =
  "https://storage.livescore.com/images/competition/high/";

export interface LiveScoreResourceConfig {
  resourceId: string;
  providerCompetitionId: string;
  competitionSlug: string;
  categorySlug: string;
  competitionId: string;
  seasonId: string;
  timezoneName: string;
  locale: string;
  limit: number;
  apiUrl?: string | null;
}

export interface LiveScoreFetchOptions {
  includeDetails: boolean;
  includeScoreboard: boolean;
  delayMs: number;
}

export interface LiveScoreFixtureRows {
  rows: Record<string, unknown>[];
  metadata: Record<string, unknown>;
}

function slugify(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(
    /^-+|-+$/g,
    "",
  );
}

function firstTeam(event: Record<string, unknown>, key: "T1" | "T2") {
  const teams = event[key];
  if (!Array.isArray(teams) || !teams.length) return {};
  const first = teams[0];
  return typeof first === "object" && first !== null
    ? first as Record<string, unknown>
    : {};
}

function readInt(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && /^-?\d+$/.test(value.trim())) {
    return Number(value.trim());
  }
  return null;
}

function readFirstInt(source: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = readInt(source[key]);
    if (value !== null) return value;
  }
  return null;
}

function imageUrl(path: unknown, baseUrl: string) {
  const raw = String(path ?? "").trim();
  if (!raw) return null;
  if (raw.startsWith("http://") || raw.startsWith("https://")) return raw;
  return new URL(raw, baseUrl).toString();
}

export function normalizeLiveScoreStatus(status: unknown): string {
  const raw = String(status ?? "").trim().toLowerCase();
  if (["live", "inplay", "ip", "1h", "2h", "ht"].includes(raw)) {
    return "live";
  }
  if (["ft", "aet", "ap", "finished", "final"].includes(raw)) {
    return "finished";
  }
  if (["postponed", "ppd"].includes(raw)) return "postponed";
  if (["cancelled", "canceled", "can"].includes(raw)) return "cancelled";
  return "scheduled";
}

function timeZoneOffsetMs(date: Date, timezoneName: string): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: timezoneName,
    hour12: false,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).formatToParts(date);

  const values: Record<string, number> = {};
  for (const part of parts) {
    if (part.type !== "literal") {
      values[part.type] = Number(part.value);
    }
  }

  return Date.UTC(
    values.year,
    values.month - 1,
    values.day,
    values.hour,
    values.minute,
    values.second,
  ) - date.getTime();
}

export function parseLiveScoreDateTime(
  value: unknown,
  timezoneName = "UTC",
): string {
  const raw = String(value ?? "").trim();
  if (!/^\d{14}$/.test(raw)) {
    throw new Error(`Invalid LiveScore Esd datetime: ${raw || "empty"}`);
  }

  const year = Number(raw.slice(0, 4));
  const month = Number(raw.slice(4, 6)) - 1;
  const day = Number(raw.slice(6, 8));
  const hour = Number(raw.slice(8, 10));
  const minute = Number(raw.slice(10, 12));
  const second = Number(raw.slice(12, 14));
  const utcCandidate = new Date(
    Date.UTC(year, month, day, hour, minute, second),
  );
  if (timezoneName === "UTC" || timezoneName === "Etc/UTC") {
    return utcCandidate.toISOString();
  }

  const offset = timeZoneOffsetMs(utcCandidate, timezoneName);
  let utcDate = new Date(utcCandidate.getTime() - offset);
  const correctedOffset = timeZoneOffsetMs(utcDate, timezoneName);
  if (correctedOffset !== offset) {
    utcDate = new Date(utcCandidate.getTime() - correctedOffset);
  }

  return utcDate.toISOString();
}

export function parseLiveScoreLocalDateTime(value: unknown): {
  localDate: string;
  localTime: string;
} {
  const raw = String(value ?? "").trim();
  if (!/^\d{14}$/.test(raw)) {
    throw new Error(`Invalid LiveScore Esd datetime: ${raw || "empty"}`);
  }

  return {
    localDate: `${raw.slice(0, 4)}-${raw.slice(4, 6)}-${raw.slice(6, 8)}`,
    localTime: `${raw.slice(8, 10)}:${raw.slice(10, 12)}:${raw.slice(12, 14)}`,
  };
}

export function buildFixturesApiUrl(resource: LiveScoreResourceConfig) {
  if (resource.apiUrl) return resource.apiUrl;
  const timezonePath = encodeURIComponent(resource.timezoneName);
  const query = new URLSearchParams({
    locale: resource.locale,
    limit: String(resource.limit),
  });
  return `${PUBLIC_API_BASE}/competition/${resource.providerCompetitionId}/fixtures-w/${timezonePath}?${query}`;
}

export function buildInfoApiUrl(eventId: string, locale: string) {
  const query = new URLSearchParams({ locale });
  return `${PUBLIC_API_BASE}/info/soccer/${eventId}?${query}`;
}

export function buildScoreboardApiUrl(eventId: string, locale: string) {
  const query = new URLSearchParams({ locale });
  return `${PUBLIC_API_BASE}/scoreboard/soccer/${eventId}?${query}`;
}

function buildMatchUrl(
  resource: LiveScoreResourceConfig,
  homeName: string,
  awayName: string,
  eventId: string,
) {
  return `${LIVESCORE_WEB_BASE}/en/football/${resource.categorySlug}/${resource.competitionSlug}/${
    slugify(homeName)
  }-vs-${slugify(awayName)}/${eventId}/`;
}

async function sleep(ms: number) {
  if (ms > 0) await new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchJson(url: string, userAgent: string) {
  const response = await fetch(url, {
    headers: {
      "Accept": "application/json,text/plain,*/*",
      "Origin": LIVESCORE_WEB_BASE,
      "Referer": `${LIVESCORE_WEB_BASE}/`,
      "User-Agent": userAgent,
    },
  });
  if (!response.ok) {
    throw new Error(`LiveScore fetch failed ${response.status}: ${url}`);
  }
  return await response.json() as Record<string, unknown>;
}

export async function fetchLiveScoreFixtureRows(
  resource: LiveScoreResourceConfig,
  options: LiveScoreFetchOptions,
  userAgent: string,
): Promise<LiveScoreFixtureRows> {
  const apiUrl = buildFixturesApiUrl(resource);
  const payload = await fetchJson(apiUrl, userAgent);
  const stages = Array.isArray(payload.Stages) ? payload.Stages : [];
  const rows: Record<string, unknown>[] = [];
  const seen = new Set<string>();

  for (const stageValue of stages) {
    if (typeof stageValue !== "object" || stageValue === null) continue;
    const stage = stageValue as Record<string, unknown>;
    const events = Array.isArray(stage.Events) ? stage.Events : [];
    for (const eventValue of events) {
      if (typeof eventValue !== "object" || eventValue === null) continue;
      const event = eventValue as Record<string, unknown>;
      const eventId = String(event.Eid ?? "").trim();
      if (!eventId || seen.has(eventId)) continue;
      seen.add(eventId);

      const home = firstTeam(event, "T1");
      const away = firstTeam(event, "T2");
      const homeName = String(home.Nm ?? "").trim();
      const awayName = String(away.Nm ?? "").trim();
      const startsAt = parseLiveScoreDateTime(
        event.Esd,
        resource.timezoneName,
      );
      const { localDate, localTime } = parseLiveScoreLocalDateTime(event.Esd);
      const sourceUrl = buildMatchUrl(resource, homeName, awayName, eventId);
      let details: Record<string, unknown> = {};
      let scoreboard: Record<string, unknown> = {};

      if (options.includeDetails) {
        await sleep(options.delayMs);
        details = await fetchJson(
          buildInfoApiUrl(eventId, resource.locale),
          userAgent,
        );
      }
      if (options.includeScoreboard) {
        await sleep(options.delayMs);
        scoreboard = await fetchJson(
          buildScoreboardApiUrl(eventId, resource.locale),
          userAgent,
        );
      }

      const scoreboardVenue = typeof scoreboard.Venue === "object" &&
          scoreboard.Venue !== null
        ? scoreboard.Venue as Record<string, unknown>
        : {};
      const homeScore = readFirstInt(event, ["Tr1", "Tr1OR", "Tr1C"]);
      const awayScore = readFirstInt(event, ["Tr2", "Tr2OR", "Tr2C"]);
      const eventStatus = String(event.Eps ?? "").trim();
      const matchStatus = normalizeLiveScoreStatus(eventStatus);
      const liveMinute = readFirstInt(event, ["Emin", "Epr"]);

      rows.push({
        source_match_id: eventId,
        provider_match_id: eventId,
        competition_id: resource.competitionId,
        season_id: resource.seasonId,
        competition_name: payload.CompN ?? stage.Cnm ?? stage.CompN,
        competition_provider_id: payload.CompId ?? stage.CompId,
        competition_logo_url: imageUrl(
          payload.badgeUrl ?? stage.badgeUrl,
          COMPETITION_IMAGE_BASE,
        ),
        stage: stage.Snm ?? event.stageName,
        matchday_or_round: event.ErnInf,
        home_team_source_id: String(home.ID ?? "").trim(),
        away_team_source_id: String(away.ID ?? "").trim(),
        home_team_name: homeName,
        away_team_name: awayName,
        home_team_abbr: home.Abr,
        away_team_abbr: away.Abr,
        home_team_image_path: home.Img,
        away_team_image_path: away.Img,
        home_team_logo_url: imageUrl(home.Img, TEAM_IMAGE_BASE),
        away_team_logo_url: imageUrl(away.Img, TEAM_IMAGE_BASE),
        home_team_type: "national",
        away_team_type: "national",
        local_date: localDate,
        local_time: localTime,
        timezone_name: resource.timezoneName,
        starts_at: startsAt,
        venue: details.Vnm ?? scoreboardVenue.Vnm ?? null,
        venue_city: details.Vcy ?? details.VCnm ?? scoreboardVenue.Vcy ?? null,
        source_url: sourceUrl,
        match_status: matchStatus,
        event_status: eventStatus,
        home_score: homeScore,
        away_score: awayScore,
        live_minute: matchStatus === "live" ? liveMinute : null,
        live_phase: eventStatus || matchStatus,
        is_neutral: Boolean(details.Vneut ?? scoreboardVenue.Vneut ?? false),
        confidence: "official",
        source_payload: { stage, event, details, scoreboard },
      });
    }
  }

  return {
    rows,
    metadata: {
      api_url: apiUrl,
      provider_competition_id: resource.providerCompetitionId,
      competition_name: payload.CompN,
      stages_seen: stages.length,
      rows_seen: rows.length,
      timezone_name: resource.timezoneName,
      include_details: options.includeDetails,
      include_scoreboard: options.includeScoreboard,
    },
  };
}
