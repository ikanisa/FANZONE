import { ALLOWED_HEADERS, FUNCTION_NAME } from "./constants.ts";
import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";

export class HttpError extends Error {
  status: number;
  details?: unknown;

  constructor(status: number, message: string, details?: unknown) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export const corsHeaders = buildCorsHeaders(ALLOWED_HEADERS);

export function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new HttpError(500, `Missing required environment variable: ${name}`);
  }
  return value;
}

export function assertAuthorized(req: Request) {
  // Accept service role bearer, anon key bearer, or shared secret
  // Try both standard and FANZONE-prefixed env vars (project uses custom names)
  const serviceRoleKey = (
    Deno.env.get("FANZONE_SUPABASE_SERVICE_ROLE_KEY") ||
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  )?.trim();
  const matchSyncSecret = Deno.env.get("MATCH_SYNC_SECRET")?.trim();
  const anonKey = (
    Deno.env.get("FANZONE_ANON_KEY") ||
    Deno.env.get("SUPABASE_ANON_KEY")
  )?.trim();

  // Dev passthrough: if no auth keys are configured, skip auth
  if (!serviceRoleKey && !matchSyncSecret && !anonKey) {
    return;
  }

  if (
    isAuthorizedEdgeRequest({
      req,
      serviceRoleKey,
      allowServiceRoleBearer: true,
      sharedSecrets: matchSyncSecret
        ? [{ header: "x-match-sync-secret", value: matchSyncSecret }]
        : [],
    })
  ) {
    return;
  }

  // Also accept anon key as bearer (for CLI/cron invocation)
  if (anonKey) {
    const bearer = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim();
    if (bearer === anonKey) return;
  }

  throw new HttpError(401, "Unauthorized request.");
}

export function logError(requestId: string, error: unknown) {
  console.error(`[${FUNCTION_NAME}]`, {
    requestId,
    error: getErrorMessage(error),
  });
}
