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
  featureFlags: Record<string, boolean>;
  appConfig: Record<string, unknown>;
  platformFeatures: PlatformFeature[];
  platformContentBlocks: PlatformContentBlock[];
}

function defaultChannel(
  channel: "mobile" | "web",
  config: Partial<PlatformFeatureChannel> = {},
): PlatformFeatureChannel {
  return {
    channel,
    isVisible: config.isVisible ?? true,
    isEnabled: config.isEnabled ?? true,
    showInNavigation: config.showInNavigation ?? false,
    showOnHome: config.showOnHome ?? false,
    sortOrder: config.sortOrder ?? 100,
    routeKey: config.routeKey ?? null,
    entryKey: config.entryKey ?? null,
    navigationLabel: config.navigationLabel ?? null,
    placementKey: config.placementKey ?? null,
    metadata: config.metadata ?? {},
  };
}

function defaultFeature(
  featureKey: string,
  displayName: string,
  config: {
    description?: string;
    defaultRouteKey?: string;
    navigationGroup?: string;
    authRequired?: boolean;
    web?: Partial<PlatformFeatureChannel>;
    mobile?: Partial<PlatformFeatureChannel>;
  },
): PlatformFeature {
  const mobile = defaultChannel("mobile", config.mobile);
  const web = defaultChannel("web", config.web);
  const resolvedState: PlatformFeatureState = {
    featureKey,
    displayName,
    description: config.description ?? null,
    status: "active",
    exists: true,
    isEnabled: true,
    isOperational: true,
    isVisible: web.isVisible,
    isAvailable: true,
    authRequired: config.authRequired ?? false,
    dependencyBlocker: null,
    channel: "web",
    showInNavigation: web.showInNavigation,
    showOnHome: web.showOnHome,
    routeKey: web.routeKey ?? config.defaultRouteKey ?? null,
    entryKey: web.entryKey,
    sortOrder: web.sortOrder,
    roleRestrictions: [],
    rolloutConfig: {},
    scheduleStartAt: null,
    scheduleEndAt: null,
    metadata: {},
  };

  return {
    featureKey,
    displayName,
    description: config.description ?? null,
    status: "active",
    isEnabled: true,
    navigationGroup: config.navigationGroup ?? null,
    defaultRouteKey: config.defaultRouteKey ?? null,
    adminNotes: null,
    metadata: {},
    authRequired: config.authRequired ?? false,
    roleRestrictions: [],
    dependencyConfig: {},
    rolloutConfig: {},
    scheduleStartAt: null,
    scheduleEndAt: null,
    channels: { mobile, web },
    resolvedState,
  };
}

function defaultBlock(
  blockKey: string,
  blockType: string,
  title: string,
  sortOrder: number,
  featureKey: string | null,
  content: Record<string, unknown> = {},
): PlatformContentBlock {
  return {
    blockKey,
    blockType,
    title,
    content,
    targetChannel: "both",
    isActive: true,
    sortOrder,
    featureKey,
    placementKey: "home.primary",
    metadata: {},
  };
}

export const DEFAULT_PLATFORM_BOOTSTRAP: PlatformBootstrap = {
  featureFlags: {
    home_feed: true,
    fixtures: true,
    predictions: true,
    leaderboard: true,
    wallet: true,
    profile: true,
    notifications: true,
    settings: true,
    onboarding: true,
    match_center: true,
  },
  appConfig: {},
  platformFeatures: [
    defaultFeature("home_feed", "Home", {
      defaultRouteKey: "/",
      navigationGroup: "primary",
      web: {
        routeKey: "/",
        navigationLabel: "Home",
        showInNavigation: true,
        showOnHome: true,
        sortOrder: 10,
      },
    }),
    defaultFeature("fixtures", "Fixtures", {
      defaultRouteKey: "/fixtures",
      navigationGroup: "primary",
      web: {
        routeKey: "/fixtures",
        navigationLabel: "Fixtures",
        showInNavigation: true,
        showOnHome: true,
        sortOrder: 20,
      },
    }),
    defaultFeature("predictions", "Predictions", {
      description: "Lean prediction entry and consensus flows.",
      defaultRouteKey: "/match/:id",
      navigationGroup: "secondary",
      authRequired: true,
      web: {
        routeKey: "/match/:id",
        showInNavigation: false,
        showOnHome: true,
        sortOrder: 30,
      },
    }),
    defaultFeature("leaderboard", "Leaderboard", {
      defaultRouteKey: "/leaderboard",
      navigationGroup: "primary",
      web: {
        routeKey: "/leaderboard",
        navigationLabel: "Leaderboard",
        showInNavigation: true,
        sortOrder: 40,
      },
    }),
    defaultFeature("wallet", "Wallet", {
      defaultRouteKey: "/wallet",
      navigationGroup: "primary",
      authRequired: true,
      web: {
        routeKey: "/wallet",
        navigationLabel: "Wallet",
        showInNavigation: true,
        sortOrder: 50,
      },
    }),
    defaultFeature("profile", "Profile", {
      defaultRouteKey: "/profile",
      navigationGroup: "primary",
      web: {
        routeKey: "/profile",
        navigationLabel: "Profile",
        showInNavigation: true,
        sortOrder: 60,
      },
    }),
    defaultFeature("notifications", "Notifications", {
      defaultRouteKey: "/notifications",
      navigationGroup: "secondary",
      authRequired: true,
      web: {
        routeKey: "/notifications",
        showInNavigation: false,
        sortOrder: 70,
      },
    }),
    defaultFeature("settings", "Settings", {
      defaultRouteKey: "/settings",
      navigationGroup: "secondary",
      web: { routeKey: "/settings", showInNavigation: false, sortOrder: 80 },
    }),
    defaultFeature("onboarding", "Onboarding", {
      defaultRouteKey: "/onboarding",
      navigationGroup: "system",
      web: { routeKey: "/onboarding", showInNavigation: false, sortOrder: 90 },
    }),
    defaultFeature("match_center", "Match Center", {
      defaultRouteKey: "/match/:id",
      navigationGroup: "system",
      web: { routeKey: "/match/:id", showInNavigation: false, sortOrder: 100 },
    }),
  ],
  platformContentBlocks: [
    defaultBlock("home_promo_banner", "promo_banner", "Lean Matchday Window", 10, "predictions", {
      badge: "DERBY DAY",
      kicker: "Global",
      subtitle: "Live fixtures, free picks, and leaderboard movement are synced now.",
      cta_label: "Open Picks",
      cta_route: "/match/:id",
    }),
    defaultBlock("home_daily_insight", "daily_insight", "Daily Insight", 15, "predictions", {
      subtitle: "Track live fixtures, lock free picks, and follow the leaderboard from one place.",
    }),
    defaultBlock("home_live_matches", "live_matches", "Live Action", 20, "fixtures", {
      empty_title: "No Live Matches",
      empty_description: "Check upcoming.",
    }),
    defaultBlock("home_upcoming_matches", "upcoming_matches", "Upcoming", 30, "fixtures", {
      empty_title: "No Upcoming",
      empty_description: "None left.",
      cta_route: "/fixtures",
    }),
  ],
};
