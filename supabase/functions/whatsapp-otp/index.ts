// FANZONE — WhatsApp Cloud API OTP Edge Function
//
// Custom OTP pipeline using WhatsApp Business Cloud API.
//
// Actions:
//   POST { action: "send", phone: "+356..." }
//     -> Generate OTP, store hash, send via WhatsApp Cloud API
//
//   POST { action: "verify", phone: "+356...", otp: "123456" }
//     -> Verify OTP, create/find Supabase user, create custom FANZONE session
//
//   POST { action: "refresh", refresh_token: "..." }
//     -> Rotate the custom refresh token and issue a new access token
//
//   POST { action: "logout", refresh_token: "..." }
//     -> Revoke the custom FANZONE session
//
// Required secrets:
//   WABA_ACCESS_TOKEN         — WhatsApp Business API token
//   WABA_PHONE_NUMBER_ID      — WhatsApp Business phone number ID
//   SUPABASE_URL              — Supabase project URL
//   SUPABASE_SERVICE_ROLE_KEY — Service role key for admin operations
//   FANZONE_JWT_SECRET        — JWT signing secret for custom access tokens
//
// Optional:
//   WABA_OTP_TEMPLATE_NAME                — Template name (default: "gikundiro")
//   OTP_EXPIRY_SECONDS                    — OTP validity in seconds (default: 600)
//   WHATSAPP_SESSION_ACCESS_EXPIRY_SECONDS  — Access token validity (default: 3600)
//   WHATSAPP_SESSION_REFRESH_EXPIRY_SECONDS — Refresh token validity (default: 2592000)

import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { buildCorsHeaders, getErrorMessage } from "../_shared/http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_JWT_SECRET = Deno.env.get("FANZONE_JWT_SECRET")?.trim() || "";

const WABA_ACCESS_TOKEN = Deno.env.get("WABA_ACCESS_TOKEN")?.trim() || "";
const WABA_PHONE_NUMBER_ID = Deno.env.get("WABA_PHONE_NUMBER_ID")?.trim() || "";
const WABA_TEMPLATE_NAME = Deno.env.get("WABA_OTP_TEMPLATE_NAME")?.trim() ||
  "gikundiro";
const OTP_EXPIRY_SECONDS = parseInt(
  Deno.env.get("OTP_EXPIRY_SECONDS") || "600",
  10,
);
const SESSION_ACCESS_EXPIRY_SECONDS = parseInt(
  Deno.env.get("WHATSAPP_SESSION_ACCESS_EXPIRY_SECONDS") || "3600",
  10,
);
const SESSION_REFRESH_EXPIRY_SECONDS = parseInt(
  Deno.env.get("WHATSAPP_SESSION_REFRESH_EXPIRY_SECONDS") || "2592000",
  10,
);

const MAX_OTP_ATTEMPTS = 5;
const RATE_LIMIT_WINDOW_SECONDS = 60;
const CORS_HEADERS = buildCorsHeaders("authorization, content-type, apikey");

type UserSummary = {
  id: string;
  phone: string | null;
  [key: string]: unknown;
};

type SessionRow = {
  id: string;
  user_id: string;
  phone: string;
  refresh_token_hash: string;
  access_expires_at: string;
  refresh_expires_at: string;
  revoked_at: string | null;
};

type SessionResponsePayload = {
  success: true;
  access_token: string;
  refresh_token: string;
  expires_in: number;
  expires_at: number;
  refresh_expires_at: number;
  token_type: "bearer";
  user: UserSummary;
};

function createAdminClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

function normalizePhone(phone: string): string {
  let cleaned = phone.replace(/[\s\-()]/g, "");
  if (!cleaned.startsWith("+")) {
    cleaned = `+${cleaned}`;
  }
  return cleaned;
}

function generateOtp(): string {
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  return String(array[0] % 1000000).padStart(6, "0");
}

