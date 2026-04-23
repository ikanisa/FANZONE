import { useQuery } from "@tanstack/react-query";

import type { PaginationOpts, PaginatedResult } from "../../hooks/useSupabaseQuery";
import { countAdminRows } from "../../lib/adminData";
import { adminEnvError, isSupabaseConfigured, supabase } from "../../lib/supabase";

interface AppMatchRow {
  id: string;
  competition_id: string;
  competition_name: string | null;
  home_team: string;
  away_team: string;
  date: string;
  status: string;
}

interface ConsensusRow {
  match_id: string;
  total_predictions: number;
  home_pct: number | null;
  draw_pct: number | null;
  away_pct: number | null;
}

interface EngineRow {
  match_id: string;
  confidence_label: string;
  home_win_score: number;
  draw_score: number;
  away_win_score: number;
  generated_at: string;
}

export interface PredictionFixtureSurface {
  id: string;
  match_id: string;
  match_name: string;
  competition_name: string;
  status: string;
  predictions_count: number;
  closes_at: string;
  confidence_label: string | null;
  engine_status: "ready" | "missing";
  top_result_code: string | null;
  consensus_home_pct: number | null;
  consensus_draw_pct: number | null;
  consensus_away_pct: number | null;
}

export interface PredictionKpis {
  openFixtures: number;
  totalPredictions24h: number;
  pendingSettlement: number;
  settledToday: number;
}

function topResultCode(row: EngineRow | undefined): string | null {
  if (!row) return null;
  if (row.home_win_score >= row.draw_score && row.home_win_score >= row.away_win_score) {
    return "H";
  }
  if (row.away_win_score >= row.home_win_score && row.away_win_score >= row.draw_score) {
    return "A";
  }
  return "D";
}

export function usePredictionFixtures(
  pagination: PaginationOpts,
  filters?: { status?: string; search?: string },
) {
  const pageSize = pagination.pageSize ?? 25;
  const from = pagination.page * pageSize;
  const to = from + pageSize - 1;

  return useQuery<PaginatedResult<PredictionFixtureSurface>>({
    queryKey: ["prediction-fixtures", pagination.page, pageSize, filters?.status, filters?.search],
    queryFn: async () => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      let query = supabase
        .from("app_matches")
        .select("id, competition_id, competition_name, home_team, away_team, date, status", {
          count: "exact",
        });

      if (filters?.status && filters.status !== "all") {
        query = query.eq("status", filters.status);
      }

      if (filters?.search && filters.search.trim().length > 0) {
        const escaped = filters.search.trim().replaceAll(",", "\\,");
        query = query.or(
          `home_team.ilike.%${escaped}%,away_team.ilike.%${escaped}%,competition_name.ilike.%${escaped}%,competition_id.ilike.%${escaped}%,id.ilike.%${escaped}%`,
        );
      }

      const { data, error, count } = await query
        .order("date", { ascending: false })
        .range(from, to);

      if (error) {
        throw new Error(error.message);
      }

      const matches = (data ?? []) as AppMatchRow[];
      const matchIds = matches.map((match) => match.id);

      let consensusRows: ConsensusRow[] = [];
      let engineRows: EngineRow[] = [];

      if (matchIds.length > 0) {
        const [{ data: consensusData, error: consensusError }, { data: engineData, error: engineError }] =
          await Promise.all([
            supabase
              .from("match_prediction_consensus")
              .select("match_id, total_predictions, home_pct, draw_pct, away_pct")
              .in("match_id", matchIds),
            supabase
              .from("predictions_engine_outputs")
              .select("match_id, confidence_label, home_win_score, draw_score, away_win_score, generated_at")
              .in("match_id", matchIds),
          ]);

        if (consensusError) {
          throw new Error(consensusError.message);
        }
        if (engineError) {
          throw new Error(engineError.message);
        }

        consensusRows = (consensusData ?? []) as ConsensusRow[];
        engineRows = (engineData ?? []) as EngineRow[];
      }

      const consensusByMatch = new Map(consensusRows.map((row) => [row.match_id, row]));
      const engineByMatch = new Map(engineRows.map((row) => [row.match_id, row]));

      const merged = matches.map<PredictionFixtureSurface>((match) => {
        const consensus = consensusByMatch.get(match.id);
        const engine = engineByMatch.get(match.id);

        return {
          id: match.id,
          match_id: match.id,
          match_name: `${match.home_team} vs ${match.away_team}`,
          competition_name: match.competition_name ?? match.competition_id,
          status: match.status,
          predictions_count: consensus?.total_predictions ?? 0,
          closes_at: match.date,
          confidence_label: engine?.confidence_label ?? null,
          engine_status: engine ? "ready" : "missing",
          top_result_code: topResultCode(engine),
          consensus_home_pct: consensus?.home_pct ?? null,
          consensus_draw_pct: consensus?.draw_pct ?? null,
          consensus_away_pct: consensus?.away_pct ?? null,
        };
      });

      return {
        data: merged,
        count: count ?? 0,
        page: pagination.page,
        pageSize,
      };
    },
    refetchInterval: 120_000,
  });
}

export function usePredictionKpis() {
  return useQuery<PredictionKpis>({
    queryKey: ["prediction-kpis"],
    queryFn: async () => {
      const now = new Date();
      const last24h = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();

      const [openFixtures, recentPredictions, pendingSettlement, settledToday] = await Promise.all([
        countAdminRows("matches", (query) =>
          query.gte("match_date", now.toISOString()).eq("match_status", "scheduled"),
        ),
        countAdminRows("user_predictions", (query) => query.gte("created_at", last24h)),
        countAdminRows("user_predictions", (query) => query.eq("reward_status", "pending")),
        countAdminRows("user_predictions", (query) =>
          query.eq("reward_status", "awarded").gte("updated_at", startOfDay),
        ),
      ]);

      return {
        openFixtures,
        totalPredictions24h: recentPredictions,
        pendingSettlement,
        settledToday,
      };
    },
    refetchInterval: 120_000,
  });
}
