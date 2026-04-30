import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
  handleCors,
  jsonResponse,
  errorResponse,
  createAdminClient,
  createLogger,
  getOrCreateRequestId,
} from "../_shared/mod.ts";

const searchSchema = z.object({
  q: z.string().min(1).max(200).optional(),
  country: z.enum(["RW", "MT"]).optional(),
  status: z.enum(["active", "pending", "suspended"]).optional().default("active"),
  limit: z.number().int().min(1).max(100).optional().default(20),
  offset: z.number().int().min(0).optional().default(0),
});

Deno.serve(async (req) => {
  const requestId = getOrCreateRequestId(req);
  const logger = createLogger({ requestId, action: "bar_search" });

  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "GET" && req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  try {
    logger.requestStart(req.method, "/bar_search");

    const supabaseAdmin = createAdminClient();

    // Parse from query params (GET) or body (POST)
    let searchParams: Record<string, unknown> = {};
    if (req.method === "GET") {
      const url = new URL(req.url);
      searchParams = {
        q: url.searchParams.get("q") || undefined,
        country: url.searchParams.get("country") || undefined,
        status: url.searchParams.get("status") || undefined,
        limit: url.searchParams.has("limit") ? Number(url.searchParams.get("limit")) : undefined,
        offset: url.searchParams.has("offset") ? Number(url.searchParams.get("offset")) : undefined,
      };
    } else {
      searchParams = await req.json();
    }

    const parsed = searchSchema.safeParse(searchParams);
    if (!parsed.success) {
      return errorResponse("Invalid search parameters", 400, parsed.error.issues);
    }

    const { q, country, status, limit, offset } = parsed.data;

    // Build query
    let query = supabaseAdmin
      .from("venues")
      .select("id, name, slug, country, address, status, created_at", { count: "exact" })
      .eq("status", status!)
      .order("name", { ascending: true })
      .range(offset!, offset! + limit! - 1);

    if (country) {
      query = query.eq("country", country);
    }

    if (q) {
      query = query.or(`name.ilike.%${q}%,slug.ilike.%${q}%,address.ilike.%${q}%`);
    }

    const { data: venues, error, count } = await query;

    if (error) {
      logger.error("Search query failed", { error: error.message });
      return errorResponse("Search failed", 500);
    }

    logger.info("Search completed", { results: venues?.length || 0, total: count });

    return jsonResponse({
      success: true,
      requestId,
      venues: venues || [],
      pagination: {
        total: count || 0,
        limit: limit!,
        offset: offset!,
      },
    });
  } catch (error) {
    logger.error("Bar search error", { error: String(error) });
    return errorResponse("Internal server error", 500);
  }
});
