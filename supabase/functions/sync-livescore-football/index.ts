import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.49.4";

import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";
import {
  cronAuditResponse,
  finishCronJobRun,
  startCronJobRun,
} from "../_shared/cron_audit.ts";
import {
  fetchLiveScoreFixtureRows,
  type LiveScoreResourceConfig,
} from "./livescore.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("EDGE_SERVICE_ROLE_KEY")?.trim() ||
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() || "";
const CRON_SECRET = Deno.env.get("CRON_SECRET")?.trim() || "";
const DEFAULT_USER_AGENT = Deno.env.get("LIVESCORE_SYNC_USER_AGENT")?.trim() ||
  "FANZONE-LiveScore-Sync/1.0";

type AnySupabase = SupabaseClient<any, "public", any>;

interface SyncPayload {
  resource_id?: string;
  resourceId?: string;
  apply?: boolean;
  include_details?: boolean;
  includeDetails?: boolean;
  include_scoreboard?: boolean;
  includeScoreboard?: boolean;
  delay_ms?: number;
  delayMs?: number;
  limit?: number;
}

function readBool(value: unknown, fallback: boolean) {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (["true", "1", "yes"].includes(normalized)) return true;
    if (["false", "0", "no"].includes(normalized)) return false;
  }
  return fallback;
}

function readInt(value: unknown, fallback: number) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && /^-?\d+$/.test(value.trim())) {
    return Number(value.trim());
  }
  return fallback;
}

function readObjectNumber(value: unknown, key: string, fallback: number) {
  if (typeof value !== "object" || value === null) return fallback;
  const candidate = (value as Record<string, unknown>)[key];
  return typeof candidate === "number" ? candidate : fallback;
}

async function rpc(
  supabase: AnySupabase,
  name: string,
  params: Record<string, unknown>,
) {
  const { data, error } = await supabase.rpc(name, params);
  if (error) throw error;
  return data;
}

async function loadResource(
  supabase: AnySupabase,
  resourceId: string,
  limitOverride: number | null,
): Promise<LiveScoreResourceConfig> {
  const { data, error } = await supabase
    .from("football_official_resources")
    .select(
      "id, provider, api_url, resource_url, competition_id, season_id, provider_competition_id, timezone_name, config_json, is_active, fetch_mode",
    )
    .eq("id", resourceId)
    .eq("is_active", true)
    .single();

  if (error || !data) {
    throw new Error(`Active LiveScore resource not found: ${resourceId}`);
  }
  if (
    data.provider !== "livescore" || data.fetch_mode !== "livescore_public_api"
  ) {
    throw new Error(
      `Resource ${resourceId} is not configured for LiveScore sync`,
    );
  }

  const config = typeof data.config_json === "object" && data.config_json
    ? data.config_json as Record<string, unknown>
    : {};

  return {
    resourceId: data.id,
    providerCompetitionId: String(data.provider_competition_id ?? ""),
    competitionSlug: String(config.competition_slug ?? "world-cup-2026"),
    categorySlug: String(config.category_slug ?? "international"),
    competitionId: String(data.competition_id ?? "fifa_world_cup"),
    seasonId: String(data.season_id ?? "fifa_world_cup_2026"),
    timezoneName: String(data.timezone_name ?? "UTC"),
    locale: String(config.locale ?? "en"),
    limit: limitOverride ?? readInt(config.limit, 200),
    apiUrl: typeof data.api_url === "string" && data.api_url.trim()
      ? data.api_url
      : null,
  };
}

