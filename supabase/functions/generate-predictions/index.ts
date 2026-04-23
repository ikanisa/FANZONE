import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("EDGE_SERVICE_ROLE_KEY")
  ?.trim() || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() || "";
const CRON_SECRET = Deno.env.get("CRON_SECRET")?.trim() || "";

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
    const payload = await req.json().catch(() => ({})) as { limit?: number };
    const limit = Math.max(1, Math.min(250, Number(payload.limit ?? 50) || 50));

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data, error } = await supabase.rpc(
      "generate_predictions_for_upcoming_matches",
      { p_limit: limit },
    );

    if (error) {
      throw error;
    }

    return Response.json(
      { generated_predictions: data ?? 0, limit },
      { headers: buildCorsHeaders("content-type") },
    );
  } catch (error) {
    return Response.json(
      { error: getErrorMessage(error) },
      { status: 500, headers: buildCorsHeaders("content-type") },
    );
  }
});
