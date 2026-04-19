// FANZONE — WhatsApp Cloud API OTP Edge Function
//
// Custom OTP pipeline using WhatsApp Business Cloud API.
// Template: "gikundiro" (Authentication template)
//
// Actions:
//   POST { action: "send", phone: "+356..." }
//     → Generate OTP, store hash, send via WhatsApp Cloud API
//
//   POST { action: "verify", phone: "+356...", otp: "123456" }
//     → Verify OTP, create/find Supabase user, return session JWT
//
// Required secrets:
//   WABA_ACCESS_TOKEN       — WhatsApp Business API token
//   WABA_PHONE_NUMBER_ID    — WhatsApp Business phone number ID
//   SUPABASE_URL            — Supabase project URL
//   SUPABASE_SERVICE_ROLE_KEY — Service role key for admin operations
//   SUPABASE_ANON_KEY       — Anon key for session creation
//
// Optional:
//   WABA_OTP_TEMPLATE_NAME  — Template name (default: "gikundiro")
//   OTP_EXPIRY_SECONDS      — OTP validity in seconds (default: 600)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import {
  buildCorsHeaders,
  getErrorMessage,
} from "../_shared/http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const WABA_ACCESS_TOKEN = Deno.env.get("WABA_ACCESS_TOKEN")?.trim() || "";
const WABA_PHONE_NUMBER_ID = Deno.env.get("WABA_PHONE_NUMBER_ID")?.trim() || "";
const WABA_TEMPLATE_NAME = Deno.env.get("WABA_OTP_TEMPLATE_NAME")?.trim() || "gikundiro";
const OTP_EXPIRY_SECONDS = parseInt(
  Deno.env.get("OTP_EXPIRY_SECONDS") || "600",
  10,
);

const MAX_OTP_ATTEMPTS = 5;
const RATE_LIMIT_WINDOW_SECONDS = 60;

const CORS_HEADERS = buildCorsHeaders("authorization, content-type, apikey");

// ── Helpers ──

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

async function hashOtp(otp: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(otp);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function verifyOtpHash(otp: string, hash: string): Promise<boolean> {
  const computed = await hashOtp(otp);
  // Constant-time comparison
  if (computed.length !== hash.length) return false;
  let result = 0;
  for (let i = 0; i < computed.length; i++) {
    result |= computed.charCodeAt(i) ^ hash.charCodeAt(i);
  }
  return result === 0;
}

// ── WhatsApp Cloud API ──

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
          parameters: [
            {
              type: "text",
              text: otp,
            },
          ],
        },
        {
          type: "button",
          sub_type: "url",
          index: "0",
          parameters: [
            {
              type: "text",
              text: otp,
            },
          ],
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

// ── JWT Generation ──

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

  const headerB64 = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify(header)),
  );
  const payloadB64 = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify(payload)),
  );

  const signingInput = `${headerB64}.${payloadB64}`;

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

  const sigB64 = base64UrlEncode(new Uint8Array(signature));
  return `${headerB64}.${payloadB64}.${sigB64}`;
}

async function generateSessionTokens(
  userId: string,
  phone: string,
  jwtSecret: string,
): Promise<{ access_token: string; expires_in: number; expires_at: number }> {
  const now = Math.floor(Date.now() / 1000);
  const expiresIn = 3600; // 1 hour
  const expiresAt = now + expiresIn;

  const accessTokenPayload = {
    aud: "authenticated",
    exp: expiresAt,
    iat: now,
    iss: `${SUPABASE_URL}/auth/v1`,
    sub: userId,
    phone: phone,
    role: "authenticated",
    session_id: crypto.randomUUID(),
    is_anonymous: false,
    app_metadata: {
      provider: "phone",
      providers: ["phone"],
    },
    user_metadata: {
      phone: phone,
      phone_verified: true,
    },
    amr: [{ method: "otp", timestamp: now }],
  };

  const access_token = await signJwt(accessTokenPayload, jwtSecret);

  return { access_token, expires_in: expiresIn, expires_at: expiresAt };
}

// ── Action: Send OTP ──

