import { afterEach, describe, expect, it } from "vitest";

import {
  getPlatformFeatureRoute,
  getWebsiteHomeBlocks,
  getWebsiteNavigationFeatures,
  isPlatformFeatureAvailable,
  isPlatformFeatureVisible,
  setPlatformBootstrapSnapshot,
} from "./access";
import { DEFAULT_PLATFORM_BOOTSTRAP, type PlatformBootstrap } from "./types";

function withBootstrap(partial: Partial<PlatformBootstrap>): PlatformBootstrap {
  return {
    ...DEFAULT_PLATFORM_BOOTSTRAP,
    ...partial,
  };
}

describe("platform access helpers", () => {
  afterEach(() => {
    setPlatformBootstrapSnapshot(DEFAULT_PLATFORM_BOOTSTRAP);
  });

  it("does not fabricate website defaults when the registry is unavailable", () => {
    setPlatformBootstrapSnapshot(DEFAULT_PLATFORM_BOOTSTRAP);

    expect(getWebsiteNavigationFeatures()).toEqual([]);
    expect(getWebsiteHomeBlocks("home.primary")).toEqual([]);
    expect(isPlatformFeatureVisible("pools", { surface: "route" })).toBe(
      false,
    );
    expect(isPlatformFeatureAvailable("wallet")).toBe(false);
    expect(
      getPlatformFeatureRoute("pools", { fallback: "/fixtures" }),
    ).toBe("/fixtures");
  });

  it("filters navigation, home blocks, and actions from the resolved registry state", () => {
    setPlatformBootstrapSnapshot(
      withBootstrap({
        platformFeatures: [
          {
            featureKey: "wallet",
            displayName: "Wallet",
            description: null,
            status: "active",
            isEnabled: true,
            navigationGroup: "primary",
            defaultRouteKey: "/wallet",
            adminNotes: null,
            metadata: {},
            authRequired: true,
            roleRestrictions: [],
            dependencyConfig: {},
            rolloutConfig: {},
            scheduleStartAt: null,
            scheduleEndAt: null,
            channels: {
              mobile: {
                channel: "mobile",
                isVisible: true,
                isEnabled: true,
                showInNavigation: false,
                showOnHome: false,
                sortOrder: 50,
                routeKey: "/wallet",
                entryKey: "wallet.index",
                navigationLabel: "Wallet",
                placementKey: "secondary-nav",
                metadata: {},
              },
              web: {
                channel: "web",
                isVisible: true,
                isEnabled: true,
                showInNavigation: true,
                showOnHome: true,
                sortOrder: 50,
                routeKey: "/wallet",
                entryKey: "wallet.index",
                navigationLabel: "Wallet",
                placementKey: "primary-nav",
                metadata: {},
              },
            },
            resolvedState: {
              featureKey: "wallet",
              displayName: "Wallet",
              description: null,
              status: "active",
              exists: true,
              isEnabled: true,
              isOperational: true,
              isVisible: true,
              isAvailable: false,
              authRequired: true,
              dependencyBlocker: null,
              channel: "web",
              showInNavigation: true,
              showOnHome: true,
              routeKey: "/wallet",
              entryKey: "wallet.index",
              sortOrder: 50,
              roleRestrictions: [],
              rolloutConfig: {},
              scheduleStartAt: null,
              scheduleEndAt: null,
              metadata: {},
            },
          },
          {
            featureKey: "pools",
            displayName: "Pools",
            description: "FET match pools",
            status: "active",
            isEnabled: true,
            navigationGroup: "primary",
            defaultRouteKey: "/pools",
            adminNotes: null,
            metadata: {},
            authRequired: true,
            roleRestrictions: [],
            dependencyConfig: {},
            rolloutConfig: {},
            scheduleStartAt: null,
            scheduleEndAt: null,
            channels: {
              mobile: {
                channel: "mobile",
                isVisible: true,
                isEnabled: true,
                showInNavigation: true,
                showOnHome: true,
                sortOrder: 30,
                routeKey: "/pools",
                entryKey: "pools.index",
                navigationLabel: "Pools",
                placementKey: "primary-nav",
                metadata: {},
              },
              web: {
                channel: "web",
                isVisible: true,
                isEnabled: true,
                showInNavigation: true,
                showOnHome: true,
                sortOrder: 30,
                routeKey: "/pools",
                entryKey: "pools.index",
                navigationLabel: "Pools",
                placementKey: "primary-nav",
                metadata: {},
              },
            },
            resolvedState: {
              featureKey: "pools",
              displayName: "Pools",
              description: "FET match pools",
              status: "active",
              exists: true,
              isEnabled: true,
              isOperational: true,
              isVisible: true,
              isAvailable: false,
              authRequired: true,
              dependencyBlocker: null,
              channel: "web",
              showInNavigation: true,
              showOnHome: true,
              routeKey: "/pools",
              entryKey: "pools.index",
              sortOrder: 30,
              roleRestrictions: [],
              rolloutConfig: {},
              scheduleStartAt: null,
              scheduleEndAt: null,
              metadata: {},
            },
          },
        ],
        platformContentBlocks: [
          {
            blockKey: "wallet_banner",
            blockType: "promo_banner",
            title: "Wallet Push",
            content: {},
            targetChannel: "web",
            isActive: true,
            sortOrder: 10,
            featureKey: "wallet",
            placementKey: "home.primary",
            metadata: {},
          },
          {
            blockKey: "pool_banner",
            blockType: "promo_banner",
            title: "Pool Push",
            content: {},
            targetChannel: "web",
            isActive: true,
            sortOrder: 20,
            featureKey: "pools",
            placementKey: "home.primary",
            metadata: {},
          },
        ],
      }),
    );

    expect(
      getWebsiteNavigationFeatures().map((feature) => feature.featureKey),
    ).toEqual(["pools", "wallet"]);
    expect(isPlatformFeatureVisible("pools", { surface: "route" })).toBe(true);
    expect(isPlatformFeatureAvailable("wallet")).toBe(false);
    expect(
      getWebsiteHomeBlocks("home.primary").map((block) => block.blockKey),
    ).toEqual(["wallet_banner", "pool_banner"]);
  });
});
