/**
 * Shared CORS headers for all Edge Functions
 */
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-request-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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
export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * Create an error response with CORS headers
 */
export function errorResponse(
  message: string,
  status: number,
  details?: unknown,
): Response {
  const body = details !== undefined && shouldExposeErrorDetails(status)
    ? { error: message, details }
    : { error: message };

  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}

/**
 * Handle CORS preflight request
 */
export function handleCors(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}
