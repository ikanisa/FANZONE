import type { PlatformFeatureChannelConfig } from "../../types";

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

function trimNullable(value?: string | null) {
  const next = value?.trim();
  return next ? next : null;
}

export function buildPlatformFeaturePayload(args: UpsertPlatformFeatureArgs) {
  return {
    feature_key: args.feature_key.trim().toLowerCase(),
    display_name: args.display_name.trim(),
    description: trimNullable(args.description),
    status: args.status,
    is_enabled: args.is_enabled,
    navigation_group: trimNullable(args.navigation_group),
    default_route_key: trimNullable(args.default_route_key),
    admin_notes: trimNullable(args.admin_notes),
    metadata: args.metadata ?? {},
    auth_required: args.auth_required,
    role_restrictions: args.role_restrictions ?? [],
    dependency_config: args.dependency_config ?? {},
    rollout_config: args.rollout_config ?? {},
    schedule_start_at: args.schedule_start_at ?? null,
    schedule_end_at: args.schedule_end_at ?? null,
    mobile_channel: {
      channel: "mobile" as const,
      is_visible: args.mobile_channel.is_visible,
      is_enabled: args.mobile_channel.is_enabled,
      show_in_navigation: args.mobile_channel.show_in_navigation,
      show_on_home: args.mobile_channel.show_on_home,
      sort_order: args.mobile_channel.sort_order,
      route_key: trimNullable(args.mobile_channel.route_key),
      entry_key: trimNullable(args.mobile_channel.entry_key),
      navigation_label: trimNullable(args.mobile_channel.navigation_label),
      placement_key: trimNullable(args.mobile_channel.placement_key),
      metadata: args.mobile_channel.metadata ?? {},
    },
    web_channel: {
      channel: "web" as const,
      is_visible: args.web_channel.is_visible,
      is_enabled: args.web_channel.is_enabled,
      show_in_navigation: args.web_channel.show_in_navigation,
      show_on_home: args.web_channel.show_on_home,
      sort_order: args.web_channel.sort_order,
      route_key: trimNullable(args.web_channel.route_key),
      entry_key: trimNullable(args.web_channel.entry_key),
      navigation_label: trimNullable(args.web_channel.navigation_label),
      placement_key: trimNullable(args.web_channel.placement_key),
      metadata: args.web_channel.metadata ?? {},
    },
  };
}

export function buildPlatformContentBlockPayload(
  args: UpsertPlatformContentBlockArgs,
) {
  return {
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
  };
}
