import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import {
  acknowledgeBellRequest,
  fetchActiveBellRequests,
  type BellRequest,
} from '../services/venueOperations';

export function useBellRequests(venueId: string) {
  const [bells, setBells] = useState<BellRequest[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (!venueId) {
      setBells([]);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      setBells(await fetchActiveBellRequests(venueId));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch bell requests.');
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
      .channel(`venue-bells-${venueId}-${Date.now()}-${Math.random().toString(16).slice(2)}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'bell_requests',
          filter: `venue_id=eq.${venueId}`,
        },
        () => refresh(),
      )
      .subscribe();

    return () => {
      window.clearTimeout(timer);
      supabase.removeChannel(channel);
    };
  }, [refresh, venueId]);

  const acknowledge = async (bellId: string) => {
    await acknowledgeBellRequest(bellId);
    await refresh();
  };

  return {
    bells: venueId ? bells : [],
    loading: venueId ? loading : false,
    error: venueId ? error : null,
    refresh,
    acknowledge,
  };
}
