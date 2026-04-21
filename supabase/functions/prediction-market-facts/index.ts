import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET = Deno.env.get("CRON_SECRET")?.trim() || "";
const PREDICTION_FACTS_SECRET =
  Deno.env.get("PREDICTION_FACTS_SECRET")?.trim() || "";

type FactScopeType = "match" | "scope";

interface FactPayload {
  market_type_id: string;
  subject_key?: string;
  fact_value: Record<string, unknown>;
  is_final?: boolean;
}

interface RefreshDerivedBody {
  mode?: "refresh_derived";
  match_id?: string | null;
  run_settlement_cycle?: boolean;
  trigger_source?: string;
}

interface IngestFactsBody {
  mode: "ingest";
  scope_type: FactScopeType;
  scope_id: string;
  facts: FactPayload[];
  source_type?: string;
  source_ref?: string | null;
  run_settlement_cycle?: boolean;
  trigger_source?: string;
}

function isFactScopeType(value: unknown): value is FactScopeType {
  return value === "match" || value === "scope";
}

function isIngestFactsBody(
  value: RefreshDerivedBody | IngestFactsBody,
): value is IngestFactsBody {
  return value.mode === "ingest";
}

async function runSettlementCycle(
  supabase: any,
  triggerSource?: string,
) {
  const { data, error } = await supabase.rpc(
    "run_prediction_market_settlement_cycle",
    {
      p_trigger_source: triggerSource || "prediction-market-facts-edge",
    },
  );

  if (error) {
    throw new Error(`Settlement cycle failed: ${error.message}`);
  }

  return data ?? null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: buildCorsHeaders("authorization, content-type, x-cron-secret, x-prediction-facts-secret"),
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (
    !isAuthorizedEdgeRequest({
      req,
      sharedSecrets: [
        { header: "x-cron-secret", value: CRON_SECRET },
        { header: "x-prediction-facts-secret", value: PREDICTION_FACTS_SECRET },
      ],
    })
  ) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    const body = await req.json().catch(() => ({})) as
      | RefreshDerivedBody
      | IngestFactsBody;

    const mode = body.mode ?? "refresh_derived";

    if (mode === "refresh_derived") {
      const refreshBody = body as RefreshDerivedBody;
      const { data, error } = await supabase.rpc("refresh_match_resolution_facts", {
        p_match_id: refreshBody.match_id ?? null,
      });

      if (error) {
        throw new Error(`Derived fact refresh failed: ${error.message}`);
      }

      const settlement =
        refreshBody.run_settlement_cycle === true
          ? await runSettlementCycle(supabase, refreshBody.trigger_source)
          : null;

      return Response.json({
        status: "ok",
        mode,
        refresh: data ?? null,
        settlement,
      });
    }

    if (mode === "ingest") {
      if (!isIngestFactsBody(body)) {
        return Response.json({ error: "Invalid ingest payload" }, { status: 400 });
      }

      if (!isFactScopeType(body.scope_type)) {
        return Response.json(
          { error: "scope_type must be 'match' or 'scope'" },
          { status: 400 },
        );
      }

      if (!body.scope_id?.trim()) {
        return Response.json({ error: "scope_id is required" }, { status: 400 });
      }

      if (!Array.isArray(body.facts) || body.facts.length === 0) {
        return Response.json(
          { error: "facts must be a non-empty array" },
          { status: 400 },
        );
      }

      const { data, error } = await supabase.rpc(
        "ingest_prediction_market_resolution_facts",
        {
          p_scope_type: body.scope_type,
          p_scope_id: body.scope_id,
          p_facts: body.facts,
          p_source_type: body.source_type ?? "edge_function",
          p_source_ref: body.source_ref ?? null,
        },
      );

      if (error) {
        throw new Error(`Fact ingestion failed: ${error.message}`);
      }

      const settlement =
        body.run_settlement_cycle === true
          ? await runSettlementCycle(supabase, body.trigger_source)
          : null;

      return Response.json({
        status: "ok",
        mode,
        ingest: data ?? null,
        settlement,
      });
    }

    return Response.json({ error: `Unsupported mode: ${mode}` }, { status: 400 });
  } catch (error: unknown) {
    return Response.json(
      { error: getErrorMessage(error) },
      { status: 500 },
    );
  }
});
