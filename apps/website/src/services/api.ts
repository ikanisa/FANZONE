import { isSupabaseConfigured } from "../lib/supabase";
import { normalizePlatformBootstrap } from "../platform/normalize";
import type { PlatformBootstrap } from "../platform/types";
import { ensureClient } from "./apiClient";
import { getLiveMatches, getMatchDetail, getUpcomingMatches } from "./matchApi";
import {
  createPool,
  createPoolInvite,
  generatePoolShareCard,
  getMatchPoolBySlug,
  getMatchPools,
  getMyPools,
  getOpenMatchPools,
  getPoolMatches,
  joinMatchPool,
} from "./poolApi";
import {
  fetchMenu,
  fetchVenueBySlug,
  fetchVenues,
  placeOrder,
} from "./venueOrderingApi";
import {
  getPreferredCurrencyDisplay,
  getPreferredPhonePreset,
  getViewerState,
  markAllNotificationsRead,
  markNotificationRead,
  transferFetByFanId,
} from "./viewerApi";

export type {
  CurrencyDisplayPreference,
  ViewerState,
  WebsitePhonePreset,
} from "./viewerApi";

async function getPlatformBootstrap(): Promise<PlatformBootstrap> {
  const client = await ensureClient();
  if (!client) {
    throw new Error("Supabase is not configured for the website.");
  }

  const { data, error } = await client.rpc("get_app_bootstrap_config", {
    p_market: "global",
    p_platform: "web",
  });

  if (error) {
    throw new Error(error.message);
  }

  return normalizePlatformBootstrap(data);
}

export const api = {
  isConfigured: isSupabaseConfigured,
  getPlatformBootstrap,
  getLiveMatches,
  getUpcomingMatches,
  getMatchDetail,
  getOpenMatchPools,
  getMatchPools,
  getMatchPoolBySlug,
  getPoolMatches,
  getMyPools,
  createPool,
  generatePoolShareCard,
  createPoolInvite,
  getViewerState,
  getPreferredPhonePreset,
  getPreferredCurrencyDisplay,
  joinMatchPool,
  transferFetByFanId,
  markNotificationRead,
  markAllNotificationsRead,
  fetchVenues,
  fetchVenueBySlug,
  fetchMenu,
  placeOrder,
};
