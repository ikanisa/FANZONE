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
  // Accept either service role bearer token or shared secret
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  const matchSyncSecret = Deno.env.get("MATCH_SYNC_SECRET")?.trim();

  if (
    !isAuthorizedEdgeRequest({
      req,
      serviceRoleKey,
      allowServiceRoleBearer: true,
      sharedSecrets: matchSyncSecret
        ? [{ header: "x-match-sync-secret", value: matchSyncSecret }]
        : [],
    })
  ) {
    throw new HttpError(401, "Unauthorized request.");
  }
}

export function logError(requestId: string, error: unknown) {
  console.error(`[${FUNCTION_NAME}]`, {
    requestId,
    error: getErrorMessage(error),
  });
}
