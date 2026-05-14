import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@fanzone/core";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || "";
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || "";

export const venueEnvError =
  "Venue environment is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to enable venue operations.";

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

type VenueSupabaseClient = SupabaseClient<Database>;

let supabaseClient: VenueSupabaseClient | null = null;
let supabaseAuthClient: VenueSupabaseClient | null = null;
let activeVenueSession: VenueSessionSnapshot | null = null;

const venueSessionStorageKey = "fanzone.venue.session.v1";

export interface VenueSessionSnapshot {
  accessToken?: string | null;
  refreshToken?: string | null;
  userId: string;
  expiresAt: number;
  refreshExpiresAt: number;
  phone: string;
}

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
  expires_at?: number;
  refresh_expires_at?: number;
  user?: {
    id?: string;
    phone?: string | null;
  } | null;
}

function clearLegacyBrowserSession() {
  if (typeof window === "undefined") return;
  try {
    window.localStorage?.removeItem(venueSessionStorageKey);
  } catch {
    // Best-effort cleanup for locked-down browser storage.
  }
  try {
    window.sessionStorage?.removeItem(venueSessionStorageKey);
  } catch {
    // Best-effort cleanup for locked-down browser storage.
  }
}

export function readStoredVenueSession(): VenueSessionSnapshot | null {
  clearLegacyBrowserSession();
  if (!activeVenueSession || isVenueRefreshExpired(activeVenueSession)) {
    activeVenueSession = null;
    return null;
  }
  return activeVenueSession;
}

function venueSessionFromBffPayload(
  payload: BffAuthPayload | null,
): VenueSessionSnapshot | null {
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
    phone: payload.user.phone ?? "",
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
    const errorPayload = payload as { error?: string } | null;
    return {
      data: payload,
      error: new Error(errorPayload?.error || "BFF request failed."),
    };
  }

  return { data: payload, error: null };
}

export async function readCurrentVenueSession(): Promise<VenueSessionSnapshot | null> {
  if (!isBffSessionMode) {
    return readStoredVenueSession();
  }

  const { data, error } =
    await fetchBffJson<BffAuthPayload>("/api/auth/session");
  if (error) {
    activeVenueSession = null;
    return null;
  }

  const session = venueSessionFromBffPayload(data);
  activeVenueSession = session;
  return session;
}

export async function invokeVenueAuthAction<T>(
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

export function persistVenueSession(session: VenueSessionSnapshot) {
  clearLegacyBrowserSession();
  activeVenueSession = session;
}

export function clearStoredVenueSession() {
  activeVenueSession = null;
  clearLegacyBrowserSession();
}

export function isVenueSessionExpired(
  session: VenueSessionSnapshot,
  leadMs = 0,
) {
  return session.expiresAt * 1000 <= Date.now() + leadMs;
}

export function isVenueRefreshExpired(session: VenueSessionSnapshot) {
  return session.refreshExpiresAt * 1000 <= Date.now();
}

export function resetSupabaseClient() {
  supabaseClient = null;
}

function createVenueClient(): VenueSupabaseClient {
  const session = readStoredVenueSession();
  const clientUrl =
    isBffSessionMode && typeof window !== "undefined"
      ? `${window.location.origin}/api/supabase`
      : supabaseUrl;
  const headers =
    !isBffSessionMode && session && !isVenueSessionExpired(session)
      ? { Authorization: `Bearer ${session.accessToken}` }
      : undefined;

  return createClient<Database>(clientUrl, supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      storageKey: "fanzone-venue-data-auth",
    },
    global: isBffSessionMode
      ? {
          fetch: (input, init) =>
            fetch(input, { ...init, credentials: "same-origin" }),
        }
      : headers
        ? { headers }
        : undefined,
  });
}

export function getSupabaseClient(): VenueSupabaseClient {
  if (!isSupabaseConfigured) {
    throw new Error(venueEnvError);
  }

  supabaseClient ??= createVenueClient();
  return supabaseClient;
}

export function getSupabaseAuthClient(): VenueSupabaseClient {
  if (!isSupabaseConfigured) {
    throw new Error(venueEnvError);
  }

  supabaseAuthClient ??= createClient<Database>(supabaseUrl, supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      storageKey: "fanzone-venue-otp-auth",
    },
  });
  return supabaseAuthClient;
}

export const supabase: VenueSupabaseClient = new Proxy(
  {} as VenueSupabaseClient,
  {
    get(_target, property, receiver) {
      const client = getSupabaseClient();
      const value = Reflect.get(client, property, receiver);
      return typeof value === "function" ? value.bind(client) : value;
    },
  },
);
