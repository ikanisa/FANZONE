import type { MatchPool, MatchPoolCamp, MatchPoolStatus } from "./types";

export type PoolCampKey = "home" | "draw" | "away" | "custom";
export type PoolEntrySource =
  | "direct"
  | "invite_link"
  | "venue_qr"
  | "social_share";
export type PoolVisibility = "public" | "shareable" | "private";
export type VenuePoolEndorsementStatus = "not_required" | "pending" | "endorsed" | "rejected";

export const POOL_STATE_TRANSITIONS: Record<MatchPoolStatus, MatchPoolStatus[]> = {
  draft: ["open", "cancelled"],
  open: ["locked", "live", "cancelled"],
  locked: ["live", "settling", "cancelled"],
  live: ["settling", "cancelled"],
  settling: ["settled", "cancelled"],
  settled: [],
  cancelled: [],
};

export interface PoolOutcomeEstimate {
  stakeAmount: number;
  currentCampStake: number;
  currentPoolStake: number;
  estimatedReturnIfSelectedCampWins: number;
  estimatedProfitIfSelectedCampWins: number;
  disclaimer: string;
}

export interface PoolJoinAvailability {
  canJoin: boolean;
  reason: string | null;
}

export function canPoolTransition(
  from: MatchPoolStatus,
  to: MatchPoolStatus,
): boolean {
  return POOL_STATE_TRANSITIONS[from]?.includes(to) ?? false;
}

export function poolStatusLabel(status: MatchPoolStatus | string): string {
  switch (status) {
    case "draft":
      return "Pending";
    case "open":
      return "Open";
    case "locked":
      return "Locked";
    case "live":
      return "Live";
    case "settling":
      return "Settling";
    case "settled":
      return "Settled";
    case "cancelled":
      return "Cancelled";
    default:
      return status;
  }
}

export function getPoolJoinAvailability(pool: { status: MatchPoolStatus | string }): PoolJoinAvailability {
  if (pool.status !== "open") {
    return {
      canJoin: false,
      reason:
        pool.status === "draft"
          ? "This pool is waiting for venue endorsement."
          : "This pool is locked and no longer accepts stakes.",
    };
  }

  return { canJoin: true, reason: null };
}

export function fixedOrDefaultStake(pool: Pick<MatchPool, "entryFeeFet" | "stakeMinFet">): number {
  return pool.entryFeeFet > 0 ? pool.entryFeeFet : pool.stakeMinFet;
}

export function clampPoolStake(
  amount: number,
  pool: Pick<MatchPool, "entryFeeFet" | "stakeMinFet" | "stakeMaxFet">,
): number {
  if (pool.entryFeeFet > 0) return pool.entryFeeFet;
  const safeAmount = Number.isFinite(amount) ? amount : pool.stakeMinFet;
  return Math.min(Math.max(Math.round(safeAmount), pool.stakeMinFet), pool.stakeMaxFet);
}

export function estimatePoolOutcome(
  pool: Pick<MatchPool, "totalStakedFet">,
  camp: Pick<MatchPoolCamp, "totalStakedFet">,
  stakeAmount: number,
): PoolOutcomeEstimate {
  const stake = Math.max(0, Math.round(stakeAmount));
  const currentCampStake = Math.max(0, Math.round(camp.totalStakedFet));
  const currentPoolStake = Math.max(0, Math.round(pool.totalStakedFet));
  const selectedCampStakeAfterJoin = currentCampStake + stake;
  const losingStakeIfClosedNow = Math.max(currentPoolStake - currentCampStake, 0);
  const proRataLosingStake =
    selectedCampStakeAfterJoin > 0
      ? Math.floor((losingStakeIfClosedNow * stake) / selectedCampStakeAfterJoin)
      : 0;
  const estimatedReturnIfSelectedCampWins = stake + proRataLosingStake;

  return {
    stakeAmount: stake,
    currentCampStake,
    currentPoolStake,
    estimatedReturnIfSelectedCampWins,
    estimatedProfitIfSelectedCampWins: Math.max(
      estimatedReturnIfSelectedCampWins - stake,
      0,
    ),
    disclaimer:
      "Estimate only. Final settlement depends on future entries, cancellations, and the official final result.",
  };
}

export function inferCampKey(camp: Pick<MatchPoolCamp, "code" | "resultCode" | "label">): PoolCampKey {
  const code = camp.code.toLowerCase();
  if (code === "home" || camp.resultCode === "H") return "home";
  if (code === "draw" || camp.resultCode === "D") return "draw";
  if (code === "away" || camp.resultCode === "A") return "away";
  return "custom";
}
