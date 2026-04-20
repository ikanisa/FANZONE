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

export function assertAuthorized(
  req: Request,
  options: { matchSyncSecret?: string } = {},
) {
  const matchSyncSecret = options.matchSyncSecret?.trim() ||
    Deno.env.get("MATCH_SYNC_SECRET")?.trim();
  if (!matchSyncSecret) {
    throw new HttpError(
      500,
      "MATCH_SYNC_SECRET is not configured. Rejecting all requests.",
    );
  }

  if (
    !isAuthorizedEdgeRequest({
      req,
      sharedSecrets: [
        { header: "x-match-sync-secret", value: matchSyncSecret },
      ],
    })
  ) {
    throw new HttpError(401, "Unauthorized request.");
  }
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

  if (_isGeminiApiError(error)) {
    const status = error.status === 429 ? 429 : 502;
    return {
      status,
      body: {
        success: false,
        requestId,
        error: error.status === 429
          ? "Gemini API rate limit or quota exceeded."
          : "Gemini API request failed.",
        details: {
          status: error.status,
          message: error.message,
        },
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

function _isGeminiApiError(
  error: unknown,
): error is { status: number; message: string } {
  if (typeof error != "object" || error == null) {
    return false;
  }

  const candidate = error as Record<string, unknown>;
  return typeof candidate["status"] == "number" &&
    typeof candidate["message"] == "string";
}
