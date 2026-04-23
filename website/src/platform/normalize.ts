import {
  DEFAULT_PLATFORM_BOOTSTRAP,
  type PlatformBootstrap,
  type PlatformContentBlock,
  type PlatformFeature,
  type PlatformFeatureChannel,
  type PlatformFeatureState,
} from "./types";

function asRecord(value: unknown) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function asString(value: unknown, fallback = "") {
  return typeof value === "string" ? value : fallback;
}

function asBoolean(value: unknown, fallback = false) {
  return typeof value === "boolean" ? value : fallback;
}

function asNumber(value: unknown, fallback = 0) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function normalizeChannel(
  channel: "mobile" | "web",
  value: unknown,
): PlatformFeatureChannel {
  const record = asRecord(value);
  return {
    channel,
    isVisible: asBoolean(record.is_visible, false),
    isEnabled: asBoolean(record.is_enabled, false),
    showInNavigation: asBoolean(record.show_in_navigation, false),
    showOnHome: asBoolean(record.show_on_home, false),
    sortOrder: asNumber(record.sort_order, 100),
    routeKey: asString(record.route_key) || null,
    entryKey: asString(record.entry_key) || null,
    navigationLabel: asString(record.navigation_label) || null,
    placementKey: asString(record.placement_key) || null,
    metadata: asRecord(record.metadata),
  };
}

function normalizeResolvedState(value: unknown): PlatformFeatureState {
  const record = asRecord(value);
  return {
    featureKey: asString(record.feature_key),
    displayName: asString(record.display_name),
    description: asString(record.description) || null,
    status: asString(record.status, "inactive"),
    exists: asBoolean(record.exists, true),
    isEnabled: asBoolean(record.is_enabled, false),
    isOperational: asBoolean(record.is_operational, false),
    isVisible: asBoolean(record.is_visible, false),
    isAvailable: asBoolean(record.is_available, false),
    authRequired: asBoolean(record.auth_required, false),
    dependencyBlocker: asString(record.dependency_blocker) || null,
    channel: asString(record.channel, "web") === "mobile" ? "mobile" : "web",
    showInNavigation: asBoolean(record.show_in_navigation, false),
    showOnHome: asBoolean(record.show_on_home, false),
    routeKey: asString(record.route_key) || null,
    entryKey: asString(record.entry_key) || null,
    sortOrder: asNumber(record.sort_order, 100),
    roleRestrictions: record.role_restrictions ?? [],
    rolloutConfig: asRecord(record.rollout_config),
    scheduleStartAt: asString(record.schedule_start_at) || null,
    scheduleEndAt: asString(record.schedule_end_at) || null,
    metadata: asRecord(record.metadata),
  };
}

function normalizeFeature(value: unknown): PlatformFeature {
  const record = asRecord(value);
  const channels = asRecord(record.channels);
  return {
    featureKey: asString(record.feature_key),
    displayName: asString(record.display_name),
    description: asString(record.description) || null,
    status: asString(record.status, "inactive"),
    isEnabled: asBoolean(record.is_enabled, false),
    navigationGroup: asString(record.navigation_group) || null,
    defaultRouteKey: asString(record.default_route_key) || null,
    adminNotes: asString(record.admin_notes) || null,
    metadata: asRecord(record.metadata),
    authRequired: asBoolean(record.auth_required, false),
    roleRestrictions: record.role_restrictions ?? [],
    dependencyConfig: asRecord(record.dependency_config),
    rolloutConfig: asRecord(record.rollout_config),
    scheduleStartAt: asString(record.schedule_start_at) || null,
    scheduleEndAt: asString(record.schedule_end_at) || null,
    channels: {
      mobile: normalizeChannel("mobile", channels.mobile),
      web: normalizeChannel("web", channels.web),
    },
    resolvedState: normalizeResolvedState(record.resolved_state),
  };
}

function normalizeBlock(value: unknown): PlatformContentBlock {
  const record = asRecord(value);
  const targetChannel = asString(record.target_channel, "both");
  return {
    blockKey: asString(record.block_key),
    blockType: asString(record.block_type),
    title: asString(record.title),
    content: asRecord(record.content),
    targetChannel:
      targetChannel === "mobile" || targetChannel === "web"
        ? targetChannel
        : "both",
    isActive: asBoolean(record.is_active, false),
    sortOrder: asNumber(record.sort_order, 100),
    featureKey: asString(record.feature_key) || null,
    placementKey: asString(record.placement_key),
    metadata: asRecord(record.metadata),
  };
}

export function normalizePlatformBootstrap(value: unknown): PlatformBootstrap {
  const record = asRecord(value);
  const features = Array.isArray(record.platform_features)
    ? record.platform_features.map(normalizeFeature)
    : DEFAULT_PLATFORM_BOOTSTRAP.platformFeatures;
  const blocks = Array.isArray(record.platform_content_blocks)
    ? record.platform_content_blocks.map(normalizeBlock)
    : DEFAULT_PLATFORM_BOOTSTRAP.platformContentBlocks;
  const featureFlags = asRecord(record.feature_flags);

  return {
    featureFlags: Object.fromEntries(
      Object.entries(featureFlags).map(([key, raw]) => [key, raw === true]),
    ),
    appConfig: asRecord(record.app_config),
    platformFeatures: features,
    platformContentBlocks: blocks,
  };
}
