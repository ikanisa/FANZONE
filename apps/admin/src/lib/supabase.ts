// FANZONE Admin — Supabase Clients
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { env } from "../config/env";

export const adminEnvError =
  "Admin environment is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to enable WhatsApp OTP sign-in.";

type AdminSupabaseClient = SupabaseClient;

export interface AdminSessionSnapshot {
  accessToken?: string | null;
  refreshToken?: string | null;
  userId: string;
  expiresAt: number;
  refreshExpiresAt: number;
  phone?: string | null;
}

export const isSupabaseConfigured = Boolean(
  env.supabaseUrl && env.supabaseAnonKey,
);

const ADMIN_SESSION_STORAGE_KEY = "fanzone-admin-session";

let supabaseClient: AdminSupabaseClient | null = null;
let supabaseAuthClient: AdminSupabaseClient | null = null;
let activeAdminSession: AdminSessionSnapshot | null = null;

const configuredSessionMode = (
  import.meta.env.VITE_PRIVILEGED_SESSION_MODE || ""
)
  .toString()
  .toLowerCase();

export const privilegedSessionMode =
  configuredSessionMode === "browser"
    ? "browser"
    : configuredSessionMode === "bff"
      ? "bff"
      : import.meta.env.PROD
        ? "bff"
        : "browser";

export const isBffSessionMode = privilegedSessionMode === "bff";

interface BffAuthPayload {
  success?: boolean;
  authenticated?: boolean;
  error?: string;
  message?: string;
  expires_at?: number;
  refresh_expires_at?: number;
  user?: {
    id?: string;
    phone?: string | null;
  } | null;
}

function clearLegacyBrowserSession() {
  if (typeof window === "undefined") {
    return;
  }
  try {
    window.localStorage?.removeItem(ADMIN_SESSION_STORAGE_KEY);
  } catch {
    // Best-effort cleanup for locked-down browser storage.
  }
  try {
    window.sessionStorage?.removeItem(ADMIN_SESSION_STORAGE_KEY);
  } catch {
    // Best-effort cleanup for locked-down browser storage.
  }
}

export function isAdminSessionExpired(session: AdminSessionSnapshot | null) {
  if (!session) return true;
  return session.expiresAt <= Math.floor(Date.now() / 1000);
}

export function isAdminRefreshExpired(session: AdminSessionSnapshot | null) {
  if (!session) return true;
  return session.refreshExpiresAt <= Math.floor(Date.now() / 1000);
}

export function readStoredAdminSession(): AdminSessionSnapshot | null {
  clearLegacyBrowserSession();
  if (!activeAdminSession || isAdminRefreshExpired(activeAdminSession)) {
    activeAdminSession = null;
    return null;
  }
  return activeAdminSession;
}

function adminSessionFromBffPayload(
  payload: BffAuthPayload | null,
): AdminSessionSnapshot | null {
  if (!payload || payload.authenticated === false) return null;
  if (!payload.user?.id || !payload.expires_at || !payload.refresh_expires_at) {
    return null;
  }

  return {
    accessToken: null,
    refreshToken: null,
    userId: payload.user.id,
    expiresAt: payload.expires_at,
    refreshExpiresAt: payload.refresh_expires_at,
    phone: payload.user.phone ?? null,
  };
}

async function fetchBffJson<T>(
  path: string,
  init: RequestInit = {},
): Promise<{ data: T | null; error: Error | null }> {
  const response = await fetch(path, {
    ...init,
    credentials: "same-origin",
    headers: {
      accept: "application/json",
      ...(init.body ? { "content-type": "application/json" } : {}),
      ...init.headers,
    },
  });
  let payload: T | null = null;
  try {
    payload = (await response.json()) as T;
  } catch {
    payload = null;
  }

  if (!response.ok) {
    const message =
      typeof payload === "object" &&
      payload &&
      "error" in payload &&
      typeof payload.error === "string"
        ? payload.error
        : "BFF request failed.";
    return { data: payload, error: new Error(message) };
  }

  return { data: payload, error: null };
}

export async function readCurrentAdminSession(): Promise<AdminSessionSnapshot | null> {
  if (!isBffSessionMode) {
    return readStoredAdminSession();
  }

  const { data, error } =
    await fetchBffJson<BffAuthPayload>("/api/auth/session");
  if (error) {
    activeAdminSession = null;
    return null;
  }

  const session = adminSessionFromBffPayload(data);
  activeAdminSession = session;
  return session;
}

export async function invokeAdminAuthAction<T>(
  body: Record<string, unknown>,
): Promise<{ data: T | null; error: Error | null }> {
  if (!isBffSessionMode) {
    const { data, error } = await getSupabaseAuthClient().functions.invoke<T>(
      "whatsapp-otp",
      { body },
    );
    return {
      data: data ?? null,
      error:
        error instanceof Error
          ? error
          : error
            ? new Error(error.message)
            : null,
    };
  }

  return fetchBffJson<T>("/api/auth/whatsapp-otp", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

export function persistAdminSession(session: AdminSessionSnapshot) {
  clearLegacyBrowserSession();
  activeAdminSession = session;
}

export function clearStoredAdminSession() {
  activeAdminSession = null;
  clearLegacyBrowserSession();
}

export function createScopedSupabaseClient(
  accessToken?: string | null,
): AdminSupabaseClient {
  const supabaseUrl =
    isBffSessionMode && typeof window !== "undefined"
      ? `${window.location.origin}/api/supabase`
      : env.supabaseUrl;

  return createClient(supabaseUrl, env.supabaseAnonKey, {
    accessToken: async () =>
      isBffSessionMode
        ? null
        : (accessToken ?? readStoredAdminSession()?.accessToken ?? null),
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
    global: isBffSessionMode
      ? {
          fetch: (input, init) =>
            fetch(input, { ...init, credentials: "same-origin" }),
        }
      : undefined,
  });
}

function createSupabaseBrowserClient(): AdminSupabaseClient {
  return createScopedSupabaseClient();
}

function createSupabaseAuthClient(): AdminSupabaseClient {
  return createClient(env.supabaseUrl, env.supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
}

export function getSupabaseClient(): AdminSupabaseClient {
  if (!isSupabaseConfigured) {
    throw new Error(adminEnvError);
  }

  supabaseClient ??= createSupabaseBrowserClient();
  return supabaseClient;
}

export function getSupabaseAuthClient(): AdminSupabaseClient {
  if (!isSupabaseConfigured) {
    throw new Error(adminEnvError);
  }

  supabaseAuthClient ??= createSupabaseAuthClient();
  return supabaseAuthClient;
}

export const supabase: AdminSupabaseClient = new Proxy(
  {} as AdminSupabaseClient,
  {
    get(_target, property, receiver) {
      const client = getSupabaseClient();
      const value = Reflect.get(client, property, receiver);
      return typeof value === "function" ? value.bind(client) : value;
    },
  },
);

export const supabaseAuth: AdminSupabaseClient = new Proxy(
  {} as AdminSupabaseClient,
  {
    get(_target, property, receiver) {
      const client = getSupabaseAuthClient();
      const value = Reflect.get(client, property, receiver);
      return typeof value === "function" ? value.bind(client) : value;
    },
  },
);
