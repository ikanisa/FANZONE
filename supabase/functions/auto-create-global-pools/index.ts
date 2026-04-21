// FANZONE — Auto Create Global Pools Edge Function
//
// Creates system-seeded global pools for upcoming matches involving
// the top active European teams. Each generated pool is seeded with
// 500 FET from the machine system account and is visible to everyone.
//
// Triggered by:
//   - pg_cron every 30 minutes (via pg_net)
//   - manual admin invocation
//
// Auth:
//   - service_role bearer
//   - x-cron-secret

import { createClient } from "jsr:@supabase/supabase-js@2";

import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";

const FUNCTION_NAME = "auto-create-global-pools";

const corsHeaders = {
  ...buildCorsHeaders("authorization, content-type, x-cron-secret"),
  "Content-Type": "application/json",
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing env: ${name}`);
  return value;
}

function parsePositiveInt(
  value: unknown,
  fallback: number,
  min: number,
  max: number,
): number {
  const numeric = typeof value === "number"
    ? value
    : typeof value === "string" && value.trim().length > 0
    ? Number(value)
    : NaN;

  if (!Number.isFinite(numeric)) return fallback;
  return Math.min(Math.max(Math.trunc(numeric), min), max);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, {
      ok: false,
      function: FUNCTION_NAME,
      error: "Method not allowed",
    });
  }

  let serviceRoleKey: string;
  let supabaseUrl: string;
  let cronSecret: string;

  try {
    serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
    supabaseUrl = requireEnv("SUPABASE_URL");
    cronSecret = Deno.env.get("CRON_SECRET")?.trim() || "";
  } catch (error) {
    return jsonResponse(500, {
      ok: false,
      function: FUNCTION_NAME,
      error: getErrorMessage(error),
    });
  }

  if (
    !isAuthorizedEdgeRequest({
      req,
      serviceRoleKey,
      allowServiceRoleBearer: true,
      sharedSecrets: [{ header: "x-cron-secret", value: cronSecret }],
    })
  ) {
    return jsonResponse(401, {
      ok: false,
      function: FUNCTION_NAME,
      error: "Unauthorized",
    });
  }

  let body: Record<string, unknown> = {};

  try {
    const rawBody = await req.text();
    if (rawBody.trim().length > 0) {
      body = JSON.parse(rawBody);
    }
  } catch (error) {
    return jsonResponse(400, {
      ok: false,
      function: FUNCTION_NAME,
      error: `Invalid JSON body: ${getErrorMessage(error)}`,
    });
  }

  const hoursAhead = parsePositiveInt(
    body.hoursAhead ?? body.hours_ahead,
    72,
    1,
    168,
  );
  const maxPools = parsePositiveInt(
    body.maxPools ?? body.max_pools,
    20,
    1,
    100,
  );
  const stakeFet = parsePositiveInt(
    body.stakeFet ?? body.stake_fet,
    500,
    10,
    1_000_000,
  );
  const topRank = parsePositiveInt(
    body.topRank ?? body.top_rank,
    20,
    1,
    100,
  );
  const lockBufferMinutes = parsePositiveInt(
    body.lockBufferMinutes ?? body.lock_buffer_minutes,
    30,
    1,
    240,
  );

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    const { data, error } = await supabase.rpc("auto_create_global_pools", {
      p_hours_ahead: hoursAhead,
      p_limit: maxPools,
      p_stake: stakeFet,
      p_top_rank: topRank,
      p_lock_buffer_minutes: lockBufferMinutes,
    });

    if (error) {
      console.error(`[${FUNCTION_NAME}] RPC failed`, error);
      return jsonResponse(500, {
        ok: false,
        function: FUNCTION_NAME,
        error: error.message,
        config: {
          hoursAhead,
          maxPools,
          stakeFet,
          topRank,
          lockBufferMinutes,
        },
      });
    }

    console.log(
      `[${FUNCTION_NAME}] completed`,
      JSON.stringify({
        hoursAhead,
        maxPools,
        stakeFet,
        topRank,
        lockBufferMinutes,
        summary: data,
      }),
    );

    return jsonResponse(200, {
      ok: true,
      function: FUNCTION_NAME,
      config: {
        hoursAhead,
        maxPools,
        stakeFet,
        topRank,
        lockBufferMinutes,
      },
      result: data,
    });
  } catch (error) {
    console.error(`[${FUNCTION_NAME}] unexpected failure`, error);
    return jsonResponse(500, {
      ok: false,
      function: FUNCTION_NAME,
      error: getErrorMessage(error),
    });
  }
});
