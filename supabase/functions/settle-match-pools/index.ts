import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

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

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("EDGE_SERVICE_ROLE_KEY")
  ?.trim() || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() || "";
const CRON_SECRET = Deno.env.get("CRON_SECRET")?.trim() || "";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: buildCorsHeaders(
        "authorization, apikey, content-type, x-cron-secret",
      ),
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (
    !isAuthorizedEdgeRequest({
      req,
      serviceRoleKey: SUPABASE_SERVICE_ROLE_KEY,
      allowServiceRoleBearer: true,
      sharedSecrets: [{ header: "x-cron-secret", value: CRON_SECRET }],
    })
  ) {
    return new Response("Unauthorized", { status: 401 });
  }

  const payload = await req.json().catch(() => ({})) as { limit?: number };
  const limit = Math.max(1, Math.min(250, Number(payload.limit ?? 50) || 50));

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let audit = await startCronJobRun(supabase, "settle-match-pools", {
    limit,
    edge_function: "settle-match-pools",
  });

  try {
    const { data, error } = await supabase.rpc(
      "settle_finished_match_pools",
      { p_limit: limit },
    );

    if (error) {
      throw error;
    }

    const body = { settled_pools: data ?? 0, limit };
    audit = await finishCronJobRun(supabase, audit, "completed", body);

    return Response.json(
      { ...body, audit: cronAuditResponse(audit) },
      {
        headers: buildCorsHeaders(
          "authorization, apikey, content-type, x-cron-secret",
        ),
      },
    );
  } catch (error) {
    audit = await finishCronJobRun(
      supabase,
      audit,
      "failed",
      { limit },
      getErrorMessage(error),
    );
    return Response.json(
      { error: getErrorMessage(error), audit: cronAuditResponse(audit) },
      {
        status: 500,
        headers: buildCorsHeaders(
          "authorization, apikey, content-type, x-cron-secret",
        ),
      },
    );
  }
});
