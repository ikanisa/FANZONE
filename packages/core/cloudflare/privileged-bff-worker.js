const AUTH_PREFIX = "/api/auth";
const HEALTH_PATH = "/api/health";
const SUPABASE_PROXY_PREFIX = "/api/supabase";
const UNSAFE_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);
const TOKEN_REFRESH_LEAD_SECONDS = 45;

function jsonResponse(payload, init = {}) {
  const headers = new Headers(init.headers);
  headers.set("content-type", "application/json; charset=utf-8");
  headers.set("cache-control", "no-store");
  return new Response(JSON.stringify(payload), { ...init, headers });
}

function getSupabaseConfig(env) {
  const supabaseUrl = (env.SUPABASE_URL || env.VITE_SUPABASE_URL || "").replace(
    /\/$/,
    "",
  );
  const supabaseAnonKey =
    env.SUPABASE_ANON_KEY || env.VITE_SUPABASE_ANON_KEY || "";
  return { supabaseUrl, supabaseAnonKey };
}

function getRuntimeHealth(surface, env) {
  const { supabaseUrl, supabaseAnonKey } = getSupabaseConfig(env);
  const cookiePrefix = env.FANZONE_BFF_COOKIE_PREFIX || `fz_${surface}`;

  return {
    ok: Boolean(supabaseUrl && supabaseAnonKey && cookiePrefix),
    surface,
    bff: true,
    supabaseUrlConfigured: Boolean(supabaseUrl),
    supabaseAnonKeyConfigured: Boolean(supabaseAnonKey),
    cookiePrefixConfigured: Boolean(cookiePrefix),
    privilegedSessionMode: "bff",
  };
}

function parseCookies(header) {
  const cookies = new Map();
  if (!header) return cookies;

  for (const part of header.split(";")) {
    const index = part.indexOf("=");
    if (index === -1) continue;
    const name = part.slice(0, index).trim();
    const value = part.slice(index + 1).trim();
    if (!name) continue;
    try {
      cookies.set(name, decodeURIComponent(value));
    } catch {
      cookies.set(name, value);
    }
  }

  return cookies;
}

