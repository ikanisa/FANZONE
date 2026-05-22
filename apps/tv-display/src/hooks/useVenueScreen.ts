import { useCallback, useEffect, useRef, useState } from "react";
import {
  fetchGameDisplay,
  fetchMenuHighlights,
  fetchPoolDisplay,
  fetchScreenState,
  resolveVenue,
  subscribeToVenueScreen,
} from "../services/tvData";
import type { ScreenData } from "../types";

export function useVenueScreen(venueKey: string | undefined) {
  const requestIdRef = useRef(0);
  const [data, setData] = useState<ScreenData>({
    venue: null,
    state: null,
    pool: null,
    game: null,
    menuItems: [],
    loading: true,
    error: null,
    refreshedAt: null,
  });

  const reload = useCallback(async () => {
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;

    if (!venueKey) {
      setData({
        venue: null,
        state: null,
        pool: null,
        game: null,
        menuItems: [],
        loading: false,
        error: null,
        refreshedAt: null,
      });
      return;
    }

    setData({
      venue: null,
      state: null,
      pool: null,
      game: null,
      menuItems: [],
      loading: true,
      error: null,
      refreshedAt: null,
    });
    try {
      const venue = await resolveVenue(venueKey);
      const state = await fetchScreenState(venue.id);
      const mode = state?.mode ?? "welcome";
      const [pool, game, menuItems] = await Promise.all([
        state?.activePoolId
          ? fetchPoolDisplay(venue.id, state.activePoolId)
          : Promise.resolve(null),
        state?.activeGameSessionId
          ? fetchGameDisplay(venue.id, state.activeGameSessionId)
          : Promise.resolve(null),
        mode === "menu" || mode === "promo"
          ? fetchMenuHighlights(venue.id)
          : Promise.resolve([]),
      ]);

      if (requestId !== requestIdRef.current) return;

      setData({
        venue,
        state,
        pool,
        game,
        menuItems,
        loading: false,
        error: null,
        refreshedAt: new Date(),
      });
    } catch (error) {
      if (requestId !== requestIdRef.current) return;

      setData({
        venue: null,
        state: null,
        pool: null,
        game: null,
        menuItems: [],
        loading: false,
        error:
          error instanceof Error ? error.message : "Could not load TV display.",
        refreshedAt: new Date(),
      });
    }
  }, [venueKey]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void reload();
    }, 0);
    const interval = window.setInterval(() => {
      void reload();
    }, 15000);
    return () => {
      window.clearTimeout(timer);
      window.clearInterval(interval);
    };
  }, [reload]);

  useEffect(() => {
    if (!data.venue?.id) return undefined;
    return subscribeToVenueScreen(data.venue.id, () => {
      void reload();
    });
  }, [data.venue?.id, reload]);

  return { data, reload };
}
