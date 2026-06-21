import {
  useRpcMutation,
  useSupabaseList,
  type AdminListQuery,
} from "../../hooks/useSupabaseQuery";

export interface GameContentRun {
  id: string;
  week_start: string;
  market_codes: string[];
  target_pack_count: number;
  questions_per_pack: number;
  generation_model: string | null;
  status: string;
  approved_pack_count: number;
  generated_pack_count: number;
  error_message: string | null;
  created_at: string;
  updated_at: string;
}

export interface GameContentPackSummary {
  id: string;
  generation_run_id: string | null;
  week_start: string;
  template_id: string;
  template_name: string;
  market_code: string;
  title: string;
  status: string;
  question_count: number;
  safety_labels: string[];
  review_notes: string | null;
  reviewed_at: string | null;
  approved_at: string | null;
  created_at: string;
  updated_at: string;
  assignment_count: number;
}

export interface VenueGameAssignmentSummary {
  id: string;
  venue_id: string;
  venue_name: string;
  market_code: string;
  pack_id: string;
  pack_title: string;
  template_id: string;
  template_name: string;
  week_start: string;
  assignment_rank: number;
  status: string;
  assignment_seed: string;
  override_reason: string | null;
  published_at: string | null;
  created_at: string;
  updated_at: string;
}

export function useGameContentRuns() {
  return useSupabaseList<GameContentRun>(
    ["game-content-runs"],
    "game_content_generation_runs",
    {
      order: { column: "created_at", ascending: false },
      limit: 25,
    },
  );
}

export function useGameContentPacks(filters: { weekStart?: string }) {
  return useSupabaseList<GameContentPackSummary>(
    ["game-content-packs", filters.weekStart],
    "admin_game_content_pack_summary",
    {
      filters: (query: AdminListQuery<GameContentPackSummary>) => {
        if (!filters.weekStart) return query;
        return query.eq("week_start", filters.weekStart);
      },
      order: { column: "created_at", ascending: false },
      limit: 100,
    },
  );
}

export function useVenueGameAssignments(filters: { weekStart?: string }) {
  return useSupabaseList<VenueGameAssignmentSummary>(
    ["venue-game-assignments", filters.weekStart],
    "admin_venue_game_assignment_summary",
    {
      filters: (query: AdminListQuery<VenueGameAssignmentSummary>) => {
        if (!filters.weekStart) return query;
        return query.eq("week_start", filters.weekStart);
      },
      order: { column: "assignment_rank", ascending: true },
      limit: 100,
    },
  );
}

export function useCreateGameContentRun() {
  return useRpcMutation<{
    p_week_start: string;
    p_market_codes: string[];
    p_target_pack_count: number;
    p_questions_per_pack: number;
    p_generation_model: string | null;
    p_prompt: string | null;
    p_metadata: Record<string, unknown>;
  }>({
    fnName: "admin_create_game_content_run",
    invalidateKeys: [["game-content-runs"]],
    successMessage: "Weekly game generation run queued.",
  });
}

export function useReviewGameContentPack() {
  return useRpcMutation<{
    p_pack_id: string;
    p_status: "approved" | "rejected" | "generated_pending_review" | "retired";
    p_review_notes: string | null;
  }>({
    fnName: "admin_set_game_content_pack_status",
    invalidateKeys: [["game-content-packs"], ["game-content-runs"]],
    successMessage: "Game pack review status saved.",
  });
}

export function useAssignWeeklyGamePacks() {
  return useRpcMutation<{
    p_week_start: string;
    p_market_codes: string[];
    p_packs_per_venue: number;
    p_seed: string | null;
  }>({
    fnName: "admin_assign_weekly_game_packs",
    invalidateKeys: [["venue-game-assignments"], ["game-content-packs"]],
    successMessage: "Approved weekly game packs assigned to venues.",
  });
}

export function useOverrideVenueGameAssignment() {
  return useRpcMutation<{
    p_assignment_id: string;
    p_status: "scheduled" | "published" | "overridden" | "retired";
    p_reason: string | null;
  }>({
    fnName: "admin_override_venue_game_assignment",
    invalidateKeys: [["venue-game-assignments"], ["game-content-packs"]],
    successMessage: "Venue game assignment updated.",
  });
}