function base64UrlEncode(value) {
  return btoa(value)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function base64UrlDecode(value) {
  const padded = value
    .replace(/-/g, "+")
    .replace(/_/g, "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  return atob(padded);
}

function decodeJwtPayload(token) {
  const [, payload] = token.split(".");
  if (!payload) return null;

  try {
    return JSON.parse(base64UrlDecode(payload));
  } catch {
    return null;
  }
}

function cookieNames(surface, env) {
  const prefix = env.FANZONE_BFF_COOKIE_PREFIX || `fz_${surface}`;
  return {
    access: `${prefix}_access`,
    refresh: `${prefix}_refresh`,
    meta: `${prefix}_meta`,
  };
}

function readSessionCookies(request, surface, env) {
  const names = cookieNames(surface, env);
  const cookies = parseCookies(request.headers.get("cookie"));
  const accessToken = cookies.get(names.access) || "";
  const refreshToken = cookies.get(names.refresh) || "";
  const metaCookie = cookies.get(names.meta) || "";
  let meta = null;

  if (metaCookie) {
    try {
      meta = JSON.parse(base64UrlDecode(metaCookie));
    } catch {
      meta = null;
    }
  }

  return { names, accessToken, refreshToken, meta };
}

function secureCookieFlag(request) {
  const hostname = new URL(request.url).hostname;
  return hostname === "localhost" || hostname === "127.0.0.1" ? "" : "; Secure";
}

function buildCookie(request, name, value, maxAgeSeconds) {
  const maxAge = Math.max(0, Math.floor(maxAgeSeconds));
  return [
    `${name}=${encodeURIComponent(value)}`,
    "Path=/api",
    `Max-Age=${maxAge}`,
    "HttpOnly",
    "SameSite=Strict",
    secureCookieFlag(request).replace(/^; /, ""),
  ]
    .filter(Boolean)
    .join("; ");
}

function clearCookie(request, name) {
  return buildCookie(request, name, "", 0);
}

function safeSessionMeta(payload, fallbackPhone) {
  const user = payload.user || null;
  const accessToken = payload.access_token || "";
  const jwtPayload = accessToken ? decodeJwtPayload(accessToken) : null;

  return {
    userId: user?.id || jwtPayload?.sub || "",
    phone: user?.phone || fallbackPhone || jwtPayload?.phone || null,
    expiresAt: Number(payload.expires_at || jwtPayload?.exp || 0),
    refreshExpiresAt: Number(payload.refresh_expires_at || 0),
  };
}

function sessionFromMeta(meta) {
  if (!meta?.userId || !meta?.expiresAt || !meta?.refreshExpiresAt) {
    return null;
  }

  return {
    authenticated: true,
    user: {
      id: meta.userId,
      phone: meta.phone ?? null,
    },
    expires_at: meta.expiresAt,
    refresh_expires_at: meta.refreshExpiresAt,
  };
}

function appendSessionCookies(
  response,
  request,
  surface,
  env,
  payload,
  fallbackPhone,
) {
  const names = cookieNames(surface, env);
  const now = Math.floor(Date.now() / 1000);
  const meta = safeSessionMeta(payload, fallbackPhone);
  const accessToken = payload.access_token || "";
  const refreshToken = payload.refresh_token || "";

  if (
    !accessToken ||
    !refreshToken ||
    !meta.userId ||
    !meta.expiresAt ||
    !meta.refreshExpiresAt
  ) {
    return response;
  }

  response.headers.append(
    "set-cookie",
    buildCookie(request, names.access, accessToken, meta.expiresAt - now),
  );
  response.headers.append(
    "set-cookie",
    buildCookie(
      request,
      names.refresh,
      refreshToken,
      meta.refreshExpiresAt - now,
    ),
  );
  response.headers.append(
    "set-cookie",
    buildCookie(
      request,
      names.meta,
      base64UrlEncode(JSON.stringify(meta)),
      meta.refreshExpiresAt - now,
    ),
  );

  return response;
}

function appendClearSessionCookies(response, request, surface, env) {
  const names = cookieNames(surface, env);
  response.headers.append("set-cookie", clearCookie(request, names.access));
  response.headers.append("set-cookie", clearCookie(request, names.refresh));
  response.headers.append("set-cookie", clearCookie(request, names.meta));
  return response;
}

function stripTokens(payload) {
  if (!payload || typeof payload !== "object") return payload;
  const next = { ...payload };
  delete next.access_token;
  delete next.refresh_token;
  return next;
}

function hasSameOrigin(request) {
  const url = new URL(request.url);
  const origin = request.headers.get("origin");
  if (origin) return origin === url.origin;

  const referer = request.headers.get("referer");
  if (!referer) return true;

  try {
    return new URL(referer).origin === url.origin;
  } catch {
    return false;
  }
}

function enforceSameOrigin(request) {
  if (!UNSAFE_METHODS.has(request.method)) return null;
  if (hasSameOrigin(request)) return null;
  return jsonResponse(
    { success: false, error: "Cross-origin request blocked." },
    { status: 403 },
  );
}

async function callWhatsAppOtp(env, body) {
  const { supabaseUrl, supabaseAnonKey } = getSupabaseConfig(env);
  if (!supabaseUrl || !supabaseAnonKey) {
    return {
      status: 500,
      payload: {
        success: false,
        error: "BFF Supabase runtime environment is not configured.",
      },
    };
  }

  const response = await fetch(`${supabaseUrl}/functions/v1/whatsapp-otp`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      apikey: supabaseAnonKey,
      authorization: `Bearer ${supabaseAnonKey}`,
    },
    body: JSON.stringify(body),
  });

  let payload = null;
  try {
    payload = await response.json();
  } catch {
    payload = {
      success: false,
      error: response.ok
        ? "Invalid auth response."
        : "Auth service request failed.",
    };
  }

  return { status: response.status, payload };
}

async function refreshSession(request, surface, env) {
  const { refreshToken, meta } = readSessionCookies(request, surface, env);
  if (!refreshToken) return null;

  const now = Math.floor(Date.now() / 1000);
  if (meta?.refreshExpiresAt && Number(meta.refreshExpiresAt) <= now) {
    return null;
  }

  const result = await callWhatsAppOtp(env, {
    action: "refresh",
    refresh_token: refreshToken,
  });

  if (result.status >= 400 || result.payload?.success !== true) {
    return null;
  }

  return result.payload;
}

async function resolveAccessToken(request, surface, env) {
  const session = readSessionCookies(request, surface, env);
  const now = Math.floor(Date.now() / 1000);
  const accessExp = session.meta?.expiresAt
    ? Number(session.meta.expiresAt)
    : Number(decodeJwtPayload(session.accessToken)?.exp || 0);

  if (session.accessToken && accessExp > now + TOKEN_REFRESH_LEAD_SECONDS) {
    return { accessToken: session.accessToken, refreshedPayload: null };
  }

  const refreshedPayload = await refreshSession(request, surface, env);
  if (!refreshedPayload?.access_token) {
    return { accessToken: "", refreshedPayload: null };
  }

  return {
    accessToken: refreshedPayload.access_token,
    refreshedPayload,
  };
}

