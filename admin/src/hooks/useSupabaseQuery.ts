// FANZONE Admin — Generic Supabase + TanStack Query Wrapper
import { useQuery, useMutation, useQueryClient, type QueryKey } from '@tanstack/react-query';
import { adminEnvError, isSupabaseConfigured, supabase } from '../lib/supabase';
import { useToast } from './useToast';
import { PAGE_SIZE } from '../config/constants';

/* ── Types ── */
export interface PaginationOpts {
  page: number;
  pageSize?: number;
}

export interface PaginatedResult<T> {
  data: T[];
  count: number;
  page: number;
  pageSize: number;
}

interface QueryErrorLike {
  message: string;
}

interface QueryResponse<T> {
  data: T[] | null;
  error: QueryErrorLike | null;
  count?: number | null;
}

export interface AdminListQuery<T = Record<string, unknown>>
  extends PromiseLike<QueryResponse<T>> {
  eq(column: string, value: unknown): AdminListQuery<T>;
  or(filters: string): AdminListQuery<T>;
  ilike(column: string, pattern: string): AdminListQuery<T>;
  order(column: string, options?: { ascending?: boolean }): AdminListQuery<T>;
  range(from: number, to: number): AdminListQuery<T>;
  limit(count: number): AdminListQuery<T>;
}

function throwMissingAdminEnv(): never {
  throw new Error(adminEnvError);
}

/* ── Paginated Supabase Query ── */
export function useSupabasePaginated<T>(
  queryKey: QueryKey,
  table: string,
  opts: {
    pagination: PaginationOpts;
    select?: string;
    filters?: (query: AdminListQuery<T>) => AdminListQuery<T>;
    order?: { column: string; ascending?: boolean };
    enabled?: boolean;
  },
) {
  const { pagination, select = '*', filters, order, enabled = true } = opts;
  const ps = pagination.pageSize || PAGE_SIZE;
  const from = pagination.page * ps;
  const to = from + ps - 1;

  return useQuery<PaginatedResult<T>>({
    queryKey: [...queryKey, pagination.page, ps],
    queryFn: async (): Promise<PaginatedResult<T>> => {
      if (!isSupabaseConfigured) return throwMissingAdminEnv();

      let query = supabase.from(table).select(select, { count: 'exact' }) as unknown as AdminListQuery<T>;
      if (filters) query = filters(query);
      if (order) query = query.order(order.column, { ascending: order.ascending ?? false });
      query = query.range(from, to);

      const { data, error, count } = await query;
      if (error) throw new Error(error.message);
      return { data: (data ?? []) as T[], count: count ?? 0, page: pagination.page, pageSize: ps };
    },
    enabled,
  });
}

/* ── Simple Supabase Query (non-paginated) ── */
export function useSupabaseList<T>(
  queryKey: QueryKey,
  table: string,
  opts: {
    select?: string;
    filters?: (query: AdminListQuery<T>) => AdminListQuery<T>;
    order?: { column: string; ascending?: boolean };
    enabled?: boolean;
    limit?: number;
  },
) {
  const { select = '*', filters, order, enabled = true, limit } = opts;

  return useQuery<T[]>({
    queryKey,
    queryFn: async (): Promise<T[]> => {
      if (!isSupabaseConfigured) return throwMissingAdminEnv();

      let query = supabase.from(table).select(select) as unknown as AdminListQuery<T>;
      if (filters) query = filters(query);
      if (order) query = query.order(order.column, { ascending: order.ascending ?? false });
      if (limit) query = query.limit(limit);

      const { data, error } = await query;
      if (error) throw new Error(error.message);
      return (data ?? []) as T[];
    },
    enabled,
  });
}

/* ── RPC Call Query ── */
export function useSupabaseRpc<T>(
  queryKey: QueryKey,
  fnName: string,
  args: Record<string, unknown> = {},
  opts?: { enabled?: boolean },
) {
  const { enabled = true } = opts ?? {};

  return useQuery<T>({
    queryKey,
    queryFn: async (): Promise<T> => {
      if (!isSupabaseConfigured) return throwMissingAdminEnv();

      const { data, error } = await supabase.rpc(fnName, args);
      if (error) throw new Error(error.message);
      return data as T;
    },
    enabled,
  });
}

/* ── Mutation with toast + query invalidation ── */
export function useSupabaseMutation<TArgs, TResult = unknown>(opts: {
  mutationFn: (args: TArgs) => Promise<TResult>;
  invalidateKeys?: QueryKey[];
  successMessage?: string;
  errorMessage?: string;
}) {
  const queryClient = useQueryClient();
  const { addToast } = useToast();

  return useMutation<TResult, Error, TArgs>({
    mutationFn: opts.mutationFn,
    onSuccess: () => {
      if (opts.invalidateKeys) {
        opts.invalidateKeys.forEach(key => queryClient.invalidateQueries({ queryKey: key }));
      }
      if (opts.successMessage) {
        addToast('success', opts.successMessage);
      }
    },
    onError: (error) => {
      addToast('error', opts.errorMessage || error.message || 'Operation failed');
    },
  });
}

/* ── RPC Mutation shorthand ── */
export function useRpcMutation<TArgs extends Record<string, unknown>>(opts: {
  fnName: string;
  invalidateKeys?: QueryKey[];
  successMessage?: string;
  errorMessage?: string;
}) {
  return useSupabaseMutation<TArgs>({
    mutationFn: async (args: TArgs) => {
      if (!isSupabaseConfigured) return throwMissingAdminEnv();
      const { data, error } = await supabase.rpc(opts.fnName, args);
      if (error) throw new Error(error.message);
      return data;
    },
    invalidateKeys: opts.invalidateKeys,
    successMessage: opts.successMessage,
    errorMessage: opts.errorMessage,
  });
}
