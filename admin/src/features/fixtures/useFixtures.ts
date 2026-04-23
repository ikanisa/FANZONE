// FANZONE Admin — Fixtures Data Hooks
import {
  useSupabasePaginated,
  useRpcMutation,
  type AdminListQuery,
} from "../../hooks/useSupabaseQuery";
import type { Match } from "../../types";
import type { PaginationOpts } from "../../hooks/useSupabaseQuery";

/* ── Hooks ── */
export function useFixtures(
  pagination: PaginationOpts,
  filters?: { status?: string; search?: string },
) {
  return useSupabasePaginated<Match>(["fixtures", filters], "app_matches", {
    pagination,
    select: "*",
    filters: (query: AdminListQuery<Match>) => {
      let q = query;
      if (filters?.status && filters.status !== "all") {
        q = q.eq("status", filters.status);
      }
      if (filters?.search && filters.search.trim().length > 0) {
        const escaped = filters.search.trim().replaceAll(",", "\\,");
        q = q.or(
          `home_team.ilike.%${escaped}%,away_team.ilike.%${escaped}%,competition_name.ilike.%${escaped}%,competition_id.ilike.%${escaped}%,id.ilike.%${escaped}%`,
        );
      }
      return q;
    },
    order: { column: "date", ascending: false },
  });
}

export function useUpdateFixtureResult() {
  return useRpcMutation<{
    p_match_id: string;
    p_home_goals: number;
    p_away_goals: number;
  }>({
    fnName: "admin_update_match_result",
    invalidateKeys: [["fixtures"], ["prediction-fixtures"], ["prediction-kpis"]],
    successMessage: "Match result recorded and related predictions scored.",
  });
}