async function handleAuth(request, surface, env) {
  const sameOriginError = enforceSameOrigin(request);
  if (sameOriginError) return sameOriginError;

  const url = new URL(request.url);
  if (url.pathname === `${AUTH_PREFIX}/session` && request.method === "GET") {
    const session = readSessionCookies(request, surface, env);
    const now = Math.floor(Date.now() / 1000);

    if (
      session.meta?.refreshExpiresAt &&
      Number(session.meta.refreshExpiresAt) <= now
    ) {
      return appendClearSessionCookies(
        jsonResponse({ authenticated: false }),
        request,
        surface,
        env,
      );
    }

    if (
      session.meta?.expiresAt &&
      Number(session.meta.expiresAt) <= now + TOKEN_REFRESH_LEAD_SECONDS &&
      session.refreshToken
    ) {
      const refreshed = await refreshSession(request, surface, env);
      if (refreshed?.success === true) {
        const response = jsonResponse({
          ...stripTokens(refreshed),
          authenticated: true,
        });
        return appendSessionCookies(response, request, surface, env, refreshed);
      }
    }

    const snapshot = sessionFromMeta(session.meta);
    return jsonResponse(snapshot ?? { authenticated: false });
  }

  if (
    url.pathname !== `${AUTH_PREFIX}/whatsapp-otp` ||
    request.method !== "POST"
  ) {
    return jsonResponse(
      { success: false, error: "Unknown auth route." },
      { status: 404 },
    );
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(
      { success: false, error: "Invalid JSON body." },
      { status: 400 },
    );
  }

  const action = String(body?.action || "");
  const upstreamBody = { ...body };

  if (action === "refresh" || action === "logout") {
    const session = readSessionCookies(request, surface, env);
    if (!session.refreshToken) {
      const response = jsonResponse(
        {
          success: false,
          error: "No active session.",
        },
        { status: 401 },
      );
      return appendClearSessionCookies(response, request, surface, env);
    }
    upstreamBody.refresh_token = session.refreshToken;
  }

  const result = await callWhatsAppOtp(env, upstreamBody);
  const payload = stripTokens(result.payload);
  const status = result.status;

  if (action === "logout") {
    return appendClearSessionCookies(
      jsonResponse(payload ?? { success: true }, { status }),
      request,
      surface,
      env,
    );
  }

  const response = jsonResponse(payload, { status });
  if (
    (action === "verify" || action === "refresh") &&
    result.payload?.success === true
  ) {
    return appendSessionCookies(
      response,
      request,
      surface,
      env,
      result.payload,
      body.phone,
    );
  }

  return response;
}

async function handleSupabaseProxy(request, surface, env) {
  const sameOriginError = enforceSameOrigin(request);
  if (sameOriginError) return sameOriginError;

  const { supabaseUrl, supabaseAnonKey } = getSupabaseConfig(env);
  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse(
      { error: "BFF Supabase runtime environment is not configured." },
      { status: 500 },
    );
  }

  const { accessToken, refreshedPayload } = await resolveAccessToken(
    request,
    surface,
    env,
  );
  if (!accessToken) {
    return appendClearSessionCookies(
      jsonResponse({ error: "No active session." }, { status: 401 }),
      request,
      surface,
      env,
    );
  }

  const url = new URL(request.url);
  const upstreamPath = url.pathname.slice(SUPABASE_PROXY_PREFIX.length) || "/";
  const upstreamUrl = `${supabaseUrl}${upstreamPath}${url.search}`;
  const headers = new Headers(request.headers);

  headers.delete("cookie");
  headers.delete("host");
  headers.set("apikey", supabaseAnonKey);
  headers.set("authorization", `Bearer ${accessToken}`);

  const upstreamRequest = new Request(upstreamUrl, {
    method: request.method,
    headers,
    body:
      request.method === "GET" || request.method === "HEAD"
        ? undefined
        : request.body,
    redirect: "manual",
  });

  const upstreamResponse = await fetch(upstreamRequest);
  if (request.headers.get("upgrade")?.toLowerCase() === "websocket") {
    return upstreamResponse;
  }

  const response = new Response(upstreamResponse.body, upstreamResponse);
  response.headers.delete("set-cookie");

  if (refreshedPayload) {
    appendSessionCookies(response, request, surface, env, refreshedPayload);
  }

  return response;
}

export function createPrivilegedBffWorker({ surface }) {
  return {
    async fetch(request, env) {
      const url = new URL(request.url);

      if (url.pathname === HEALTH_PATH) {
        const payload = getRuntimeHealth(surface, env);
        return jsonResponse(payload, { status: payload.ok ? 200 : 500 });
      }

      if (url.pathname.startsWith(AUTH_PREFIX)) {
        return handleAuth(request, surface, env);
      }

      if (url.pathname.startsWith(SUPABASE_PROXY_PREFIX)) {
        return handleSupabaseProxy(request, surface, env);
      }

      if (env.ASSETS?.fetch) {
        return env.ASSETS.fetch(request);
      }

      return new Response("Not found", { status: 404 });
    },
  };
}
