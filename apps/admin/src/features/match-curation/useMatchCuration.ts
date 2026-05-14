import { supabase, isSupabaseConfigured, adminEnvError } from "../../lib/supabase";
import {
  useSupabaseList,
  useSupabaseMutation,
  useSupabasePaginated,
  type AdminListQuery,
} from "../../hooks/useSupabaseQuery";
import type { Match } from "../../types";
import type { PaginationOpts } from "../../hooks/useSupabaseQuery";

export interface CuratedMatch {
  id: string;
  match_id: string;
  country_code: string | null;
  venue_id: string | null;
  priority_score: number;
  reason: string | null;
  is_active: boolean;
  is_pool_eligible: boolean;
  starts_at: string | null;
  expires_at: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface CuratedMatchInput {
  match_id: string;
  country_code?: string | null;
  venue_id?: string | null;
  priority_score: number;
  curation_reason?: string | null;
  starts_at?: string | null;
  expires_at?: string | null;
  metadata?: Record<string, unknown>;
  is_active?: boolean;
  is_pool_eligible?: boolean;
}

export interface MatchStateInput {
  match_id: string;
  home_score?: number | null;
  away_score?: number | null;
  status: "scheduled" | "live" | "final" | "cancelled" | "postponed";
}

function throwMissingAdminEnv(): never {
  throw new Error(adminEnvError);
}

function cleanCountryCode(value?: string | null) {
  const next = value?.trim().toUpperCase() ?? "";
  return next.length > 0 ? next : null;
}

function cleanNullable(value?: string | null) {
  const next = value?.trim() ?? "";
  return next.length > 0 ? next : null;
}

export function useCuratedMatches(
  pagination: PaginationOpts,
  filters?: { search?: string; active?: string },
) {
  return useSupabasePaginated<CuratedMatch>(
    ["match-curation", filters],
    "curated_matches",
    {
      pagination,
      select: "*",
      filters: (query: AdminListQuery<CuratedMatch>) => {
        let q = query;
        if (filters?.active === "active") q = q.eq("is_active", true);
        if (filters?.active === "inactive") q = q.eq("is_active", false);
        if (filters?.search && filters.search.trim().length > 0) {
          const escaped = filters.search.trim().replaceAll(",", "\\,");
          q = q.or(
            `match_id.ilike.%${escaped}%,country_code.ilike.%${escaped}%,reason.ilike.%${escaped}%`,
          );
        }
        return q;
      },
      order: { column: "priority_score", ascending: false },
    },
  );
}

export function useCurationMatchOptions(search: string) {
  return useSupabaseList<Match>(
    ["match-curation-options", search],
    "app_matches",
    {
      select: "*",
      filters: (query: AdminListQuery<Match>) => {
        if (search.trim().length === 0) return query;
        const escaped = search.trim().replaceAll(",", "\\,");
        return query.or(
          `home_team.ilike.%${escaped}%,away_team.ilike.%${escaped}%,competition_name.ilike.%${escaped}%,competition_id.ilike.%${escaped}%,id.ilike.%${escaped}%`,
        );
      },
      order: { column: "date", ascending: true },
      limit: 30,
    },
  );
}

export function useCreateCuratedMatch() {
  return useSupabaseMutation<CuratedMatchInput>({
    mutationFn: async (input) => {
      if (!isSupabaseConfigured) return throwMissingAdminEnv();

      const { error } = await supabase.rpc("admin_curate_match_control", {
        p_match_id: input.match_id,
        p_country_code: cleanCountryCode(input.country_code),
        p_venue_id: cleanNullable(input.venue_id),
        p_priority_score: input.priority_score,
        p_reason: cleanNullable(input.curation_reason) ?? "",
        p_starts_at: cleanNullable(input.starts_at),
        p_expires_at: cleanNullable(input.expires_at),
        p_is_active: input.is_active ?? true,
        p_metadata: {
          ...(input.metadata ?? {}),
          pool_eligible: input.is_pool_eligible ?? false,
        },
      });

      if (error) throw new Error(error.message);
    },
    invalidateKeys: [["match-curation"], ["dashboard-kpis"]],
    successMessage: "Match curated for pool discovery.",
  });
}

export function useSetCuratedMatchActive() {
  return useSupabaseMutation<{ id: string; is_active: boolean }>({
    mutationFn: async ({ id, is_active }) => {
      if (!isSupabaseConfigured) return throwMissingAdminEnv();

      const { error } = await supabase.rpc("admin_set_curated_match_active", {
        p_curated_match_id: id,
        p_is_active: is_active,
      });

      if (error) throw new Error(error.message);
    },
    invalidateKeys: [["match-curation"], ["dashboard-kpis"]],
    successMessage: "Curation status updated.",
  });
}

export function useSetCuratedMatchPoolEligible() {
  return useSupabaseMutation<{ id: string; is_pool_eligible: boolean }>({
    mutationFn: async ({ id, is_pool_eligible }) => {
      if (!isSupabaseConfigured) return throwMissingAdminEnv();

      const { error } = await supabase.rpc("admin_set_curated_match_pool_eligible", {
        p_curated_match_id: id,
        p_is_pool_eligible: is_pool_eligible,
      });

      if (error) throw new Error(error.message);
    },
    invalidateKeys: [["match-curation"], ["dashboard-kpis"]],
    successMessage: "Pool eligibility updated.",
  });
}

export function useUpdateMatchState() {
  return useSupabaseMutation<MatchStateInput>({
    mutationFn: async (input) => {
      if (!isSupabaseConfigured) return throwMissingAdminEnv();

      const { error } = await supabase.rpc("update_match_live_score", {
        p_match_id: input.match_id,
        p_home_score: input.home_score ?? null,
        p_away_score: input.away_score ?? null,
        p_status: input.status,
        p_source: "admin_curation",
      });

      if (error) throw new Error(error.message);
    },
    invalidateKeys: [["match-curation"], ["match-curation-options"], ["pool-operations"], ["dashboard-kpis"]],
    successMessage: "Match state updated.",
  });
}
