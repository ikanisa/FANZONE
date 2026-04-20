import { adminEnvError, getSupabaseClient } from './supabase';
import type { AdminUser } from '../types';

interface AdminQueryErrorLike {
  message: string;
}

interface AdminCountResponse {
  count: number | null;
  error: AdminQueryErrorLike | null;
}

interface AdminRowsResponse<T> {
  data: T[] | null;
  error: AdminQueryErrorLike | null;
}

export interface AdminCountQuery extends PromiseLike<AdminCountResponse> {
  eq(column: string, value: unknown): AdminCountQuery;
  neq(column: string, value: unknown): AdminCountQuery;
  gte(column: string, value: unknown): AdminCountQuery;
  lte(column: string, value: unknown): AdminCountQuery;
  in(column: string, values: readonly unknown[]): AdminCountQuery;
}

export interface AdminRowsQuery<T = Record<string, unknown>>
  extends PromiseLike<AdminRowsResponse<T>> {
  eq(column: string, value: unknown): AdminRowsQuery<T>;
  neq(column: string, value: unknown): AdminRowsQuery<T>;
  gte(column: string, value: unknown): AdminRowsQuery<T>;
  lte(column: string, value: unknown): AdminRowsQuery<T>;
  ilike(column: string, pattern: string): AdminRowsQuery<T>;
  order(column: string, options?: { ascending?: boolean }): AdminRowsQuery<T>;
  limit(count: number): AdminRowsQuery<T>;
}

export function throwAdminEnvError(): never {
  throw new Error(adminEnvError);
}

export function requireAdminClient() {
  return getSupabaseClient();
}

export async function runAdminRpc<T>(
  fnName: string,
  args: Record<string, unknown> = {},
): Promise<T> {
  const { data, error } = await requireAdminClient().rpc(fnName, args);
  if (error) throw new Error(error.message);
  return data as T;
}

export async function fetchAdminMe(): Promise<AdminUser | null> {
  return runAdminRpc<AdminUser | null>('get_admin_me');
}

export async function countAdminRows(
  table: string,
  mutate?: (query: AdminCountQuery) => AdminCountQuery,
): Promise<number> {
  let query = requireAdminClient().from(table).select('id', {
    count: 'exact',
    head: true,
  }) as unknown as AdminCountQuery;
  if (mutate) query = mutate(query);

  const { count, error } = await query;
  if (error) throw new Error(error.message);
  return count ?? 0;
}

export async function fetchAdminRows<T>(
  table: string,
  mutate?: (query: AdminRowsQuery<T>) => AdminRowsQuery<T>,
): Promise<T[]> {
  let query = requireAdminClient().from(table).select('*') as unknown as AdminRowsQuery<T>;
  if (mutate) query = mutate(query);

  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return (data ?? []) as T[];
}
