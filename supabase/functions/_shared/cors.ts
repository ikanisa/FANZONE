import { resolveEdgeCorsOrigin } from "./cors_allowlist.ts";

/**
 * Shared CORS headers for Edge Functions.
 *
 * Production origins are allowlisted through FANZONE_EDGE_ALLOWED_ORIGINS
 * (comma-separated). ALLOWED_ORIGIN remains supported for older functions.
 */
export function buildCorsHeaders(req?: Request): Record<string, string> {
  const allowedOrigin = resolveEdgeCorsOrigin(req?.headers.get("origin"));
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-request-id",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };

  if (allowedOrigin) {
    headers["Access-Control-Allow-Origin"] = allowedOrigin;
  }

  return headers;
}

export const corsHeaders = buildCorsHeaders();

declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

function shouldExposeErrorDetails(status: number): boolean {
  if (status < 500) return true;

  try {
    return Deno.env.get("FANZONE_EDGE_EXPOSE_ERROR_DETAILS") === "true";
  } catch {
    return false;
  }
}

/**
 * Create a JSON response with CORS headers
 */
export function jsonResponse(
  data: unknown,
  status = 200,
  req?: Request,
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...buildCorsHeaders(req), "Content-Type": "application/json" },
  });
}

/**
 * Create an error response with CORS headers
 */
export function errorResponse(
  message: string,
  status: number,
  details?: unknown,
  req?: Request,
): Response {
  const body = details !== undefined && shouldExposeErrorDetails(status)
    ? { error: message, details }
    : { error: message };

  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: { ...buildCorsHeaders(req), "Content-Type": "application/json" },
    },
  );
}

/**
 * Handle CORS preflight request
 */
export function handleCors(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    const headers = buildCorsHeaders(req);
    if (req.headers.get("origin") && !headers["Access-Control-Allow-Origin"]) {
      return new Response("CORS origin not allowed", { status: 403, headers });
    }
    return new Response("ok", { headers });
  }
  return null;
}
