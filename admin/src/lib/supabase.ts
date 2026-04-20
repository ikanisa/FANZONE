// FANZONE Admin — Supabase Clients
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { env } from '../config/env';

export const adminEnvError =
  'Admin environment is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to enable WhatsApp OTP sign-in.';

type AdminSupabaseClient = SupabaseClient;

export interface AdminSessionSnapshot {
  accessToken: string;
  refreshToken: string;
  userId: string;
  expiresAt: number;
  refreshExpiresAt: number;
  phone?: string | null;
}

export const isSupabaseConfigured = Boolean(env.supabaseUrl && env.supabaseAnonKey);

const ADMIN_SESSION_STORAGE_KEY = 'fanzone-admin-session';

let supabaseClient: AdminSupabaseClient | null = null;
let supabaseAuthClient: AdminSupabaseClient | null = null;

function canUseLocalStorage() {
  return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined';
}

function isAdminSessionSnapshot(value: unknown): value is AdminSessionSnapshot {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.accessToken === 'string' &&
    candidate.accessToken.length > 0 &&
    typeof candidate.refreshToken === 'string' &&
    candidate.refreshToken.length > 0 &&
    typeof candidate.userId === 'string' &&
    candidate.userId.length > 0 &&
    typeof candidate.expiresAt === 'number' &&
    typeof candidate.refreshExpiresAt === 'number'
  );
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
  if (!canUseLocalStorage()) {
    return null;
  }

  const raw = window.localStorage.getItem(ADMIN_SESSION_STORAGE_KEY);
  if (!raw) {
    return null;
  }

  try {
    const parsed = JSON.parse(raw);
    if (!isAdminSessionSnapshot(parsed)) {
      clearStoredAdminSession();
      return null;
    }
    if (isAdminRefreshExpired(parsed)) {
      clearStoredAdminSession();
      return null;
    }
    return parsed;
  } catch {
    clearStoredAdminSession();
    return null;
  }
}

export function persistAdminSession(session: AdminSessionSnapshot) {
  if (!canUseLocalStorage()) {
    return;
  }
  window.localStorage.setItem(ADMIN_SESSION_STORAGE_KEY, JSON.stringify(session));
}

export function clearStoredAdminSession() {
  if (!canUseLocalStorage()) {
    return;
  }
  window.localStorage.removeItem(ADMIN_SESSION_STORAGE_KEY);
}

function createSupabaseBrowserClient(): AdminSupabaseClient {
  return createClient(
    env.supabaseUrl,
    env.supabaseAnonKey,
    {
      accessToken: async () => readStoredAdminSession()?.accessToken ?? null,
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
    },
  );
}

function createSupabaseAuthClient(): AdminSupabaseClient {
  return createClient(
    env.supabaseUrl,
    env.supabaseAnonKey,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
    },
  );
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
      return typeof value === 'function' ? value.bind(client) : value;
    },
  },
);

export const supabaseAuth: AdminSupabaseClient = new Proxy(
  {} as AdminSupabaseClient,
  {
    get(_target, property, receiver) {
      const client = getSupabaseAuthClient();
      const value = Reflect.get(client, property, receiver);
      return typeof value === 'function' ? value.bind(client) : value;
    },
  },
);
