import {
  DEFAULT_PLATFORM_BOOTSTRAP,
  type PlatformBootstrap,
  type PlatformContentBlock,
  type PlatformFeature,
} from "./types";

let currentBootstrap: PlatformBootstrap = DEFAULT_PLATFORM_BOOTSTRAP;

function normalizeFeatureKey(featureKey: string) {
  return featureKey.trim().toLowerCase();
}

function isDynamicRoute(route: string | null | undefined) {
  return !route || route.includes(":");
}

function getConfiguredFeatures() {
  return currentBootstrap.platformFeatures;
}

function getConfiguredBlocks() {
  return currentBootstrap.platformContentBlocks;
}

const WEBSITE_GUEST_FEATURES = new Set([
  "home",
  "pools",
  "ordering",
  "venues",
  "wallet",
  "profile",
  "notifications",
  "settings",
  "rewards",
]);

export function setPlatformBootstrapSnapshot(bootstrap: PlatformBootstrap) {
  currentBootstrap = bootstrap;
}

export function getPlatformBootstrapSnapshot(): PlatformBootstrap {
  return currentBootstrap;
}

export function hasPlatformBootstrapSnapshot(
  bootstrap: PlatformBootstrap = currentBootstrap,
) {
  return (
    bootstrap.platformConfigVersion !== null ||
    Object.keys(bootstrap.featureFlags).length > 0 ||
    Object.keys(bootstrap.appConfig).length > 0 ||
    bootstrap.platformFeatures.length > 0 ||
    bootstrap.platformContentBlocks.length > 0
  );
}

export function getPlatformFeature(featureKey: string): PlatformFeature | null {
  const normalized = normalizeFeatureKey(featureKey);
  return (
    getConfiguredFeatures().find(
      (feature) => normalizeFeatureKey(feature.featureKey) === normalized,
    ) ?? null
  );
}

export function isPlatformFeatureVisible(
  featureKey: string,
  options?: { surface?: "navigation" | "home" | "route" | "action" },
) {
  const feature = getPlatformFeature(featureKey);
  if (!feature) return false;

  const state = feature.resolvedState;
  if (!state.isOperational || !state.isVisible) {
    return false;
  }

  switch (options?.surface) {
    case "navigation":
      return state.showInNavigation;
    case "home":
      return state.showOnHome;
    default:
      return true;
  }
}

export function isPlatformFeatureAvailable(featureKey: string) {
  const feature = getPlatformFeature(featureKey);
  if (!feature) return false;

  const state = feature.resolvedState;
  return state.isOperational && state.isAvailable;
}

export function getPlatformFeatureRoute(
  featureKey: string,
  options?: { fallback?: string },
) {
  const fallback = options?.fallback ?? "/";
  const feature = getPlatformFeature(featureKey);
  if (!feature) return fallback;

  const configuredRoute =
    feature.channels.web.routeKey ??
    feature.resolvedState.routeKey ??
    feature.defaultRouteKey;
  if (!isDynamicRoute(configuredRoute)) {
    return configuredRoute;
  }

  const defaultRoute = feature.defaultRouteKey;
  if (!isDynamicRoute(defaultRoute)) {
    return defaultRoute;
  }

  return fallback;
}

export function assertClientFeatureAvailable(
  featureKey: string,
  fallbackMessage: string,
) {
  if (!isPlatformFeatureAvailable(featureKey)) {
    throw new Error(fallbackMessage);
  }
}

export function getWebsiteNavigationFeatures() {
  return getConfiguredFeatures()
    .filter((feature) =>
      isPlatformFeatureVisible(feature.featureKey, { surface: "navigation" }) &&
      WEBSITE_GUEST_FEATURES.has(normalizeFeatureKey(feature.featureKey)),
    )
    .sort(
      (left, right) => left.channels.web.sortOrder - right.channels.web.sortOrder,
    );
}

export function getWebsiteHomeBlocks(placementKey = "home.primary") {
  return getConfiguredBlocks()
    .filter((block) => {
      if (!block.isActive) return false;
      if (block.placementKey !== placementKey) return false;
      if (block.targetChannel !== "both" && block.targetChannel !== "web") {
        return false;
      }
      if (block.featureKey) {
        return isPlatformFeatureVisible(block.featureKey, { surface: "home" });
      }
      return true;
    })
    .sort((left, right) => left.sortOrder - right.sortOrder);
}

export function filterBlocksByType(
  blocks: PlatformContentBlock[],
  blockType: string,
) {
  return blocks.filter((block) => block.blockType === blockType);
}
