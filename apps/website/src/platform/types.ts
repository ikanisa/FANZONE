export interface PlatformFeatureChannel {
  channel: "mobile" | "web";
  isVisible: boolean;
  isEnabled: boolean;
  showInNavigation: boolean;
  showOnHome: boolean;
  sortOrder: number;
  routeKey: string | null;
  entryKey: string | null;
  navigationLabel: string | null;
  placementKey: string | null;
  metadata: Record<string, unknown>;
}

export interface PlatformFeatureState {
  featureKey: string;
  displayName: string;
  description: string | null;
  status: string;
  exists: boolean;
  isEnabled: boolean;
  isOperational: boolean;
  isVisible: boolean;
  isAvailable: boolean;
  authRequired: boolean;
  dependencyBlocker: string | null;
  channel: "mobile" | "web";
  showInNavigation: boolean;
  showOnHome: boolean;
  routeKey: string | null;
  entryKey: string | null;
  sortOrder: number;
  roleRestrictions: unknown;
  rolloutConfig: Record<string, unknown>;
  scheduleStartAt: string | null;
  scheduleEndAt: string | null;
  metadata: Record<string, unknown>;
}

export interface PlatformFeature {
  featureKey: string;
  displayName: string;
  description: string | null;
  status: string;
  isEnabled: boolean;
  navigationGroup: string | null;
  defaultRouteKey: string | null;
  adminNotes: string | null;
  metadata: Record<string, unknown>;
  authRequired: boolean;
  roleRestrictions: unknown;
  dependencyConfig: Record<string, unknown>;
  rolloutConfig: Record<string, unknown>;
  scheduleStartAt: string | null;
  scheduleEndAt: string | null;
  channels: {
    mobile: PlatformFeatureChannel;
    web: PlatformFeatureChannel;
  };
  resolvedState: PlatformFeatureState;
}

export interface PlatformContentBlock {
  blockKey: string;
  blockType: string;
  title: string;
  content: Record<string, unknown>;
  targetChannel: "mobile" | "web" | "both";
  isActive: boolean;
  sortOrder: number;
  featureKey: string | null;
  placementKey: string;
  metadata: Record<string, unknown>;
}

export interface PlatformBootstrap {
  platformConfigVersion: string | null;
  featureFlags: Record<string, boolean>;
  appConfig: Record<string, unknown>;
  platformFeatures: PlatformFeature[];
  platformContentBlocks: PlatformContentBlock[];
}

export const DEFAULT_PLATFORM_BOOTSTRAP: PlatformBootstrap = {
  platformConfigVersion: null,
  featureFlags: {},
  appConfig: {},
  platformFeatures: [],
  platformContentBlocks: [],
};
