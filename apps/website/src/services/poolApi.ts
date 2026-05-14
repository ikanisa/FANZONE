import type { Match, MatchPoolEntrySummary, MatchPoolSummary } from "../types";
import { assertClientFeatureAvailable } from "../platform/access";
import {
  asString,
  ensureClient,
  maybeSingle,
  selectList,
  type JsonRecord,
} from "./apiClient";
import { normalizeMatchPoolRow, normalizePoolEntryRow } from "./apiMappers";
import { getLiveMatches, getUpcomingMatches } from "./matchApi";

export async function getOpenMatchPools(
  limit = 20,
): Promise<MatchPoolSummary[]> {
  const client = await ensureClient();
  if (!client) return [];

  try {
    const rows = await selectList<JsonRecord>(
      client
        .from("match_pool_stats")
        .select("*")
        .in("status", ["open", "locked", "live", "settling"])
        .order("created_at", { ascending: false })
        .limit(limit),
    );
    return rows.map(normalizeMatchPoolRow);
  } catch (error) {
    console.warn("Failed to load match pools", error);
    return [];
  }
}

export async function getMatchPools(
  matchId: string,
): Promise<MatchPoolSummary[]> {
  const client = await ensureClient();
  if (!client) return [];

  try {
    const rows = await selectList<JsonRecord>(
      client
        .from("match_pool_stats")
        .select("*")
        .eq("match_id", matchId)
        .in("status", ["open", "locked", "live", "settling", "settled"])
        .order("scope", { ascending: true })
        .order("created_at", { ascending: false }),
    );
    return rows.map(normalizeMatchPoolRow);
  } catch (error) {
    console.warn(`Failed to load pools for ${matchId}`, error);
    return [];
  }
}

export async function getMatchPoolBySlug(
  slug: string,
  inviteCode?: string | null,
  source: "direct" | "venue_qr" | "social_share" | "invite_link" = "direct",
): Promise<MatchPoolSummary | null> {
  const client = await ensureClient();
  if (!client) return null;

  try {
    const { data: shareData, error: shareError } = await client.rpc(
      "get_public_pool_share",
      {
        p_slug_or_pool_id: slug,
        p_invite_code: inviteCode ?? null,
        p_source: inviteCode ? "invite_link" : source,
      },
    );
    if (shareError) throw new Error(shareError.message);
    const resolvedPoolId = asString(
      ((shareData ?? {}) as { pool?: { id?: unknown } }).pool?.id,
    );
    if (!resolvedPoolId) return null;

    const row = await maybeSingle<JsonRecord>(
      client
        .from("match_pool_stats")
        .select("*")
        .eq("id", resolvedPoolId)
        .maybeSingle(),
    );
    return row ? normalizeMatchPoolRow(row) : null;
  } catch (error) {
    console.warn(`Failed to load pool ${slug}`, error);
    return null;
  }
}

export async function getPoolMatches(limit = 16): Promise<Match[]> {
  const [live, upcoming] = await Promise.all([
    getLiveMatches(Math.ceil(limit / 2)),
    getUpcomingMatches(limit),
  ]);
  const seen = new Set<string>();
  return [...live, ...upcoming]
    .filter((match) => {
      if (seen.has(match.id)) return false;
      seen.add(match.id);
      return true;
    })
    .slice(0, limit);
}

export async function getMyPools(limit = 50): Promise<MatchPoolEntrySummary[]> {
  const client = await ensureClient();
  if (!client) return [];

  try {
    const { data, error } = await client.rpc("get_my_pools", {
      p_limit: limit,
    });
    if (error) throw new Error(error.message);
    return ((data ?? []) as JsonRecord[]).map(normalizePoolEntryRow);
  } catch (error) {
    console.warn("Failed to load my pools", error);
    return [];
  }
}

