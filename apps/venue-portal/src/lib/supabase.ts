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

const venueSessionStorageKey = "fanzone.venue.session.v1";

export interface VenueSessionSnapshot {
  accessToken: string;
  refreshToken: string;
  userId: string;
  expiresAt: number;
  refreshExpiresAt: number;
  phone: string;
}

function storageAvailable() {
  return typeof window !== "undefined" &&
    typeof window.sessionStorage !== "undefined";
}

function clearLegacyLocalSession() {
  if (typeof window === "undefined" || !window.localStorage) return;
  window.localStorage.removeItem(venueSessionStorageKey);
}

export function readStoredVenueSession(): VenueSessionSnapshot | null {
  clearLegacyLocalSession();

  if (!storageAvailable()) return null;

  try {
    const raw = window.sessionStorage.getItem(venueSessionStorageKey);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<VenueSessionSnapshot>;
    if (
      typeof parsed.accessToken !== "string" ||
      typeof parsed.refreshToken !== "string" ||
      typeof parsed.userId !== "string" ||
      typeof parsed.expiresAt !== "number" ||
      typeof parsed.refreshExpiresAt !== "number"
    ) {
      return null;
    }

    return {
      accessToken: parsed.accessToken,
      refreshToken: parsed.refreshToken,
      userId: parsed.userId,
      expiresAt: parsed.expiresAt,
      refreshExpiresAt: parsed.refreshExpiresAt,
      phone: typeof parsed.phone === "string" ? parsed.phone : "",
    };
  } catch {
    return null;
  }
}

export function persistVenueSession(session: VenueSessionSnapshot) {
  clearLegacyLocalSession();

  if (!storageAvailable()) return;
  window.sessionStorage.setItem(venueSessionStorageKey, JSON.stringify(session));
}

export function clearStoredVenueSession() {
  clearLegacyLocalSession();

  if (!storageAvailable()) return;
  window.sessionStorage.removeItem(venueSessionStorageKey);
}

export function isVenueSessionExpired(session: VenueSessionSnapshot, leadMs = 0) {
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
  const headers =
    session && !isVenueSessionExpired(session)
      ? { Authorization: `Bearer ${session.accessToken}` }
      : undefined;

  return createClient<Database>(supabaseUrl, supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      storageKey: "fanzone-venue-data-auth",
    },
    global: headers ? { headers } : undefined,
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