function generateOpaqueToken(byteLength = 32): string {
  const random = new Uint8Array(byteLength);
  crypto.getRandomValues(random);
  return base64UrlEncode(random);
}

async function hashValue(value: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(value);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function verifyHashedValue(
  candidate: string,
  expectedHash: string,
): Promise<boolean> {
  const computed = await hashValue(candidate);
  if (computed.length !== expectedHash.length) return false;
  let result = 0;
  for (let i = 0; i < computed.length; i++) {
    result |= computed.charCodeAt(i) ^ expectedHash.charCodeAt(i);
  }
  return result === 0;
}

function base64UrlEncode(data: Uint8Array): string {
  return btoa(String.fromCharCode(...data))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function signJwt(
  payload: Record<string, unknown>,
  secret: string,
): Promise<string> {
  const header = { alg: "HS256", typ: "JWT" };
  const encodedHeader = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify(header)),
  );
  const encodedPayload = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify(payload)),
  );
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;
}

async function sendWhatsAppOtp(
  phone: string,
  otp: string,
): Promise<{ success: boolean; error?: string }> {
  if (!WABA_ACCESS_TOKEN || !WABA_PHONE_NUMBER_ID) {
    return { success: false, error: "WhatsApp API not configured" };
  }

  const url =
    `https://graph.facebook.com/v21.0/${WABA_PHONE_NUMBER_ID}/messages`;

  const body = {
    messaging_product: "whatsapp",
    to: phone.replace("+", ""),
    type: "template",
    template: {
      name: WABA_TEMPLATE_NAME,
      language: { code: "en_US" },
      components: [
        {
          type: "body",
          parameters: [{ type: "text", text: otp }],
        },
        {
          type: "button",
          sub_type: "url",
          index: "0",
          parameters: [{ type: "text", text: otp }],
        },
      ],
    },
  };

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${WABA_ACCESS_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (res.ok) {
      return { success: true };
    }

    const errorBody = await res.text();
    console.error("WhatsApp API error:", res.status, errorBody);
    return { success: false, error: `WhatsApp API error: ${res.status}` };
  } catch (error) {
    console.error("WhatsApp API fetch error:", error);
    return { success: false, error: getErrorMessage(error) };
  }
}

async function loadUserSummary(
  supabase: SupabaseClient,
  userId: string,
  fallbackPhone: string,
): Promise<UserSummary> {
  const { data, error } = await supabase.auth.admin.getUserById(userId);
  if (error) {
    throw new Error("Failed to load authenticated user.");
  }
  return (data.user as UserSummary | null) ??
    { id: userId, phone: fallbackPhone };
}

async function issueSessionTokens(
  userId: string,
  phone: string,
  sessionId: string,
): Promise<{ accessToken: string; expiresIn: number; expiresAt: number }> {
  const now = Math.floor(Date.now() / 1000);
  const expiresIn = SESSION_ACCESS_EXPIRY_SECONDS;
  const expiresAt = now + expiresIn;

  const accessTokenPayload = {
    aud: "authenticated",
    exp: expiresAt,
    iat: now,
    iss: `${SUPABASE_URL}/auth/v1`,
    sub: userId,
    role: "authenticated",
    aal: "aal1",
    session_id: sessionId,
    email: null,
    phone,
    is_anonymous: false,
    app_metadata: {
      provider: "phone",
      providers: ["phone"],
    },
    user_metadata: {
      phone,
      phone_verified: true,
    },
    amr: [{ method: "otp", timestamp: now }],
  };

  return {
    accessToken: await signJwt(accessTokenPayload, SUPABASE_JWT_SECRET),
    expiresIn,
    expiresAt,
  };
}