export async function createPool(input: {
  matchId: string;
  scope: "global" | "country" | "venue";
  title: string;
  stakeMinFet: number;
  stakeMaxFet: number;
  venueId?: string | null;
  visibility?: "shareable" | "private" | "public";
}): Promise<{
  success: boolean;
  poolId?: string;
  shareUrl?: string | null;
  status?: string;
  endorsementStatus?: string | null;
  socialCardUrl?: string | null;
  error?: string;
}> {
  const client = await ensureClient();
  if (!client) {
    return {
      success: false,
      error: "Supabase is not configured for the website.",
    };
  }

  try {
    assertClientFeatureAvailable(
      "pools",
      "Match pools are currently unavailable.",
    );

    if (input.scope !== "venue" || !input.venueId) {
      return {
        success: false,
        error: "Choose the linked venue before creating a pool.",
      };
    }

    const { data, error } = await client.rpc("create_pool", {
      p_match_id: input.matchId,
      p_scope: "venue",
      p_country_id: null,
      p_venue_id: input.venueId,
      p_title: input.title.trim() || null,
      p_stake_min: input.stakeMinFet,
      p_stake_max: input.stakeMaxFet,
      p_creator_reward_per_qualified_member: 1,
      p_rules_json: {
        visibility: input.visibility ?? "shareable",
        is_official: false,
      },
      p_allow_multiple: false,
    });

    if (error) throw new Error(error.message);
    const row = (data ?? {}) as JsonRecord;
    const poolId = asString(row.pool_id);
    let socialCardUrl: string | null = null;

    if (poolId) {
      try {
        const generated = await generatePoolShareCard(poolId);
        socialCardUrl = generated.socialCardUrl ?? null;
      } catch (cardError) {
        console.warn(
          "Pool created but social card generation failed",
          cardError,
        );
      }
    }

    return {
      success: true,
      poolId,
      shareUrl: asString(row.share_url) || null,
      status: asString(row.status, "created"),
      endorsementStatus: asString(row.endorsement_status) || null,
      socialCardUrl,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Could not create pool.",
    };
  }
}

export async function generatePoolShareCard(poolId: string): Promise<{
  success: boolean;
  socialCardUrl?: string | null;
  error?: string;
}> {
  const client = await ensureClient();
  if (!client) {
    return {
      success: false,
      error: "Supabase is not configured for the website.",
    };
  }

  try {
    const { data, error } = await client.functions.invoke(
      "generate-pool-social-card",
      { body: { pool_id: poolId } },
    );
    if (error) throw new Error(error.message);
    const row = (data ?? {}) as JsonRecord;
    return {
      success: true,
      socialCardUrl:
        asString(row.social_card_url) || asString(row.socialCardUrl) || null,
    };
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "Could not generate social card.",
    };
  }
}

export async function createPoolInvite(poolId: string): Promise<{
  success: boolean;
  inviteCode?: string | null;
  shareUrl?: string | null;
  deepLinkUrl?: string | null;
  error?: string;
}> {
  const client = await ensureClient();
  if (!client) {
    return {
      success: false,
      error: "Supabase is not configured for the website.",
    };
  }

  try {
    const { data, error } = await client.rpc("create_match_pool_invite", {
      p_pool_id: poolId,
    });
    if (error) throw new Error(error.message);
    const row = (data ?? {}) as JsonRecord;
    return {
      success: true,
      inviteCode: asString(row.invite_code) || null,
      shareUrl: asString(row.share_url) || null,
      deepLinkUrl: asString(row.deep_link_url) || null,
    };
  } catch (error) {
    return {
      success: false,
      error:
        error instanceof Error
          ? error.message
          : "Could not create pool invite.",
    };
  }
}

export async function joinMatchPool(
  poolId: string,
  campId: string,
  amountFet?: number | null,
  inviteCode?: string | null,
  source: "direct" | "venue_qr" | "social_share" = "direct",
): Promise<{ success: boolean; error?: string }> {
  const client = await ensureClient();
  if (!client) {
    return {
      success: false,
      error: "Supabase is not configured for the website.",
    };
  }

  try {
    assertClientFeatureAvailable(
      "pools",
      "Match pools are currently unavailable.",
    );

    const { error } = await client.rpc("stake_fet", {
      p_pool_id: poolId,
      p_camp_id: campId,
      p_stake_amount: amountFet ?? null,
      p_source: inviteCode ? "invite_link" : source,
      p_invite_code: inviteCode ?? null,
    });

    if (error) throw new Error(error.message);
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Could not join pool.",
    };
  }
}
