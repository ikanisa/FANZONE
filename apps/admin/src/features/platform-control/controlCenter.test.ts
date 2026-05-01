import { describe, expect, it } from "vitest";

import {
  buildCuratedMatchMetadata,
  buildRewardRuleRpcArgs,
  buildWalletAdjustmentRpcArgs,
  requireAdminReason,
} from "./controlCenter";

describe("platform control center helpers", () => {
  it("requires explicit reasons for sensitive admin actions", () => {
    expect(() => requireAdminReason("short", "refunds")).toThrow(
      /at least 8 characters/,
    );
    expect(requireAdminReason("manual refund after cancelled match", "refunds")).toBe(
      "manual refund after cancelled match",
    );
  });

  it("normalizes reward rule RPC payloads by scope", () => {
    const payload = buildRewardRuleRpcArgs({
      scope: "country",
      countryId: " 6a56f000-0000-4000-9000-000000000001 ",
      venueId: "",
      welcomeFetAmount: 25.8,
      orderFetDefaultPercent: 4.5,
      poolCreatorRewardPerMember: 2.9,
      minQualifiedStake: 10.2,
      minQualifiedMembers: 3.8,
      isActive: true,
      reason: "country rollout reward policy",
    });

    expect(payload.p_scope).toBe("country");
    expect(payload.p_country_id).toBe("6a56f000-0000-4000-9000-000000000001");
    expect(payload.p_venue_id).toBeNull();
    expect(payload.p_welcome_fet_amount).toBe(25);
    expect(payload.p_pool_creator_reward_per_member).toBe(2);
    expect(payload.p_min_qualified_members).toBe(3);
  });

  it("rejects reward rule scope mismatches", () => {
    expect(() =>
      buildRewardRuleRpcArgs({
        scope: "venue",
        welcomeFetAmount: 0,
        orderFetDefaultPercent: 0,
        poolCreatorRewardPerMember: 0,
        minQualifiedStake: 0,
        minQualifiedMembers: 0,
        isActive: true,
        reason: "venue rule update",
      }),
    ).toThrow(/require a venue/);
  });

  it("builds wallet adjustment payloads with audited reasons", () => {
    const payload = buildWalletAdjustmentRpcArgs({
      userId: "00000000-0000-4000-9000-000000000001",
      amount: 12.9,
      direction: "debit",
      reason: "duplicate creator reward reversal",
      idempotencyKey: " admin-adjustment-test ",
    });

    expect(payload).toEqual({
      p_target_user_id: "00000000-0000-4000-9000-000000000001",
      p_amount_fet: 12,
      p_direction: "debit",
      p_reason: "duplicate creator reward reversal",
      p_idempotency_key: "admin-adjustment-test",
    });
  });

  it("serializes curated match visibility tags", () => {
    expect(
      buildCuratedMatchMetadata({
        global: true,
        country: false,
        venueRelevant: true,
        featured: true,
        hidden: false,
      }),
    ).toEqual({
      tags: ["global", "venue_relevant", "featured"],
      visibility: "global",
      featured: true,
      hidden: false,
    });
  });
});
