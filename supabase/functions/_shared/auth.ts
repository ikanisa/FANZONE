import {
  createClient,
  SupabaseClient,
  User,
} from "https://esm.sh/@supabase/supabase-js@2";
import { errorResponse } from "./cors.ts";
import { AuthContext, RateLimitConfig } from "./types.ts";
import { Logger } from "./logger.ts";

export type AdminRole = "viewer" | "moderator" | "admin" | "super_admin";

export interface ActiveAdminRecord {
  id: string;
  role: AdminRole;
}

const adminRoleRank: Record<AdminRole, number> = {
  viewer: 1,
  moderator: 2,
  admin: 3,
  super_admin: 4,
};

declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

/**
 * Create a Supabase admin client (service role, bypasses RLS)
 */
export function createAdminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
}

/**
 * Create a Supabase user client (respects RLS)
 */
export function createUserClient(authHeader: string): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } },
  );
}

/**
 * Extract authorization header from request
 */
export function getAuthHeader(req: Request): string | null {
  return req.headers.get("Authorization");
}

/**
 * Get the authenticated user from request
 */
export async function getAuthenticatedUser(
  req: Request,
  logger?: Logger,
): Promise<{ user: User; supabaseUser: SupabaseClient } | null> {
  const authHeader = getAuthHeader(req);
  if (!authHeader) {
    logger?.warn("Missing authorization header");
    return null;
  }

  const supabaseUser = createUserClient(authHeader);
  const { data: { user }, error } = await supabaseUser.auth.getUser();

  if (error || !user) {
    logger?.warn("Failed to get user from token", { error: error?.message });
    return null;
  }

  logger?.debug("User authenticated", { userId: user.id, email: user.email });
  return { user, supabaseUser };
}

/**
 * Require authenticated user or return error response
 */
export async function requireAuth(
  req: Request,
  logger?: Logger,
): Promise<{ user: User; supabaseUser: SupabaseClient } | Response> {
  const auth = await getAuthenticatedUser(req, logger);
  if (!auth) {
    return errorResponse("Unauthorized", 401, undefined, req);
  }
  return auth;
}

/**
 * Optional authentication - returns user if authenticated, null otherwise
 */
export async function optionalAuth(
  req: Request,
  logger?: Logger,
): Promise<{ user: User; supabaseUser: SupabaseClient } | null> {
  return await getAuthenticatedUser(req, logger);
}

function isAdminRole(value: unknown): value is AdminRole {
  return value === "viewer" || value === "moderator" || value === "admin" ||
    value === "super_admin";
}

/**
 * Fetch the caller's active admin record, including role, through the service-role client.
 */
export async function getActiveAdminRecord(
  supabaseAdmin: SupabaseClient,
  userId: string,
  logger?: Logger,
): Promise<ActiveAdminRecord | null> {
  const { data: adminRecord, error } = await supabaseAdmin
    .from("admin_users")
    .select("id, role")
    .eq("user_id", userId)
    .eq("is_active", true)
    .single();

  if (error || !adminRecord) {
    logger?.debug("Admin record check", {
      userId,
      isAdmin: false,
      error: error?.message,
    });
    return null;
  }

  if (!isAdminRole(adminRecord.role)) {
    logger?.warn("Admin record has unsupported role", {
      userId,
      role: adminRecord.role,
    });
    return null;
  }

  logger?.debug("Admin record check", {
    userId,
    isAdmin: true,
    role: adminRecord.role,
  });
  return {
    id: adminRecord.id,
    role: adminRecord.role,
  };
}

/**
 * Check if user is an admin
 */
export async function isAdmin(
  supabaseAdmin: SupabaseClient,
  userId: string,
  logger?: Logger,
): Promise<boolean> {
  const result = await getActiveAdminRecord(supabaseAdmin, userId, logger) !==
    null;
  logger?.debug("Admin check", { userId, isAdmin: result });
  return result;
}

/**
 * Check if user is a member of a venue
 */
export async function isVendorMember(
  supabaseUser: SupabaseClient,
  vendorId: string,
  userId: string,
  logger?: Logger,
): Promise<boolean> {
  const { data: memberRecord } = await supabaseUser
    .from("venue_users")
    .select("id, role")
    .eq("venue_id", vendorId)
    .eq("user_id", userId)
    .eq("is_active", true)
    .single();

  const result = !!memberRecord;
  logger?.debug("Vendor member check", {
    userId,
    vendorId,
    isMember: result,
    role: memberRecord?.role,
  });
  return result;
}

/**
 * Require user to be admin or return error response
 */
export async function requireAdmin(
  supabaseAdmin: SupabaseClient,
  userId: string,
  logger?: Logger,
): Promise<boolean | Response> {
  const admin = await isAdmin(supabaseAdmin, userId, logger);
  if (!admin) {
    logger?.warn("Admin access denied", { userId });
    return errorResponse("Forbidden - admin access required", 403);
  }
  return true;
}

/**
 * Require a minimum active admin role or return an error response.
 */
export async function requireAdminRole(
  supabaseAdmin: SupabaseClient,
  userId: string,
  minimumRole: AdminRole,
  logger?: Logger,
): Promise<ActiveAdminRecord | Response> {
  const admin = await getActiveAdminRecord(supabaseAdmin, userId, logger);
  if (!admin) {
    logger?.warn("Admin access denied", { userId, minimumRole });
    return errorResponse("Forbidden - admin access required", 403);
  }

  if (adminRoleRank[admin.role] < adminRoleRank[minimumRole]) {
    logger?.warn("Admin role access denied", {
      userId,
      role: admin.role,
      minimumRole,
    });
    return errorResponse(`Forbidden - ${minimumRole} access required`, 403);
  }

  return admin;
}

/**
 * Require user to be venue member or admin
 */
export async function requireVendorOrAdmin(
  supabaseAdmin: SupabaseClient,
  supabaseUser: SupabaseClient,
  vendorId: string,
  userId: string,
  logger?: Logger,
): Promise<boolean | Response> {
  if (await isVendorMember(supabaseUser, vendorId, userId, logger)) {
    return true;
  }

  if (await isAdmin(supabaseAdmin, userId, logger)) {
    return true;
  }

  logger?.warn("Vendor/admin access denied", { userId, vendorId });
  return errorResponse("Forbidden - not a venue member or admin", 403);
}

/**
 * Check rate limit for user and endpoint
 */
export async function checkRateLimit(
  supabaseAdmin: SupabaseClient,
  userId: string,
  config: RateLimitConfig,
  logger?: Logger,
): Promise<boolean | Response> {
  const { data: allowed, error } = await supabaseAdmin.rpc("check_rate_limit", {
    p_user_id: userId,
    p_action: config.endpoint,
    p_max_count: config.maxRequests,
    p_window: config.window,
  });

  if (error) {
    logger?.error("Rate limit check failed", {
      error: error.message,
      endpoint: config.endpoint,
    });
    return errorResponse("Rate limit check failed", 500);
  }

  if (!allowed) {
    logger?.warn("Rate limit exceeded", { userId, endpoint: config.endpoint });
    return errorResponse("Too many requests", 429);
  }

  return true;
}
