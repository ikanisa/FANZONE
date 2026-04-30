/**
 * Shared CORS headers for all Edge Functions
 * Ported from DineIn _lib/cors.ts
 */
export const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-request-id",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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
    details?: unknown
): Response {
    return new Response(
        JSON.stringify({ error: message, details }),
        {
            status,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
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
