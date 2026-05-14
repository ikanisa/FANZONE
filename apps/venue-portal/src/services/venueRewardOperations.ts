import type { Json } from "@fanzone/core";
import { supabase } from "../lib/supabase";

export interface RewardConfig {
  venue_id?: string;
  reward_percent: number;
  reward_trigger: "paid" | "served";
  accepts_fet_spend: boolean;
  redemption_fet_per_currency: number | null;
  max_fet_spend_per_order: number | null;
  reward_campaign_active: boolean;
  platform_default_reward_percent?: number;
  platform_default_reward_trigger?: string;
}

export interface RewardSummary {
  order_earned_today_fet: number;
  order_spent_today_fet: number;
  pending_settlements_fet: number;
}

function asRecord(
  value: Json | null | undefined,
): Record<string, Json | undefined> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, Json | undefined>)
    : {};
}

function toNumber(value: unknown, fallback = 0): number {
  const parsed = Number(value ?? fallback);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function mapRewardConfig(
  value: Partial<RewardConfig> | Json | null | undefined,
): RewardConfig {
  const record = asRecord(value as Json);
  return {
    venue_id: typeof record.venue_id === "string" ? record.venue_id : undefined,
    reward_percent: toNumber(record.reward_percent, 10),
    reward_trigger: record.reward_trigger === "served" ? "served" : "paid",
    accepts_fet_spend: Boolean(record.accepts_fet_spend),
    redemption_fet_per_currency:
      record.redemption_fet_per_currency == null
        ? null
        : toNumber(record.redemption_fet_per_currency, 0),
    max_fet_spend_per_order:
      record.max_fet_spend_per_order == null
        ? null
        : toNumber(record.max_fet_spend_per_order, 0),
    reward_campaign_active: record.reward_campaign_active !== false,
    platform_default_reward_percent:
      record.platform_default_reward_percent == null
        ? undefined
        : toNumber(record.platform_default_reward_percent, 10),
    platform_default_reward_trigger:
      typeof record.platform_default_reward_trigger === "string"
        ? record.platform_default_reward_trigger
        : undefined,
  };
}

export async function fetchRewardConfig(
  venueId: string,
): Promise<RewardConfig> {
  const { data, error } = await supabase.rpc("get_venue_fet_reward_config", {
    p_venue_id: venueId,
  });

  if (error) {
    throw new Error(error.message ?? "Failed to load reward configuration.");
  }
  return mapRewardConfig(data);
}

export async function fetchRewardSummary(
  venueId: string,
): Promise<RewardSummary> {
  const { data, error } = await supabase.rpc("get_venue_fet_reward_summary", {
    p_venue_id: venueId,
  });

  if (error) throw new Error(error.message ?? "Failed to load reward summary.");
  const record = asRecord(data);
  return {
    order_earned_today_fet: toNumber(record.order_earned_today_fet),
    order_spent_today_fet: toNumber(record.order_spent_today_fet),
    pending_settlements_fet: toNumber(record.pending_settlements_fet),
  };
}

export async function saveRewardConfig(
  venueId: string,
  config: RewardConfig,
): Promise<RewardConfig> {
  const { data, error } = await supabase.rpc("update_venue_fet_reward_config", {
    p_venue_id: venueId,
    p_reward_percent: config.reward_percent,
    p_reward_trigger: config.reward_trigger,
    p_accepts_fet_spend: config.accepts_fet_spend,
    p_redemption_fet_per_currency: config.redemption_fet_per_currency,
    p_max_fet_spend_per_order: config.max_fet_spend_per_order,
    p_reward_campaign_active: config.reward_campaign_active,
  });

  if (error) {
    throw new Error(error.message ?? "Failed to save reward configuration.");
  }
  return mapRewardConfig(data);
}