async function handleSend(
  phone: string,
): Promise<Response> {
  const normalized = normalizePhone(phone);

  if (!/^\+\d{7,15}$/.test(normalized)) {
    return Response.json(
      { error: "Invalid phone number format" },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Rate limiting: check recent OTPs for this phone
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

  // Generate and store OTP
  const otp = generateOtp();
  const otpHash = await hashOtp(otp);
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_SECONDS * 1000).toISOString();

  // Invalidate previous unverified OTPs for this phone
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

  // Send via WhatsApp Cloud API
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

// ── Action: Verify OTP ──

async function handleVerify(
  phone: string,
  otp: string,
): Promise<Response> {
  const normalized = normalizePhone(phone);

  if (!otp || otp.length !== 6 || !/^\d{6}$/.test(otp)) {
    return Response.json(
      { error: "OTP must be exactly 6 digits" },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Find the most recent unexpired, unverified OTP for this phone
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

  // Check attempt limit
  if (otpRecord.attempts >= MAX_OTP_ATTEMPTS) {
    // Mark as expired
    await supabase
      .from("otp_verifications")
      .update({ verified: true })
      .eq("id", otpRecord.id);

    return Response.json(
      { error: "Too many attempts. Please request a new code." },
      { status: 429, headers: CORS_HEADERS },
    );
  }

  // Increment attempts
  await supabase
    .from("otp_verifications")
    .update({ attempts: otpRecord.attempts + 1 })
    .eq("id", otpRecord.id);

  // Verify OTP hash
  const isValid = await verifyOtpHash(otp, otpRecord.otp_hash);

  if (!isValid) {
    const remaining = MAX_OTP_ATTEMPTS - otpRecord.attempts - 1;
    return Response.json(
      { error: `Invalid code. ${remaining} attempts remaining.` },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  // Mark OTP as verified
  await supabase
    .from("otp_verifications")
    .update({ verified: true })
    .eq("id", otpRecord.id);

  // Find or create user in Supabase Auth
  let userId: string | null = null;

  // Try to find existing user by phone
  const { data: existingUserId } = await supabase
    .rpc("find_auth_user_by_phone", { p_phone: normalized });

  if (existingUserId) {
    userId = existingUserId;

    // Ensure phone is confirmed
    await supabase.auth.admin.updateUserById(userId, {
      phone_confirm: true,
    });
  } else {
    // Create new user
    const { data: newUser, error: createError } =
      await supabase.auth.admin.createUser({
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

  // Generate session JWT
  const jwtSecret = Deno.env.get("SUPABASE_JWT_SECRET");

  if (!jwtSecret) {
    // Fallback: use signInWithPassword with temp password
    const tempPassword = crypto.randomUUID() + crypto.randomUUID();

    await supabase.auth.admin.updateUserById(userId, {
      password: tempPassword,
    });

    const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: signInData, error: signInError } =
      await anonClient.auth.signInWithPassword({
        phone: normalized,
        password: tempPassword,
      });

    // Rotate password to invalidate it
    await supabase.auth.admin.updateUserById(userId, {
      password: crypto.randomUUID() + crypto.randomUUID(),
    });

    if (signInError || !signInData.session) {
      return Response.json(
        { error: "Failed to create session" },
        { status: 500, headers: CORS_HEADERS },
      );
    }

    return Response.json({
      success: true,
      access_token: signInData.session.access_token,
      refresh_token: signInData.session.refresh_token,
      expires_in: signInData.session.expires_in,
      expires_at: signInData.session.expires_at,
      user: signInData.user,
    }, { headers: CORS_HEADERS });
  }

  // Preferred path: mint JWT directly
  const session = await generateSessionTokens(userId, normalized, jwtSecret);

  // Get user data
  const { data: userData } = await supabase.auth.admin.getUserById(userId);

  return Response.json({
    success: true,
    access_token: session.access_token,
    refresh_token: null,
    expires_in: session.expires_in,
    expires_at: session.expires_at,
    user: userData?.user || { id: userId, phone: normalized },
  }, { headers: CORS_HEADERS });
}

// ── Main handler ──

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
    const { action, phone, otp } = body;

    if (!action) {
      return Response.json(
        { error: "Missing 'action' field. Use 'send' or 'verify'." },
        { status: 400, headers: CORS_HEADERS },
      );
    }

    if (!phone) {
      return Response.json(
        { error: "Missing 'phone' field" },
        { status: 400, headers: CORS_HEADERS },
      );
    }

    switch (action) {
      case "send":
        return await handleSend(phone);

      case "verify":
        return await handleVerify(phone, otp);

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
