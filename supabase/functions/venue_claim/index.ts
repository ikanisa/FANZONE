import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import {
  AuditAction,
  checkRateLimit,
  createAdminClient,
  createAuditLogger,
  createLogger,
  EntityType,
  errorResponse,
  getOrCreateRequestId,
  handleCors,
  jsonResponse,
  requireAdmin,
  requireAuth,
} from "../_shared/mod.ts";
import type { RateLimitConfig } from "../_shared/mod.ts";

/**
 * Admin-only: create a new venue record from Google Place data.
 * Generates unique slug, creates vendor + membership, audit logged.
 */
const vendorClaimSchema = z.object({
  google_place_id: z.string().min(1),
  slug: z.string().min(1).optional().nullable(),
  name: z.string().min(1),
  address: z.string().optional().nullable(),
  lat: z.number().optional().nullable(),
  lng: z.number().optional().nullable(),
  hours_json: z.unknown().optional().nullable(),
  photos_json: z.unknown().optional().nullable(),
  website: z.string().optional().nullable(),
  phone: z.string().optional().nullable(),
  revolut_link: z.string().optional().nullable(),
  whatsapp: z.string().optional().nullable(),
  country: z.enum(["RW", "MT"]).default("MT"),
});

type VendorClaimInput = z.infer<typeof vendorClaimSchema>;

const RATE_LIMIT: RateLimitConfig = {
  maxRequests: 10,
  window: "1 hour",
  endpoint: "venue_claim",
};

Deno.serve(async (req) => {
  const startTime = Date.now();
  const requestId = getOrCreateRequestId(req);
  const logger = createLogger({ requestId, action: "venue_claim" });

  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  try {
    logger.requestStart(req.method, "/venue_claim");

    const supabaseAdmin = createAdminClient();

    // Authenticate user
    const authResult = await requireAuth(req, logger);
    if (authResult instanceof Response) return authResult;
    const { user } = authResult;

    // Require admin access
    const adminResult = await requireAdmin(supabaseAdmin, user.id, logger);
    if (adminResult instanceof Response) return adminResult;

    // Parse + validate input
    const body = await req.json();
    const parsed = vendorClaimSchema.safeParse(body);
    if (!parsed.success) {
      logger.warn("Validation failed", { errors: parsed.error.issues });
      return errorResponse("Invalid request data", 400, parsed.error.issues);
    }

    const input: VendorClaimInput = parsed.data;
    logger.info("Processing vendor claim", {
      googlePlaceId: input.google_place_id,
      name: input.name,
    });

    // Rate limiting
    const rateLimitResult = await checkRateLimit(
      supabaseAdmin,
      user.id,
      RATE_LIMIT,
      logger,
    );
    if (rateLimitResult instanceof Response) return rateLimitResult;

    const audit = createAuditLogger(supabaseAdmin, user.id, requestId, logger);

    // ========================================================================
    // STEP 1: Check if vendor already exists with this google_place_id
    // ========================================================================
    const { data: existingVendor } = await supabaseAdmin
      .from("venues")
      .select("id")
      .eq("google_place_id", input.google_place_id)
      .single();

    if (existingVendor) {
      const { data: existingMember } = await supabaseAdmin
        .from("venue_users")
        .select("id, role")
        .eq("venue_id", existingVendor.id)
        .eq("user_id", user.id)
        .single();

      if (existingMember) {
        return errorResponse("Vendor already claimed", 400, {
          venue_id: existingVendor.id,
          message: "You are already a member of this vendor",
        });
      } else {
        return errorResponse("Vendor already exists", 409, {
          venue_id: existingVendor.id,
          message: "This venue has already been claimed by another user",
        });
      }
    }

    // ========================================================================
    // STEP 2: Generate unique slug
    // ========================================================================
    const generateSlug = (name: string): string => {
      return name
        .toLowerCase()
        .trim()
        .replace(/[^\w\s-]/g, "")
        .replace(/[\s_-]+/g, "-")
        .replace(/^-+|-+$/g, "");
    };

    let slug = input.slug || generateSlug(input.name);
    let slugAttempts = 0;
    let slugExists = true;

    while (slugExists && slugAttempts < 10) {
      const { data: existing } = await supabaseAdmin
        .from("venues")
        .select("id")
        .eq("slug", slug)
        .single();

      if (!existing) {
        slugExists = false;
      } else {
        slug = `${slug}-${Math.random().toString(36).substring(2, 6)}`;
        slugAttempts++;
      }
    }

    if (slugExists) {
      logger.error("Failed to generate unique slug after retries");
      return errorResponse("Failed to generate unique slug", 500);
    }

    // ========================================================================
    // STEP 3: Create vendor record
    // ========================================================================
    const vendorData = {
      google_place_id: input.google_place_id,
      slug: slug,
      name: input.name,
      address_line1: input.address || null,
      latitude: input.lat || null,
      longitude: input.lng || null,
      hours_json: input.hours_json || null,
      photos_json: input.photos_json || null,
      website_url: input.website || null,
      owner_phone: input.phone || null,
      revolut_link: input.revolut_link || null,
      whatsapp: input.whatsapp || null,
      country_code: input.country,
      venue_type: "bar",
      currency_code: input.country === "RW" ? "RWF" : "EUR",
      owner_id: user.id,
      claimed: true,
      is_active: false,
      onboarding_status: "draft",
    };

    const { data: vendor, error: vendorError } = await supabaseAdmin
      .from("venues")
      .insert(vendorData)
      .select()
      .single();

    if (vendorError || !vendor) {
      logger.error("Failed to create vendor", { error: vendorError?.message });
      return errorResponse(
        "Failed to create vendor",
        500,
        vendorError?.message,
      );
    }

    // ========================================================================
    // STEP 4: Create venue_users membership with owner role
    // ========================================================================
    const { data: vendorUser, error: vendorUserError } = await supabaseAdmin
      .from("venue_users")
      .insert({
        venue_id: vendor.id,
        user_id: user.id,
        role: "owner",
        is_active: true,
      })
      .select()
      .single();

    if (vendorUserError || !vendorUser) {
      logger.error("Failed to create vendor membership, rolling back", {
        error: vendorUserError?.message,
      });
      await supabaseAdmin.from("venues").delete().eq("id", vendor.id);
      return errorResponse(
        "Failed to create vendor membership",
        500,
        vendorUserError?.message,
      );
    }

    // ========================================================================
    // STEP 5: Write audit log
    // ========================================================================
    await audit.log(AuditAction.VENDOR_CLAIM, EntityType.VENDOR, vendor.id, {
      googlePlaceId: input.google_place_id,
      name: input.name,
      slug,
      status: "pending",
    });

    const durationMs = Date.now() - startTime;
    logger.requestEnd(201, durationMs);

    return jsonResponse(
      {
        success: true,
        requestId,
        vendor: {
          ...vendor,
          membership: vendorUser,
        },
      },
      201,
    );
  } catch (error) {
    const durationMs = Date.now() - startTime;
    logger.error("Vendor claim error", { error: String(error), durationMs });
    return errorResponse("Internal server error", 500, String(error));
  }
});