export async function handleSyncLiveScoreFootball(req: Request) {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: buildCorsHeaders(
        "authorization, apikey, content-type, x-cron-secret",
        req,
      ),
    });
  }

  if (req.method !== "POST") {
    return Response.json(
      { error: "Method not allowed" },
      { status: 405, headers: buildCorsHeaders("content-type", req) },
    );
  }

  if (
    !isAuthorizedEdgeRequest({
      req,
      serviceRoleKey: SUPABASE_SERVICE_KEY,
      allowServiceRoleBearer: true,
      sharedSecrets: [{ header: "x-cron-secret", value: CRON_SECRET }],
    })
  ) {
    return Response.json(
      { error: "Unauthorized" },
      { status: 401, headers: buildCorsHeaders("content-type", req) },
    );
  }

  const payload = await req.json().catch(() => ({})) as SyncPayload;
  const resourceId = payload.resource_id ?? payload.resourceId ??
    "livescore_world_cup_2026";
  const applyToMatches = readBool(payload.apply, true);
  const includeDetails = readBool(
    payload.include_details ?? payload.includeDetails,
    false,
  );
  const includeScoreboard = readBool(
    payload.include_scoreboard ?? payload.includeScoreboard,
    false,
  );
  const delayMs = Math.max(
    0,
    readInt(payload.delay_ms ?? payload.delayMs, 750),
  );
  const limitOverride = payload.limit === undefined
    ? null
    : Math.max(1, readInt(payload.limit, 200));

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let audit = await startCronJobRun(supabase, "sync-livescore-football", {
    resource_id: resourceId,
    apply: applyToMatches,
    include_details: includeDetails,
    include_scoreboard: includeScoreboard,
    limit: limitOverride,
    edge_function: "sync-livescore-football",
  });

  try {
    const resource = await loadResource(supabase, resourceId, limitOverride);
    const { rows, metadata } = await fetchLiveScoreFixtureRows(
      resource,
      { includeDetails, includeScoreboard, delayMs },
      DEFAULT_USER_AGENT,
    );

    const syncRunId = await rpc(
      supabase,
      "admin_start_football_resource_sync",
      {
        p_resource_id: resource.resourceId,
        p_metadata: metadata,
      },
    );
    const staged = await rpc(supabase, "admin_stage_official_fixture_rows", {
      p_resource_id: resource.resourceId,
      p_rows: rows,
      p_sync_run_id: syncRunId,
      p_timezone: resource.timezoneName,
    });

    let applied: unknown = null;
    let liveState: unknown = null;
    if (applyToMatches) {
      applied = await rpc(
        supabase,
        "admin_apply_official_fixture_staging_batch",
        {
          p_resource_id: resource.resourceId,
          p_limit: Math.min(Math.max(rows.length, 1), 1000),
        },
      );
      liveState = await rpc(
        supabase,
        "admin_apply_official_fixture_live_state",
        {
          p_resource_id: resource.resourceId,
          p_limit: Math.min(Math.max(rows.length, 1), 2000),
        },
      );
    }

    await rpc(supabase, "admin_finish_football_resource_sync", {
      p_sync_run_id: syncRunId,
      p_status: "succeeded",
      p_rows_found: rows.length,
      p_rows_staged: readObjectNumber(staged, "staged_rows", rows.length),
      p_rows_applied: readObjectNumber(applied, "applied_rows", 0),
      p_metadata: {
        ...metadata,
        edge_function: "sync-livescore-football",
        applied_live_state: Boolean(liveState),
      },
    });

    const body = {
      success: true,
      resource_id: resource.resourceId,
      rows: rows.length,
      sync_run_id: syncRunId,
      staged,
      applied,
      live_state: liveState,
    };
    audit = await finishCronJobRun(supabase, audit, "completed", body);

    return Response.json(
      {
        ...body,
        audit: cronAuditResponse(audit),
      },
      { headers: buildCorsHeaders("content-type", req) },
    );
  } catch (error) {
    audit = await finishCronJobRun(
      supabase,
      audit,
      "failed",
      { resource_id: resourceId, apply: applyToMatches },
      getErrorMessage(error),
    );
    return Response.json(
      {
        error: getErrorMessage(error),
        resource_id: resourceId,
        audit: cronAuditResponse(audit),
      },
      { status: 500, headers: buildCorsHeaders("content-type", req) },
    );
  }
}

if (import.meta.main) {
  Deno.serve(async (req) => {
    try {
      return await handleSyncLiveScoreFootball(req);
    } catch (error) {
      return Response.json(
        { error: getErrorMessage(error) },
        { status: 500, headers: buildCorsHeaders("content-type", req) },
      );
    }
  });
}
