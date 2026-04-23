import {
  useSupabaseList,
  useSupabaseMutation,
} from "../../hooks/useSupabaseQuery";
import {
  adminEnvError,
  isSupabaseConfigured,
  supabase,
} from "../../lib/supabase";
import type {
  AuditLog,
  PlatformContentBlockRecord,
  PlatformFeatureChannelConfig,
  PlatformFeatureRecord,
} from "../../types";

export function usePlatformFeatures() {
  return useSupabaseList<PlatformFeatureRecord>(
    ["platform-features"],
    "admin_platform_features",
    {
      order: { column: "display_name", ascending: true },
    },
  );
}

export function usePlatformContentBlocks() {
  return useSupabaseList<PlatformContentBlockRecord>(
    ["platform-content-blocks"],
    "admin_platform_content_blocks",
    {
      order: { column: "sort_order", ascending: true },
    },
  );
}

export function usePlatformFeatureAuditLogs(limit = 12) {
  return useSupabaseList<AuditLog>(
    ["platform-feature-audit-logs", limit],
    "platform_feature_audit_logs",
    {
      order: { column: "created_at", ascending: false },
      limit,
    },
  );
}

export interface PlatformFeatureChannelInput
  extends Omit<PlatformFeatureChannelConfig, "channel"> {
  channel: "mobile" | "web";
}

export interface UpsertPlatformFeatureArgs {
  feature_key: string;
  display_name: string;
  description?: string | null;
  status: "active" | "inactive" | "hidden" | "beta" | "scheduled";
  is_enabled: boolean;
  navigation_group?: string | null;
  default_route_key?: string | null;
  admin_notes?: string | null;
  metadata?: Record<string, unknown>;
  auth_required: boolean;
  role_restrictions?: unknown;
  dependency_config?: Record<string, unknown>;
  rollout_config?: Record<string, unknown>;
  schedule_start_at?: string | null;
  schedule_end_at?: string | null;
  mobile_channel: PlatformFeatureChannelInput;
  web_channel: PlatformFeatureChannelInput;
}

function trimNullable(value?: string | null) {
  const next = value?.trim();
  return next ? next : null;
}

async function requireAdminSupabase() {
  if (!isSupabaseConfigured) {
    throw new Error(adminEnvError);
  }
  return supabase;
}

export function useUpsertPlatformFeature() {
  return useSupabaseMutation<UpsertPlatformFeatureArgs>({
    mutationFn: async (args) => {
      const client = await requireAdminSupabase();
      const now = new Date().toISOString();
      const featureKey = args.feature_key.trim().toLowerCase();

      const { error: featureError } = await client.from("platform_features").upsert(
        {
          feature_key: featureKey,
          display_name: args.display_name.trim(),
          description: trimNullable(args.description),
          status: args.status,
          is_enabled: args.is_enabled,
          navigation_group: trimNullable(args.navigation_group),
          default_route_key: trimNullable(args.default_route_key),
          admin_notes: trimNullable(args.admin_notes),
          metadata: args.metadata ?? {},
          updated_at: now,
        },
        { onConflict: "feature_key" },
      );

      if (featureError) {
        throw new Error(featureError.message);
      }

      const { error: ruleError } = await client
        .from("platform_feature_rules")
        .upsert(
          {
            feature_key: featureKey,
            auth_required: args.auth_required,
            role_restrictions: args.role_restrictions ?? [],
            dependency_config: args.dependency_config ?? {},
            rollout_config: args.rollout_config ?? {},
            schedule_start_at: args.schedule_start_at ?? null,
            schedule_end_at: args.schedule_end_at ?? null,
            updated_at: now,
          },
          { onConflict: "feature_key" },
        );

      if (ruleError) {
        throw new Error(ruleError.message);
      }

      const channels = [args.mobile_channel, args.web_channel].map((channel) => ({
        feature_key: featureKey,
        channel: channel.channel,
        is_visible: channel.is_visible,
        is_enabled: channel.is_enabled,
        show_in_navigation: channel.show_in_navigation,
        show_on_home: channel.show_on_home,
        sort_order: channel.sort_order,
        route_key: trimNullable(channel.route_key),
        entry_key: trimNullable(channel.entry_key),
        navigation_label: trimNullable(channel.navigation_label),
        placement_key: trimNullable(channel.placement_key),
        metadata: channel.metadata ?? {},
        updated_at: now,
      }));

      const { error: channelError } = await client
        .from("platform_feature_channels")
        .upsert(channels, { onConflict: "feature_key,channel" });

      if (channelError) {
        throw new Error(channelError.message);
      }

      return featureKey;
    },
    invalidateKeys: [
      ["platform-features"],
      ["platform-feature-audit-logs"],
    ],
    successMessage: "Platform feature saved.",
  });
}

export interface UpsertPlatformContentBlockArgs {
  block_key: string;
  block_type: string;
  title: string;
  content: Record<string, unknown>;
  target_channel: "mobile" | "web" | "both";
  is_active: boolean;
  sort_order: number;
  feature_key?: string | null;
  placement_key: string;
  metadata?: Record<string, unknown>;
}

export function useUpsertPlatformContentBlock() {
  return useSupabaseMutation<UpsertPlatformContentBlockArgs>({
    mutationFn: async (args) => {
      const client = await requireAdminSupabase();

      const { error } = await client.from("platform_content_blocks").upsert(
        {
          block_key: args.block_key.trim().toLowerCase(),
          block_type: args.block_type.trim().toLowerCase(),
          title: args.title.trim(),
          content: args.content,
          target_channel: args.target_channel,
          is_active: args.is_active,
          sort_order: args.sort_order,
          feature_key: trimNullable(args.feature_key),
          placement_key: args.placement_key.trim().toLowerCase(),
          metadata: args.metadata ?? {},
          updated_at: new Date().toISOString(),
        },
        { onConflict: "block_key" },
      );

      if (error) {
        throw new Error(error.message);
      }

      return args.block_key;
    },
    invalidateKeys: [
      ["platform-content-blocks"],
      ["platform-feature-audit-logs"],
    ],
    successMessage: "Content block saved.",
  });
}
