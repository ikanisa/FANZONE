import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";
import { ALLOWED_HEADERS, FUNCTION_NAME } from "./constants.ts";

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
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const syncSecret = Deno.env.get("TEAM_CREST_SYNC_SECRET")?.trim();

  if (
    isAuthorizedEdgeRequest({
      req,
      serviceRoleKey,
      allowServiceRoleBearer: true,
      sharedSecrets: [{
        header: "x-team-crest-sync-secret",
        value: syncSecret,
      }],
    })
  ) {
    return;
  }

  throw new HttpError(401, "Unauthorized request.");
}

export async function readJsonBody(req: Request): Promise<unknown> {
  try {
    return await req.json();
  } catch {
    throw new HttpError(400, "Request body must be valid JSON.");
  }
}

export function mapError(error: unknown, requestId: string) {
  if (error instanceof HttpError) {
    return {
      status: error.status,
      body: {
        success: false,
        requestId,
        error: error.message,
        details: error.details ?? null,
      },
    };
  }

  return {
    status: 500,
    body: {
      success: false,
      requestId,
      error: "Unhandled server error.",
      details: getErrorMessage(error),
    },
  };
}

export function logUnhandledError(requestId: string, error: unknown) {
  console.error(`[${FUNCTION_NAME}]`, {
    requestId,
    error,
  });
}
