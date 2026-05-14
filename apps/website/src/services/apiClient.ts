import {
  ensureWebsiteSession,
  isSupabaseConfigured,
  supabase,
} from "../lib/supabase";

export type JsonRecord = Record<string, unknown>;

export function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number") return value;
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    if (!Number.isNaN(parsed)) return parsed;
  }
  return fallback;
}

export function asString(value: unknown, fallback = ""): string {
  if (typeof value === "string") return value;
  if (value == null) return fallback;
  return String(value);
}

export async function ensureClient() {
  if (!isSupabaseConfigured || !supabase) return null;
  await ensureWebsiteSession();
  return supabase;
}

export async function maybeSingle<T>(
  promise: PromiseLike<{ data: T | null; error: { message: string } | null }>,
) {
  const { data, error } = await promise;
  if (error) throw new Error(error.message);
  return data;
}

export async function selectList<T>(
  promise: PromiseLike<{ data: T[] | null; error: { message: string } | null }>,
) {
  const { data, error } = await promise;
  if (error) throw new Error(error.message);
  return data ?? [];
}
