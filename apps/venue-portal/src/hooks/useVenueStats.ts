import { useCallback, useEffect, useState } from 'react';
import type { VenueOperationalInsights } from '@fanzone/core';
import { supabase } from '../lib/supabase';
import { fetchVenueOperationalInsights } from '../services/venueOperations';

export type VenueStats = VenueOperationalInsights & {
  dailyRevenue: number;
  activeOrders: number;
  fetRedeemed: number;
  matchGuests: number;
};

const emptyInsights: VenueOperationalInsights = {
  today_orders: 0,
  fet_issued: 0,
  fet_redeemed: 0,
  active_pools: 0,
  most_active_match: null,
  top_menu_items: [],
  pending_payment_count: 0,
};

function toStats(insights: VenueOperationalInsights): VenueStats {
  return {
    ...insights,
    dailyRevenue: 0,
    activeOrders: insights.today_orders,
    fetRedeemed: insights.fet_redeemed,
    matchGuests: insights.most_active_match?.total_members ?? 0,
  };
}

export function useVenueStats(venueId: string) {
  const [stats, setStats] = useState<VenueStats>(toStats(emptyInsights));
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (!venueId) {
      setStats(toStats(emptyInsights));
      return;
    }

    setLoading(true);
    setError(null);
    try {
      setStats(toStats(await fetchVenueOperationalInsights(venueId)));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch venue insights.');
    } finally {
      setLoading(false);
    }
  }, [venueId]);

  useEffect(() => {
    if (!venueId) return;

    const timer = window.setTimeout(() => {
      void refresh();
    }, 0);

    const channel = supabase
      .channel(`venue-stats-${venueId}-${Date.now()}-${Math.random().toString(16).slice(2)}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'orders', filter: `venue_id=eq.${venueId}` },
        () => refresh(),
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'match_pools', filter: `venue_id=eq.${venueId}` },
        () => refresh(),
      )
      .subscribe();

    return () => {
      window.clearTimeout(timer);
      supabase.removeChannel(channel);
    };
  }, [refresh, venueId]);

  return {
    stats,
    loading: venueId ? loading : false,
    error: venueId ? error : null,
    refresh,
  };
}
