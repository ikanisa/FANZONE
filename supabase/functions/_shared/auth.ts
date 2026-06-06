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

type FanzoneJwtPayload = {
  aud?: unknown;
  exp?: unknown;
  iat?: unknown;
  iss?: unknown;
  sub?: unknown;
  role?: unknown;
  session_id?: unknown;
  phone?: unknown;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * Create a Supabase admin client (service role, bypasses RLS)
 */
export function createAdminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
      Deno.env.get("EDGE_SERVICE_ROLE_KEY")?.trim() || "",
  );
}

/**
 * Create a Supabase user client (respects RLS)
 */
export function createUserClient(authHeader: string): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY")?.trim() ||
      Deno.env.get("FANZONE_ANON_KEY")?.trim() || "",
    { global: { headers: { Authorization: authHeader } } },
  );
}

/**
 * Extract authorization header from request
 */
export function getAuthHeader(req: Request): string | null {
  const fanzoneAccessToken = req.headers.get("x-fanzone-access-token")?.trim();
  if (fanzoneAccessToken) return `Bearer ${fanzoneAccessToken}`;

  return req.headers.get("Authorization");
}

function getBearerToken(authHeader: string): string | null {
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

function base64UrlDecode(value: string): Uint8Array<ArrayBuffer> {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(
    normalized.length + (4 - normalized.length % 4) % 4,
    "=",
  );
  const decoded = atob(padded);
  const bytes: Uint8Array<ArrayBuffer> = new Uint8Array(decoded.length);
  for (let index = 0; index < decoded.length; index++) {
    bytes[index] = decoded.charCodeAt(index);
  }
  return bytes;
}

function decodeJwtPayload(token: string): FanzoneJwtPayload | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;

  try {
    const payloadJson = new TextDecoder().decode(base64UrlDecode(parts[1]));
    return JSON.parse(payloadJson) as FanzoneJwtPayload;
  } catch {
    return null;
  }
}

async function verifyJwtSignature(
  token: string,
  secret: string,
): Promise<boolean> {
  const parts = token.split(".");
  if (parts.length !== 3) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );

  return await crypto.subtle.verify(
    "HMAC",
    key,
    base64UrlDecode(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
}

async function isAcceptedByPostgrest(
  supabaseUser: SupabaseClient,
  userId: string,
  logger?: Logger,
): Promise<boolean> {
  const { data, error } = await supabaseUser
    .from("profiles")
    .select("user_id")
    .eq("user_id", userId)
    .maybeSingle();

  if (error || data?.user_id !== userId) {
    logger?.warn("FANZONE auth token was not accepted by PostgREST", {
      userId,
      error: error?.message,
    });
    return false;
  }

  return true;
}

function isValidFanzoneJwtPayload(
  payload: FanzoneJwtPayload | null,
): payload is FanzoneJwtPayload & {
  exp: number;
  sub: string;
  role: "authenticated";
  session_id: string;
} {
  if (!payload) return false;
  if (payload.role !== "authenticated") return false;
  if (typeof payload.sub !== "string" || !uuidPattern.test(payload.sub)) {
    return false;
  }
  if (
    typeof payload.session_id !== "string" ||
    !uuidPattern.test(payload.session_id)
  ) {
    return false;
  }
  if (typeof payload.exp !== "number") return false;
  return payload.exp > Math.floor(Date.now() / 1000);
}

async function getFanzoneJwtUser(
  authHeader: string,
  supabaseUser: SupabaseClient,
  logger?: Logger,
): Promise<{ user: User; supabaseUser: SupabaseClient } | null> {
  const token = getBearerToken(authHeader);
  const secret = Deno.env.get("FANZONE_JWT_SECRET")?.trim() ||
    Deno.env.get("SUPABASE_JWT_SECRET")?.trim() || "";
  if (!token) return null;

  const payload = decodeJwtPayload(token);
  if (!isValidFanzoneJwtPayload(payload)) {
    logger?.warn("Rejected invalid FANZONE auth token payload");
    return null;
  }

  const isVerified =
    (secret.length > 0 && await verifyJwtSignature(token, secret)) ||
    await isAcceptedByPostgrest(supabaseUser, payload.sub, logger);
  if (!isVerified) {
    logger?.warn("Rejected FANZONE auth token with invalid signature", {
      userId: payload.sub,
    });
    return null;
  }

  const supabaseAdmin = createAdminClient();
  const { data: sessionRow, error: sessionError } = await supabaseAdmin
    .from("whatsapp_auth_sessions")
    .select("id, user_id, revoked_at, access_expires_at")
    .eq("id", payload.session_id)
    .eq("user_id", payload.sub)
    .is("revoked_at", null)
    .maybeSingle();

  if (
    sessionError || !sessionRow ||
    new Date(String(sessionRow.access_expires_at)).getTime() <= Date.now()
  ) {
    logger?.warn("Rejected inactive FANZONE auth session", {
      userId: payload.sub,
      sessionId: payload.session_id,
      error: sessionError?.message,
    });
    return null;
  }

  const { data, error } = await supabaseAdmin.auth.admin.getUserById(
    payload.sub,
  );
  if (error || !data.user) {
    logger?.warn("Failed to load FANZONE auth user", {
      userId: payload.sub,
      error: error?.message,
    });
    return {
      user: {
        id: payload.sub,
        phone: typeof payload.phone === "string" ? payload.phone : null,
        app_metadata: {},
        user_metadata: {},
        aud: "authenticated",
        created_at: new Date(0).toISOString(),
      } as User,
      supabaseUser,
    };
  }

  logger?.debug("User authenticated from FANZONE token", {
    userId: data.user.id,
  });
  return { user: data.user, supabaseUser };
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
    return await getFanzoneJwtUser(authHeader, supabaseUser, logger);
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
