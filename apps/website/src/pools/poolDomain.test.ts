import { describe, expect, it } from "vitest";

import {
  canPoolTransition,
  clampPoolStake,
  estimatePoolOutcome,
  getPoolJoinAvailability,
} from "@fanzone/core";

describe("pool domain model", () => {
  it("allows only the supported pool state transitions", () => {
    expect(canPoolTransition("draft", "open")).toBe(true);
    expect(canPoolTransition("open", "locked")).toBe(true);
    expect(canPoolTransition("locked", "settling")).toBe(true);
    expect(canPoolTransition("settling", "settled")).toBe(true);
    expect(canPoolTransition("settled", "open")).toBe(false);
    expect(canPoolTransition("cancelled", "open")).toBe(false);
  });

  it("only allows entries while a pool is open", () => {
    expect(getPoolJoinAvailability({ status: "open" })).toEqual({
      canJoin: true,
      reason: null,
    });
    expect(getPoolJoinAvailability({ status: "draft" })).toEqual({
      canJoin: false,
      reason: "This pool is waiting for venue endorsement.",
    });
    expect(getPoolJoinAvailability({ status: "locked" }).canJoin).toBe(false);
  });

  it("estimates outcome without overpromising a guaranteed return", () => {
    const estimate = estimatePoolOutcome(
      { totalStakedFet: 300 },
      { totalStakedFet: 100 },
      50,
    );

    expect(estimate.estimatedReturnIfSelectedCampWins).toBe(116);
    expect(estimate.estimatedProfitIfSelectedCampWins).toBe(66);
    expect(estimate.disclaimer).toContain("Estimate only");
  });

  it("clamps flexible stakes inside pool bounds and respects fixed entry fees", () => {
    expect(clampPoolStake(2, { entryFeeFet: 0, stakeMinFet: 5, stakeMaxFet: 50 })).toBe(5);
    expect(clampPoolStake(80, { entryFeeFet: 0, stakeMinFet: 5, stakeMaxFet: 50 })).toBe(50);
    expect(clampPoolStake(80, { entryFeeFet: 12, stakeMinFet: 5, stakeMaxFet: 50 })).toBe(12);
  });
});