async function buildSessionResponse(
  supabase: SupabaseClient,
  sessionRow: Pick<SessionRow, "id" | "user_id" | "phone">,
  refreshToken: string,
): Promise<SessionResponsePayload> {
  const issued = await issueSessionTokens(
    sessionRow.user_id,
    sessionRow.phone,
    sessionRow.id,
  );
  const refreshExpiresAt = Math.floor(Date.now() / 1000) +
    SESSION_REFRESH_EXPIRY_SECONDS;
  const user = await loadUserSummary(
    supabase,
    sessionRow.user_id,
    sessionRow.phone,
  );

  return {
    success: true,
    access_token: issued.accessToken,
    refresh_token: refreshToken,
    expires_in: issued.expiresIn,
    expires_at: issued.expiresAt,
    refresh_expires_at: refreshExpiresAt,
    token_type: "bearer",
    user,
  };
}

async function createCustomSession(
  supabase: SupabaseClient,
  userId: string,
  phone: string,
): Promise<Response> {
  if (!SUPABASE_JWT_SECRET) {
    return Response.json(
      { error: "JWT signing secret is not configured for WhatsApp auth." },
      { status: 503, headers: CORS_HEADERS },
    );
  }

  const sessionId = crypto.randomUUID();
  const refreshToken = generateOpaqueToken();
  const refreshTokenHash = await hashValue(refreshToken);
  const now = Date.now();
  const accessExpiresAt = new Date(now + SESSION_ACCESS_EXPIRY_SECONDS * 1000)
    .toISOString();
  const refreshExpiresAt = new Date(
    now + SESSION_REFRESH_EXPIRY_SECONDS * 1000,
  ).toISOString();

  const { error } = await supabase.from("whatsapp_auth_sessions").insert({
    id: sessionId,
    user_id: userId,
    phone,
    refresh_token_hash: refreshTokenHash,
    access_expires_at: accessExpiresAt,
    refresh_expires_at: refreshExpiresAt,
  });

  if (error) {
    console.error("Failed to persist WhatsApp auth session:", error);
    return Response.json(
      { error: "Failed to create authenticated session." },
      { status: 500, headers: CORS_HEADERS },
    );
  }

  const payload = await buildSessionResponse(
    supabase,
    { id: sessionId, user_id: userId, phone },
    refreshToken,
  );

  return Response.json(payload, { headers: CORS_HEADERS });
}

async function rotateSession(
  supabase: SupabaseClient,
  sessionRow: SessionRow,
): Promise<Response> {
  const refreshToken = generateOpaqueToken();
  const refreshTokenHash = await hashValue(refreshToken);
  const now = Date.now();
  const accessExpiresAt = new Date(now + SESSION_ACCESS_EXPIRY_SECONDS * 1000)
    .toISOString();
  const refreshExpiresAt = new Date(
    now + SESSION_REFRESH_EXPIRY_SECONDS * 1000,
  ).toISOString();

  const { error } = await supabase
    .from("whatsapp_auth_sessions")
    .update({
      refresh_token_hash: refreshTokenHash,
      access_expires_at: accessExpiresAt,
      refresh_expires_at: refreshExpiresAt,
      refreshed_at: new Date(now).toISOString(),
      updated_at: new Date(now).toISOString(),
    })
    .eq("id", sessionRow.id)
    .is("revoked_at", null);

  if (error) {
    console.error("Failed to rotate WhatsApp auth session:", error);
    return Response.json(
      { error: "Failed to refresh authenticated session." },
      { status: 500, headers: CORS_HEADERS },
    );
  }

  const payload = await buildSessionResponse(
    supabase,
    sessionRow,
    refreshToken,
  );
  return Response.json(payload, { headers: CORS_HEADERS });
}

async function resolveUserIdForPhone(
  supabase: SupabaseClient,
  phone: string,
): Promise<string | null> {
  const { data } = await supabase.rpc("find_auth_user_by_phone", {
    p_phone: phone,
  });
  if (typeof data === "string" && data.length > 0) {
    return data;
  }
  return null;
}

