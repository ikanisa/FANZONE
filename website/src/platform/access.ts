import {
  DEFAULT_PLATFORM_BOOTSTRAP,
  type PlatformBootstrap,
  type PlatformContentBlock,
  type PlatformFeature,
} from "./types";

let currentBootstrap: PlatformBootstrap = DEFAULT_PLATFORM_BOOTSTRAP;

export function setPlatformBootstrapSnapshot(bootstrap: PlatformBootstrap) {
  currentBootstrap = bootstrap;
}

export function getPlatformBootstrapSnapshot(): PlatformBootstrap {
  return currentBootstrap;
}

export function getPlatformFeature(featureKey: string): PlatformFeature | null {
  return (
    currentBootstrap.platformFeatures.find(
      (feature) => feature.featureKey === featureKey,
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

export function assertClientFeatureAvailable(
  featureKey: string,
  fallbackMessage: string,
) {
  if (!isPlatformFeatureVisible(featureKey, { surface: "action" })) {
    throw new Error(fallbackMessage);
  }
}

export function getWebsiteNavigationFeatures() {
  return currentBootstrap.platformFeatures
    .filter((feature) => isPlatformFeatureVisible(feature.featureKey, { surface: "navigation" }))
    .sort(
      (left, right) =>
        left.channels.web.sortOrder - right.channels.web.sortOrder,
    );
}

export function getWebsiteHomeBlocks(placementKey = "home.primary") {
  return currentBootstrap.platformContentBlocks
    .filter((block) => {
      if (!block.isActive) return false;
      if (block.placementKey !== placementKey) return false;
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
