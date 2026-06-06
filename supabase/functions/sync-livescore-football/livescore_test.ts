import {
  buildFixturesApiUrl,
  fetchLiveScoreFixtureRows,
  type LiveScoreResourceConfig,
  normalizeLiveScoreStatus,
  parseLiveScoreDateTime,
  parseLiveScoreLocalDateTime,
} from "./livescore.ts";

const resource: LiveScoreResourceConfig = {
  resourceId: "livescore_world_cup_2026",
  providerCompetitionId: "734",
  competitionSlug: "world-cup-2026",
  categorySlug: "international",
  competitionId: "fifa_world_cup",
  seasonId: "fifa_world_cup_2026",
  timezoneName: "UTC",
  locale: "en",
  limit: 200,
};

Deno.test("normalizeLiveScoreStatus maps LiveScore football statuses", () => {
  if (normalizeLiveScoreStatus("NS") !== "scheduled") {
    throw new Error("Expected NS to map to scheduled");
  }
  if (normalizeLiveScoreStatus("1H") !== "live") {
    throw new Error("Expected 1H to map to live");
  }
  if (normalizeLiveScoreStatus("FT") !== "finished") {
    throw new Error("Expected FT to map to finished");
  }
});

Deno.test("buildFixturesApiUrl uses the LiveScore public football endpoint", () => {
  const url = buildFixturesApiUrl(resource);
  if (
    url !==
      "https://prod-cdn-public-api.livescore.com/v1/api/app/competition/734/fixtures-w/UTC?locale=en&limit=200"
  ) {
    throw new Error(`Unexpected LiveScore fixture URL: ${url}`);
  }
});

Deno.test("parseLiveScoreDateTime converts Esd to UTC ISO", () => {
  const iso = parseLiveScoreDateTime(20260611190000);
  if (iso !== "2026-06-11T19:00:00.000Z") {
    throw new Error(`Unexpected parsed ISO value: ${iso}`);
  }
});

Deno.test("parseLiveScoreDateTime respects configured resource timezone", () => {
  const iso = parseLiveScoreDateTime(20260611210000, "Africa/Kigali");
  if (iso !== "2026-06-11T19:00:00.000Z") {
    throw new Error(`Unexpected Kigali parsed ISO value: ${iso}`);
  }
});

Deno.test("parseLiveScoreLocalDateTime preserves provider local fields", () => {
  const local = parseLiveScoreLocalDateTime(20260611210000);
  if (local.localDate !== "2026-06-11") {
    throw new Error(`Unexpected local date: ${local.localDate}`);
  }
  if (local.localTime !== "21:00:00") {
    throw new Error(`Unexpected local time: ${local.localTime}`);
  }
});

Deno.test("fetchLiveScoreFixtureRows maps fixture status and live score fields", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (async () =>
    new Response(
      JSON.stringify({
        CompN: "World Cup 2026",
        CompId: "734",
        Stages: [{
          Snm: "Group A",
          Events: [{
            Eid: "1417909",
            Esd: 20260611190000,
            Eps: "FT",
            ErnInf: "1",
            Tr1: "2",
            Tr2: "1",
            T1: [{
              ID: "9025",
              Nm: "Mexico",
              Abr: "MEX",
              Img: "enet/6710.png",
            }],
            T2: [{
              ID: "9287",
              Nm: "South Africa",
              Abr: "RSA",
              Img: "teambadge/south-africa-2024.png",
            }],
          }],
        }],
      }),
      { status: 200, headers: { "content-type": "application/json" } },
    )) as typeof fetch;

  try {
    const { rows } = await fetchLiveScoreFixtureRows(
      resource,
      { includeDetails: false, includeScoreboard: false, delayMs: 0 },
      "test-agent",
    );
    const row = rows[0];
    if (row.match_status !== "finished") {
      throw new Error(`Expected finished status, got ${row.match_status}`);
    }
    if (row.home_score !== 2 || row.away_score !== 1) {
      throw new Error("Expected LiveScore home/away scores to be mapped");
    }
    if (
      row.source_url !==
        "https://www.livescore.com/en/football/international/world-cup-2026/mexico-vs-south-africa/1417909/"
    ) {
      throw new Error(`Unexpected source URL: ${row.source_url}`);
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("fetchLiveScoreFixtureRows maps source local time through resource timezone", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (async () =>
    new Response(
      JSON.stringify({
        CompN: "World Cup 2026",
        CompId: "734",
        Stages: [{
          Snm: "Group A",
          Events: [{
            Eid: "1417909",
            Esd: 20260611210000,
            Eps: "NS",
            T1: [{ ID: "9025", Nm: "Mexico" }],
            T2: [{ ID: "9287", Nm: "South Africa" }],
          }],
        }],
      }),
      { status: 200, headers: { "content-type": "application/json" } },
    )) as typeof fetch;

  try {
    const { rows } = await fetchLiveScoreFixtureRows(
      { ...resource, timezoneName: "Africa/Kigali" },
      { includeDetails: false, includeScoreboard: false, delayMs: 0 },
      "test-agent",
    );
    const row = rows[0];
    if (row.starts_at !== "2026-06-11T19:00:00.000Z") {
      throw new Error(`Expected UTC starts_at, got ${row.starts_at}`);
    }
    if (row.timezone_name !== "Africa/Kigali") {
      throw new Error(`Expected source timezone to be preserved`);
    }
    if (row.local_date !== "2026-06-11" || row.local_time !== "21:00:00") {
      throw new Error(
        `Expected source local date/time to be preserved, got ${row.local_date} ${row.local_time}`,
      );
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});