async function handleSend(phone: string): Promise<Response> {
  const normalized = normalizePhone(phone);

  if (!/^\+\d{7,15}$/.test(normalized)) {
    return Response.json(
      { error: "Invalid phone number format" },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const supabase = createAdminClient();
  const windowStart = new Date(
    Date.now() - RATE_LIMIT_WINDOW_SECONDS * 1000,
  ).toISOString();

  const { count } = await supabase
    .from("otp_verifications")
    .select("id", { count: "exact", head: true })
    .eq("phone", normalized)
    .gte("created_at", windowStart);

  if ((count ?? 0) >= 3) {
    return Response.json(
      { error: "Too many OTP requests. Please wait a minute." },
      { status: 429, headers: CORS_HEADERS },
    );
  }

  const otp = generateOtp();
  const otpHash = await hashValue(otp);
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_SECONDS * 1000)
    .toISOString();

  await supabase
    .from("otp_verifications")
    .delete()
    .eq("phone", normalized)
    .eq("verified", false);

  const { error: insertError } = await supabase
    .from("otp_verifications")
    .insert({
      phone: normalized,
      otp_hash: otpHash,
      expires_at: expiresAt,
    });

  if (insertError) {
    console.error("OTP insert error:", insertError);
    return Response.json(
      { error: "Failed to generate OTP" },
      { status: 500, headers: CORS_HEADERS },
    );
  }

  const sendResult = await sendWhatsAppOtp(normalized, otp);
  if (!sendResult.success) {
    return Response.json(
      { error: sendResult.error || "Failed to send WhatsApp message" },
      { status: 502, headers: CORS_HEADERS },
    );
  }

  return Response.json(
    { success: true, message: "OTP sent via WhatsApp" },
    { headers: CORS_HEADERS },
  );
}

async function handleVerify(phone: string, otp: string): Promise<Response> {
  const normalized = normalizePhone(phone);

  if (!otp || otp.length !== 6 || !/^\d{6}$/.test(otp)) {
    return Response.json(
      { error: "OTP must be exactly 6 digits" },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const supabase = createAdminClient();

  const { data: otpRecord, error: fetchError } = await supabase
    .from("otp_verifications")
    .select("*")
    .eq("phone", normalized)
    .eq("verified", false)
    .gt("expires_at", new Date().toISOString())
    .order("created_at", { ascending: false })
    .limit(1)
    .single();

  if (fetchError || !otpRecord) {
    return Response.json(
      { error: "No valid OTP found. Please request a new code." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  if (otpRecord.attempts >= MAX_OTP_ATTEMPTS) {
    await supabase
      .from("otp_verifications")
      .update({ verified: true })
      .eq("id", otpRecord.id);

    return Response.json(
      { error: "Too many attempts. Please request a new code." },
      { status: 429, headers: CORS_HEADERS },
    );
  }

  await supabase
    .from("otp_verifications")
    .update({ attempts: otpRecord.attempts + 1 })
    .eq("id", otpRecord.id);

  const isValid = await verifyHashedValue(otp, otpRecord.otp_hash);
  if (!isValid) {
    const remaining = MAX_OTP_ATTEMPTS - otpRecord.attempts - 1;
    return Response.json(
      { error: `Invalid code. ${remaining} attempts remaining.` },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  await supabase
    .from("otp_verifications")
    .update({ verified: true })
    .eq("id", otpRecord.id);

  let userId = await resolveUserIdForPhone(supabase, normalized);
  if (userId != null) {
    await supabase.auth.admin.updateUserById(userId, { phone_confirm: true });
  } else {
    const { data: newUser, error: createError } = await supabase.auth.admin
      .createUser({
        phone: normalized,
        phone_confirm: true,
        user_metadata: { phone_verified: true },
      });

    if (createError) {
      console.error("User creation error:", createError);
      return Response.json(
        { error: "Failed to create user account" },
        { status: 500, headers: CORS_HEADERS },
      );
    }

    userId = newUser.user.id;
  }

  if (!userId) {
    return Response.json(
      { error: "Failed to resolve user" },
      { status: 500, headers: CORS_HEADERS },
    );
  }

  return await createCustomSession(supabase, userId, normalized);
}

async function findSessionByRefreshToken(
  supabase: SupabaseClient,
  refreshToken: string,
): Promise<SessionRow | null> {
  const tokenHash = await hashValue(refreshToken);
  const { data, error } = await supabase
    .from("whatsapp_auth_sessions")
    .select(
      "id, user_id, phone, refresh_token_hash, access_expires_at, refresh_expires_at, revoked_at",
    )
    .eq("refresh_token_hash", tokenHash)
    .maybeSingle();

  if (error) {
    console.error("Session lookup error:", error);
    throw new Error("Failed to load session.");
  }

  return data as SessionRow | null;
}

async function handleRefresh(refreshToken: string): Promise<Response> {
  if (!refreshToken || refreshToken.trim().isEmpty) {
    return Response.json(
      { error: "Missing refresh token." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const supabase = createAdminClient();
  const sessionRow = await findSessionByRefreshToken(supabase, refreshToken);
  if (!sessionRow || sessionRow.revoked_at != null) {
    return Response.json(
      { error: "Session is invalid. Please sign in again." },
      { status: 401, headers: CORS_HEADERS },
    );
  }

  if (new Date(sessionRow.refresh_expires_at).getTime() <= Date.now()) {
    await supabase
      .from("whatsapp_auth_sessions")
      .update({
        revoked_at: new Date().toISOString(),
        revoke_reason: "refresh_expired",
        updated_at: new Date().toISOString(),
      })
      .eq("id", sessionRow.id)
      .is("revoked_at", null);

    return Response.json(
      { error: "Session expired. Please sign in again." },
      { status: 401, headers: CORS_HEADERS },
    );
  }

  return await rotateSession(supabase, sessionRow);
}

async function handleLogout(refreshToken: string): Promise<Response> {
  if (!refreshToken || refreshToken.trim().isEmpty) {
    return Response.json(
      { error: "Missing refresh token." },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const supabase = createAdminClient();
  const sessionRow = await findSessionByRefreshToken(supabase, refreshToken);
  if (sessionRow != null) {
    await supabase
      .from("whatsapp_auth_sessions")
      .update({
        revoked_at: new Date().toISOString(),
        revoke_reason: "logout",
        updated_at: new Date().toISOString(),
      })
      .eq("id", sessionRow.id)
      .is("revoked_at", null);
  }

  return Response.json({ success: true }, { headers: CORS_HEADERS });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: CORS_HEADERS,
    });
  }

  try {
    const body = await req.json();
    const action = body?.action?.toString();
    const phone = body?.phone?.toString();
    const otp = body?.otp?.toString();
    const refreshToken = body?.refresh_token?.toString();

    if (!action) {
      return Response.json(
        {
          error:
            "Missing 'action' field. Use 'send', 'verify', 'refresh', or 'logout'.",
        },
        { status: 400, headers: CORS_HEADERS },
      );
    }

    switch (action) {
      case "send":
        if (!phone) {
          return Response.json(
            { error: "Missing 'phone' field" },
            { status: 400, headers: CORS_HEADERS },
          );
        }
        return await handleSend(phone);

      case "verify":
        if (!phone) {
          return Response.json(
            { error: "Missing 'phone' field" },
            { status: 400, headers: CORS_HEADERS },
          );
        }
        return await handleVerify(phone, otp ?? "");

      case "refresh":
        return await handleRefresh(refreshToken ?? "");

      case "logout":
        return await handleLogout(refreshToken ?? "");

      default:
        return Response.json(
          { error: `Unknown action: ${action}` },
          { status: 400, headers: CORS_HEADERS },
        );
    }
  } catch (error: unknown) {
    console.error("WhatsApp OTP error:", error);
    return Response.json(
      { error: getErrorMessage(error) },
      { status: 500, headers: CORS_HEADERS },
    );
  }
});
